import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../../core/constants/app_constants.dart';

// ============ EVENTS ============

abstract class PaymentEvent extends Equatable {
  const PaymentEvent();

  @override
  List<Object?> get props => [];
}

class InitiatePaymentEvent extends PaymentEvent {
  final String printJobId;
  final double amount;

  const InitiatePaymentEvent({
    required this.printJobId,
    required this.amount,
  });

  @override
  List<Object?> get props => [printJobId, amount];
}

class PaymentSuccessEvent extends PaymentEvent {
  final String orderId;
  final String paymentId;
  final String signature;

  const PaymentSuccessEvent({
    required this.orderId,
    required this.paymentId,
    required this.signature,
  });

  @override
  List<Object?> get props => [orderId, paymentId, signature];
}

class PaymentFailureEvent extends PaymentEvent {
  final String code;
  final String message;

  const PaymentFailureEvent({
    required this.code,
    required this.message,
  });

  @override
  List<Object?> get props => [code, message];
}

class ResetPaymentEvent extends PaymentEvent {}

// ============ STATES ============

abstract class PaymentState extends Equatable {
  const PaymentState();

  @override
  List<Object?> get props => [];
}

class PaymentInitial extends PaymentState {}

class PaymentLoading extends PaymentState {
  final String message;

  const PaymentLoading({this.message = 'Processing...'});

  @override
  List<Object?> get props => [message];
}

class PaymentOrderCreated extends PaymentState {
  final String orderId;
  final double amount;
  final String keyId;

  const PaymentOrderCreated({
    required this.orderId,
    required this.amount,
    required this.keyId,
  });

  @override
  List<Object?> get props => [orderId, amount, keyId];
}

class PaymentSuccess extends PaymentState {
  final String printJobId;
  final String pickupCode;
  final double amount;

  const PaymentSuccess({
    required this.printJobId,
    required this.pickupCode,
    required this.amount,
  });

  @override
  List<Object?> get props => [printJobId, pickupCode, amount];
}

class PaymentFailed extends PaymentState {
  final String message;

  const PaymentFailed(this.message);

  @override
  List<Object?> get props => [message];
}

// ============ BLOC ============

class PaymentBloc extends Bloc<PaymentEvent, PaymentState> {
  final SupabaseClient _supabase = Supabase.instance.client;
  Razorpay? _razorpay;
  String? _currentPrintJobId;
  double? _currentAmount;

  PaymentBloc() : super(PaymentInitial()) {
    on<InitiatePaymentEvent>(_onInitiatePayment);
    on<PaymentSuccessEvent>(_onPaymentSuccess);
    on<PaymentFailureEvent>(_onPaymentFailure);
    on<ResetPaymentEvent>(_onReset);

    _initRazorpay();
  }

  void _initRazorpay() {
    _razorpay = Razorpay();
    _razorpay?.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay?.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay?.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    add(PaymentSuccessEvent(
      orderId: response.orderId ?? '',
      paymentId: response.paymentId ?? '',
      signature: response.signature ?? '',
    ));
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    add(PaymentFailureEvent(
      code: response.code?.toString() ?? 'UNKNOWN',
      message: response.message ?? 'Payment failed',
    ));
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    // Handle external wallet selection
  }

  Future<void> _onInitiatePayment(
    InitiatePaymentEvent event,
    Emitter<PaymentState> emit,
  ) async {
    try {
      emit(const PaymentLoading(message: 'Creating payment order...'));

      _currentPrintJobId = event.printJobId;
      _currentAmount = event.amount;

      // Call Supabase Edge Function to create Razorpay order
      final response = await _supabase.functions.invoke(
        'create-payment-order',
        body: {
          'printJobId': event.printJobId,
          'amount': event.amount,
        },
      );

      if (response.status != 200) {
        throw Exception(response.data['error'] ?? 'Failed to create order');
      }

      final data = response.data as Map<String, dynamic>;
      final orderId = data['orderId'] as String;
      final keyId = data['keyId'] as String;

      // Open Razorpay checkout
      final user = _supabase.auth.currentUser;
      final userProfile = await _supabase
          .from('users')
          .select('name, phone_number, email')
          .eq('id', user?.id ?? '')
          .single();

      final options = {
        'key': keyId,
        'amount': (event.amount * 100).toInt(),
        'currency': 'INR',
        'order_id': orderId,
        'name': 'PrintHub Community',
        'description': 'Print Job Payment',
        'prefill': {
          'contact': userProfile['phone_number'] ?? '',
          'email': userProfile['email'] ?? '',
          'name': userProfile['name'] ?? '',
        },
        'theme': {
          'color': '#2563EB',
        },
        'modal': {
          'confirm_close': true,
        },
      };

      _razorpay?.open(options);

      emit(PaymentOrderCreated(
        orderId: orderId,
        amount: event.amount,
        keyId: keyId,
      ));
    } catch (e) {
      emit(PaymentFailed(e.toString()));
    }
  }

  Future<void> _onPaymentSuccess(
    PaymentSuccessEvent event,
    Emitter<PaymentState> emit,
  ) async {
    try {
      emit(const PaymentLoading(message: 'Verifying payment...'));

      // Verify payment via webhook (Edge Function)
      final response = await _supabase.functions.invoke(
        'handle-payment-webhook',
        body: {
          'razorpay_order_id': event.orderId,
          'razorpay_payment_id': event.paymentId,
          'razorpay_signature': event.signature,
        },
      );

      if (response.status != 200) {
        throw Exception(response.data['error'] ?? 'Payment verification failed');
      }

      final data = response.data as Map<String, dynamic>;
      final pickupCode = data['pickupCode'] as String? ?? '';

      emit(PaymentSuccess(
        printJobId: _currentPrintJobId ?? '',
        pickupCode: pickupCode,
        amount: _currentAmount ?? 0,
      ));
    } catch (e) {
      emit(PaymentFailed('Payment verification failed: ${e.toString()}'));
    }
  }

  void _onPaymentFailure(
    PaymentFailureEvent event,
    Emitter<PaymentState> emit,
  ) {
    String message;
    switch (event.code) {
      case 'PAYMENT_CANCELLED':
        message = 'Payment was cancelled';
        break;
      case 'NETWORK_ERROR':
        message = 'Network error. Please try again.';
        break;
      case 'INVALID_OPTIONS':
        message = 'Invalid payment options';
        break;
      default:
        message = event.message;
    }
    emit(PaymentFailed(message));
  }

  void _onReset(
    ResetPaymentEvent event,
    Emitter<PaymentState> emit,
  ) {
    _currentPrintJobId = null;
    _currentAmount = null;
    emit(PaymentInitial());
  }

  @override
  Future<void> close() {
    _razorpay?.clear();
    return super.close();
  }
}
