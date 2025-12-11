import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';
import '../logging/app_logger.dart';
import '../models/models.dart';
import '../services/services.dart';
import 'service_providers.dart';
import 'auth_provider.dart';
import 'society_provider.dart';

/// State for order operations
class OrderState {
  final PrintDocument? selectedDocument;
  final Station? selectedStation;
  final Society? society;
  final int copies;
  final CreditSummary? creditSummary;
  final PrintOrder? currentOrder;
  final OrderStep currentStep;
  final bool isLoading;
  final String? errorMessage;

  OrderState({
    this.selectedDocument,
    this.selectedStation,
    this.society,
    this.copies = 1,
    this.creditSummary,
    this.currentOrder,
    this.currentStep = OrderStep.selectDocument,
    this.isLoading = false,
    this.errorMessage,
  });

  OrderState copyWith({
    PrintDocument? selectedDocument,
    Station? selectedStation,
    Society? society,
    int? copies,
    CreditSummary? creditSummary,
    PrintOrder? currentOrder,
    OrderStep? currentStep,
    bool? isLoading,
    String? errorMessage,
  }) {
    return OrderState(
      selectedDocument: selectedDocument ?? this.selectedDocument,
      selectedStation: selectedStation ?? this.selectedStation,
      society: society ?? this.society,
      copies: copies ?? this.copies,
      creditSummary: creditSummary ?? this.creditSummary,
      currentOrder: currentOrder ?? this.currentOrder,
      currentStep: currentStep ?? this.currentStep,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  /// Get B/W price per page (from society or default)
  int get bwPricePerPagePaise =>
      society?.bwPricePerPagePaise ?? AppConstants.defaultBwPricePerPagePaise;

  /// Get color price per page (from society or default)
  int get colorPricePerPagePaise =>
      society?.colorPricePerPagePaise ?? AppConstants.defaultColorPricePerPagePaise;

  /// Calculate order amount in paise using society's pricing
  int get calculatedAmountPaise {
    if (selectedDocument == null) return 0;

    if (society != null) {
      return society!.calculatePrice(
        bwPages: selectedDocument!.bwPageCount,
        colorPages: selectedDocument!.colorPageCount,
        copies: copies,
      );
    }

    // Fallback to default pricing
    final bwTotal = selectedDocument!.bwPageCount * AppConstants.defaultBwPricePerPagePaise;
    final colorTotal = selectedDocument!.colorPageCount * AppConstants.defaultColorPricePerPagePaise;
    return (bwTotal + colorTotal) * copies;
  }

  /// Calculate amount after credits
  int get finalAmountPaise {
    final total = calculatedAmountPaise;
    if (creditSummary == null || !creditSummary!.hasCredits) return total;

    // Calculate credit value using society's pricing
    final creditValue = creditSummary!.calculateValueInPaise(
      bwPricePerPagePaise: bwPricePerPagePaise,
      colorPricePerPagePaise: colorPricePerPagePaise,
    );
    return (total - creditValue).clamp(0, total);
  }

  /// Credits used in paise
  int get creditsUsedPaise => calculatedAmountPaise - finalAmountPaise;

  /// Check if order is ready to create
  bool get canCreateOrder =>
      selectedDocument != null && selectedStation != null && !isLoading;
}

/// Order flow steps
enum OrderStep {
  selectDocument,
  selectStation,
  preview,
  payment,
  printing,
  completed,
  failed,
}

/// Order notifier
class OrderNotifier extends StateNotifier<OrderState> {
  final SupabaseService _supabaseService;
  final DocumentService _documentService;
  final NetworkService _networkService;
  final EpsonService _epsonService;
  final PaymentCallbackService _paymentCallbackService;
  final Ref _ref;

  OrderNotifier(
    this._supabaseService,
    this._documentService,
    this._networkService,
    this._epsonService,
    this._paymentCallbackService,
    this._ref,
  ) : super(OrderState());

  /// Reset order state
  void resetOrder() {
    final society = _ref.read(currentSocietyProvider);
    state = OrderState(society: society);
  }

  /// Select document
  Future<bool> selectDocument() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final result = await _documentService.pickDocument();

      if (!result.success) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: result.errorMessage ?? result.error?.message,
        );
        return false;
      }

