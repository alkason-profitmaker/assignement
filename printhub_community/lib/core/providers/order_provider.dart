import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import '../models/models.dart';
import '../services/services.dart';
import 'service_providers.dart';
import 'auth_provider.dart';
import 'society_provider.dart';

/// State for order operations
class OrderState {
  final PrintDocument? selectedDocument;
  final Station? selectedStation;
  final int copies;
  final CreditSummary? creditSummary;
  final PrintOrder? currentOrder;
  final OrderStep currentStep;
  final bool isLoading;
  final String? errorMessage;

  OrderState({
    this.selectedDocument,
    this.selectedStation,
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
      copies: copies ?? this.copies,
      creditSummary: creditSummary ?? this.creditSummary,
      currentOrder: currentOrder ?? this.currentOrder,
      currentStep: currentStep ?? this.currentStep,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  /// Calculate order amount in paise
  int get calculatedAmountPaise {
    if (selectedDocument == null) return 0;

    return PrintOrder.calculatePrice(
      bwPages: selectedDocument!.bwPageCount,
      colorPages: selectedDocument!.colorPageCount,
      copies: copies,
    );
  }

  /// Calculate amount after credits
  int get finalAmountPaise {
    final total = calculatedAmountPaise;
    if (creditSummary == null || !creditSummary!.hasCredits) return total;

    // Calculate credit value (simplified - in real app, track pages used)
    final creditValue = creditSummary!.valueInPaise;
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
  final Ref _ref;

  OrderNotifier(this._supabaseService, this._documentService, this._ref)
      : super(OrderState());

  /// Reset order state
  void resetOrder() {
    state = OrderState();
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

  /// Load user credits
  Future<void> loadCredits() async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;

    try {
      final creditSummary = await _supabaseService.getCreditSummary(user.id);
      state = state.copyWith(creditSummary: creditSummary);
    } catch (e) {
      // Silently fail - credits are optional
    }
  }

  /// Create order
  Future<bool> createOrder() async {
    if (!state.canCreateOrder) return false;

    final user = _ref.read(currentUserProvider);
    final society = _ref.read(currentSocietyProvider);
    if (user == null || society == null) return false;

    state = state.copyWith(isLoading: true, errorMessage: null);

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

      state = state.copyWith(
        currentOrder: order,
        currentStep: OrderStep.payment,
        isLoading: false,
      );
      return true;
    } catch (e) {
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
  Future<void> cancelOrder() async {
    // In a real implementation, mark order as cancelled in database
    resetOrder();
  }
}

/// Order provider
final orderProvider = StateNotifierProvider<OrderNotifier, OrderState>((ref) {
  final supabaseService = ref.watch(supabaseServiceProvider);
  final documentService = ref.watch(documentServiceProvider);
  return OrderNotifier(supabaseService, documentService, ref);
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