      state = state.copyWith(
        selectedDocument: result.document,
        currentStep: OrderStep.selectStation,
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to select document: ${e.toString()}',
      );
      return false;
    }
  }

  /// Set selected station
  void selectStation(Station station) {
    state = state.copyWith(
      selectedStation: station,
      currentStep: OrderStep.preview,
    );
  }

  /// Set number of copies
  void setCopies(int copies) {
    state = state.copyWith(
      copies: copies.clamp(1, AppConstants.maxCopies),
    );
  }

  /// Set document directly (for collage/external sources)
  void setDocument(PrintDocument document) {
    final society = _ref.read(currentSocietyProvider);
    state = state.copyWith(
      selectedDocument: document,
      society: society,
      currentStep: OrderStep.selectStation,
    );
  }

  /// Set station directly
  void setStation(Station station) {
    state = state.copyWith(selectedStation: station);
  }

  /// Load user credits and society pricing
  Future<void> loadCredits() async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;

    // Ensure society is set for pricing
    if (state.society == null) {
      final society = _ref.read(currentSocietyProvider);
      if (society != null) {
        state = state.copyWith(society: society);
      }
    }

    try {
      final creditSummary = await _supabaseService.getCreditSummary(user.id);
      state = state.copyWith(creditSummary: creditSummary);
    } catch (e) {
      // Silently fail - credits are optional
    }
  }

  /// Check network connectivity before operations
  Future<bool> _validateNetwork() async {
    final networkResult = await _networkService.validateNetworkForOperation();
    if (!networkResult.canProceed) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: networkResult.errorMessage,
      );
      return false;
    }
    return true;
  }

  /// Check printer status before creating order
  Future<bool> _validatePrinterStatus() async {
    if (state.selectedStation == null) return false;

    try {
      final printerEmail = state.selectedStation!.epsonPrinterEmail;
      final printerResult = await _epsonService.checkPrinterReady(printerEmail);

      if (!printerResult.isReady) {
        AppLogger.warning(
          'Printer not ready: ${printerResult.errorMessage}',
          tag: 'Order',
        );
        state = state.copyWith(
          isLoading: false,
          errorMessage: printerResult.errorMessage ?? 'Printer is not ready',
        );
        return false;
      }

      return true;
    } catch (e) {
      AppLogger.error('Printer status check failed', error: e, tag: 'Order');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to verify printer status. Please try again.',
      );
      return false;
    }
  }

  /// Create order with network and printer validation
  Future<bool> createOrder() async {
    if (!state.canCreateOrder) return false;

    final user = _ref.read(currentUserProvider);
    final society = _ref.read(currentSocietyProvider);
    if (user == null || society == null) return false;

    state = state.copyWith(isLoading: true, errorMessage: null);

    // Validate network connectivity
    if (!await _validateNetwork()) return false;

    // Validate printer status
    if (!await _validatePrinterStatus()) return false;

    try {
      final order = await _supabaseService.createOrder(
        userId: user.id,
        societyId: society.id,
        stationId: state.selectedStation!.id,
        fileName: state.selectedDocument!.name,
        fileHash: _documentService.calculateFileHash(state.selectedDocument!.bytes),
        totalPages: state.selectedDocument!.totalPages,
        bwPages: state.selectedDocument!.bwPageCount,
        colorPages: state.selectedDocument!.colorPageCount,
        copies: state.copies,
        amountPaise: state.calculatedAmountPaise,
        creditsUsedPaise: state.creditsUsedPaise,
        finalAmountPaise: state.finalAmountPaise,
      );

      // Upload document to storage for printing after payment
      AppLogger.info('Uploading document for order: ${order.id}', tag: 'Order');
      final printBytes = await _documentService.prepareForPrinting(state.selectedDocument!);
      await _supabaseService.uploadDocument(
        orderId: order.id,
        fileName: 'document.pdf',
        bytes: printBytes,
      );
      AppLogger.info('Document uploaded successfully', tag: 'Order');

      // Start payment monitoring
      _paymentCallbackService.startPaymentMonitoring(order.id);

      state = state.copyWith(
        currentOrder: order,
        currentStep: OrderStep.payment,
        isLoading: false,
      );

      AppLogger.info('Order created: ${order.id}', tag: 'Order');
      return true;
    } catch (e) {
      AppLogger.error('Failed to create order', error: e, tag: 'Order');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to create order: ${e.toString()}',
      );
      return false;
    }
  }

  /// Subscribe to order updates
  void subscribeToOrderUpdates(String orderId) {
    _supabaseService.subscribeToOrder(orderId).listen((order) {
      state = state.copyWith(currentOrder: order);

      // Update step based on order status
      if (order.isPaid && order.printStatusEnum == PrintStatus.printing) {
        state = state.copyWith(currentStep: OrderStep.printing);
      } else if (order.isCompleted) {
        state = state.copyWith(currentStep: OrderStep.completed);
      } else if (order.isFailed) {
        state = state.copyWith(currentStep: OrderStep.failed);
      }
    });
  }

  /// Cancel current order
  Future<bool> cancelOrder() async {
    if (state.currentOrder == null) {
      resetOrder();
      return true;
    }

    final orderId = state.currentOrder!.id;
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      // Stop payment monitoring
      _paymentCallbackService.stopPaymentMonitoring();

      // Update order status in database
      await Supabase.instance.client.from('orders').update({
        'status': 'cancelled',
        'cancelled_at': DateTime.now().toIso8601String(),
        'cancelled_reason': 'User cancelled',
      }).eq('id', orderId);

      AppLogger.info('Order cancelled: $orderId', tag: 'Order');

      resetOrder();
      return true;
    } catch (e) {
      AppLogger.error('Failed to cancel order', error: e, tag: 'Order');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to cancel order: ${e.toString()}',
      );
      return false;
    }
  }

  /// Handle payment success
  void onPaymentSuccess(String txnId) {
    if (state.currentOrder == null) return;

    state = state.copyWith(currentStep: OrderStep.printing);
    AppLogger.info('Payment successful, starting print: ${state.currentOrder!.id}', tag: 'Order');
  }

  /// Handle payment failure
  void onPaymentFailed(String? errorMessage) {
    state = state.copyWith(
      currentStep: OrderStep.failed,
      errorMessage: errorMessage ?? 'Payment failed',
    );
  }

  @override
  void dispose() {
    _paymentCallbackService.stopPaymentMonitoring();
    super.dispose();
  }
}

/// Payment callback service provider
final paymentCallbackServiceProvider = Provider<PaymentCallbackService>((ref) {
  final paytmService = ref.watch(paytmServiceProvider);
  return PaymentCallbackService(
    paytmService: paytmService,
    supabase: Supabase.instance.client,
  );
});

/// Order provider
final orderProvider = StateNotifierProvider<OrderNotifier, OrderState>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  final documentService = ref.watch(documentServiceProvider);
  final networkService = ref.watch(networkServiceProvider);
  final epsonService = ref.watch(epsonServiceProvider);
  final paymentCallbackService = ref.watch(paymentCallbackServiceProvider);

  return OrderNotifier(
    supabaseService,
    documentService,
    networkService,
    epsonService,
    paymentCallbackService,
    ref,
  );
});

/// Order history provider
final orderHistoryProvider = FutureProvider<List<PrintOrder>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final supabaseService = ref.read(supabaseServiceProvider);
  return supabaseService.getUserOrders(userId: user.id);
});

/// Single order provider
final singleOrderProvider = FutureProvider.family<PrintOrder?, String>(
  (ref, orderId) async {
    final supabaseService = ref.read(supabaseServiceProvider);
    return supabaseService.getOrder(orderId);
  },
);
