import 'package:dartz/dartz.dart';

import '../../core/error/failures.dart';
import '../../core/models/order.dart';
import '../../core/models/document.dart';
import '../../core/models/society.dart';
import '../../core/services/supabase_service.dart';
import '../../core/services/paytm_service.dart';
import '../../core/services/document_service.dart';

/// Order repository interface
abstract class OrderRepository {
  /// Create a new print order
  Future<Either<Failure, PrintOrder>> createOrder(CreateOrderRequest request);

  /// Get order by ID
  Future<Either<Failure, PrintOrder>> getOrderById(String orderId);

  /// Get user's order history
  Future<Either<Failure, List<PrintOrder>>> getUserOrders({
    int limit = 20,
    int offset = 0,
  });

  /// Get active/pending orders
  Future<Either<Failure, List<PrintOrder>>> getActiveOrders();

  /// Generate payment QR code for order
  Future<Either<Failure, PaymentQrData>> generatePaymentQr(String orderId);

  /// Check payment status
  Future<Either<Failure, PaymentCheckResult>> checkPaymentStatus(String orderId);

  /// Request refund for order
  Future<Either<Failure, void>> requestRefund(String orderId, String reason);

  /// Upload document for order
  Future<Either<Failure, String>> uploadDocument(String orderId, PrintDocument document);

  /// Stream of order updates
  Stream<PrintOrder> watchOrder(String orderId);
}

/// Payment QR data
class PaymentQrData {
  final String qrString;
  final String orderId;
  final int amountPaise;
  final DateTime expiresAt;

  PaymentQrData({
    required this.qrString,
    required this.orderId,
    required this.amountPaise,
    required this.expiresAt,
  });
}

/// Payment check result enum (distinct from model PaymentStatus)
enum PaymentCheckResult {
  pending,
  processing,
  success,
  failed,
  refunded,
}

/// Implementation of OrderRepository
class OrderRepositoryImpl implements OrderRepository {
  final SupabaseService _supabaseService;
  final PaytmService _paytmService;
  final DocumentService _documentService;

  OrderRepositoryImpl(
    this._supabaseService,
    this._paytmService,
    this._documentService,
  );

  @override
  Future<Either<Failure, PrintOrder>> createOrder(CreateOrderRequest request) async {
    try {
      // Validate user is authenticated
      final userId = _supabaseService.currentUserId;
      if (userId == null) {
        return Left(AuthFailure(message: 'User not authenticated'));
      }

      // Validate request
      if (request.totalPages <= 0) {
        return Left(ValidationFailure(
          message: 'Invalid page count',
          fieldErrors: {'pages': 'Must have at least 1 page'},
        ));
      }

      // Get station to find society
      final station = await _supabaseService.getStation(request.stationId);
      if (station == null) {
        return Left(ServerFailure(
          message: 'Station not found',
          code: 'STATION_NOT_FOUND',
        ));
      }

      // Get society for pricing
      final society = await _supabaseService.getSociety(station.societyId);

      // Calculate price using society's pricing (or defaults)
      final int amountPaise;
      if (society != null) {
        amountPaise = society.calculatePrice(
          bwPages: request.bwPages,
          colorPages: request.colorPages,
          copies: request.copies,
        );
      } else {
        // Fallback to default pricing
        amountPaise = PrintOrder.calculatePrice(
          bwPages: request.bwPages,
          colorPages: request.colorPages,
          copies: request.copies,
        );
      }

      // Create order in database
      final order = await _supabaseService.createOrder(
        userId: userId,
        societyId: station.societyId,
        stationId: request.stationId,
        fileName: request.fileName,
        fileHash: request.fileHash,
        totalPages: request.totalPages,
        bwPages: request.bwPages,
        colorPages: request.colorPages,
        copies: request.copies,
        amountPaise: amountPaise,
        finalAmountPaise: amountPaise,
      );

      return Right(order);
    } catch (e) {
      return Left(ServerFailure(
        message: 'Failed to create order',
        originalError: e,
      ));
    }
  }

  @override
  Future<Either<Failure, PrintOrder>> getOrderById(String orderId) async {
    try {
      final order = await _supabaseService.getOrderById(orderId);
      if (order == null) {
        return Left(ServerFailure(
          message: 'Order not found',
          code: 'ORDER_NOT_FOUND',
        ));
      }
      return Right(order);
    } catch (e) {
      return Left(ServerFailure(
        message: 'Failed to fetch order',
        originalError: e,
      ));
    }
  }

  @override
  Future<Either<Failure, List<PrintOrder>>> getUserOrders({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final userId = _supabaseService.currentUserId;
      if (userId == null) {
        return Left(AuthFailure(message: 'User not authenticated'));
      }

      final orders = await _supabaseService.getUserOrders(
        userId: userId,
        limit: limit,
        offset: offset,
      );
      return Right(orders);
    } catch (e) {
      return Left(ServerFailure(
        message: 'Failed to fetch orders',
        originalError: e,
      ));
    }
  }

  @override
  Future<Either<Failure, List<PrintOrder>>> getActiveOrders() async {
    try {
      final orders = await _supabaseService.getActiveOrders();
      return Right(orders);
    } catch (e) {
      return Left(ServerFailure(
        message: 'Failed to fetch active orders',
        originalError: e,
      ));
    }
  }

  @override
  Future<Either<Failure, PaymentQrData>> generatePaymentQr(String orderId) async {
    try {
      // Get order details
      final orderResult = await getOrderById(orderId);
      return orderResult.fold(
        (failure) => Left(failure),
        (order) async {
          try {
            // Generate Paytm QR
            final qrData = await _paytmService.generateDynamicQr(
              orderId: orderId,
              amount: order.finalAmountPaise / 100,
            );

            if (qrData.qrString == null) {
              return Left(PaymentFailure(
                message: qrData.errorMessage ?? 'Failed to generate QR code',
                code: qrData.errorCode,
              ));
            }

            // Update order with Paytm order ID if available
            if (qrData.paytmOrderId != null) {
              await _supabaseService.updateOrder(
                orderId: orderId,
                paytmOrderId: qrData.paytmOrderId,
              );
            }

            return Right(PaymentQrData(
              qrString: qrData.qrString!,
              orderId: orderId,
              amountPaise: order.finalAmountPaise,
              expiresAt: DateTime.now().add(const Duration(minutes: 15)),
            ));
          } catch (e) {
            return Left(PaymentFailure(
              message: 'Failed to generate payment QR',
              originalError: e,
            ));
          }
        },
      );
    } catch (e) {
      return Left(PaymentFailure(
        message: 'Failed to generate payment QR',
        originalError: e,
      ));
    }
  }

  @override
  Future<Either<Failure, PaymentCheckResult>> checkPaymentStatus(String orderId) async {
    try {
      final order = await _supabaseService.getOrderById(orderId);
      if (order == null) {
        return Left(ServerFailure(
          message: 'Order not found',
          code: 'ORDER_NOT_FOUND',
        ));
      }

      switch (order.paymentStatus) {
        case 'PENDING':
          return const Right(PaymentCheckResult.pending);
        case 'PROCESSING':
          return const Right(PaymentCheckResult.processing);
        case 'PAID':
          return const Right(PaymentCheckResult.success);
        case 'FAILED':
          return const Right(PaymentCheckResult.failed);
        case 'REFUNDED':
          return const Right(PaymentCheckResult.refunded);
        default:
          return const Right(PaymentCheckResult.pending);
      }
    } catch (e) {
      return Left(ServerFailure(
        message: 'Failed to check payment status',
        originalError: e,
      ));
    }
  }

  @override
  Future<Either<Failure, void>> requestRefund(String orderId, String reason) async {
    try {
      final order = await _supabaseService.getOrderById(orderId);
      if (order == null) {
        return Left(ServerFailure(message: 'Order not found'));
      }

      if (!order.canBeRefunded) {
        return Left(PaymentFailure(
          message: 'This order cannot be refunded',
          code: 'REFUND_NOT_ALLOWED',
        ));
      }

      // Process refund through Paytm
      if (order.paytmTxnId != null) {
        await _paytmService.initiateRefund(
          orderId: order.paytmOrderId!,
          txnId: order.paytmTxnId!,
          amount: order.finalAmountPaise / 100,
          refundId: 'REF_${orderId}_${DateTime.now().millisecondsSinceEpoch}',
        );
      }

      // Update order status
      await _supabaseService.updateOrder(
        orderId: orderId,
        refundStatus: 'INITIATED',
        refundReason: reason,
        refundType: 'USER_REQUEST',
      );

      return const Right(null);
    } catch (e) {
      return Left(PaymentFailure.refundFailed(e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> uploadDocument(
    String orderId,
    PrintDocument document,
  ) async {
    try {
      // Prepare document for printing (convert images to PDF)
      final printBytes = await _documentService.prepareForPrinting(document);

      // Upload to Supabase storage
      final path = await _supabaseService.uploadDocument(
        orderId: orderId,
        fileName: document.name,
        bytes: printBytes,
      );

      return Right(path);
    } catch (e) {
      return Left(DocumentFailure(
        message: 'Failed to upload document',
        originalError: e,
      ));
    }
  }

  @override
  Stream<PrintOrder> watchOrder(String orderId) {
    return _supabaseService.watchOrder(orderId);
  }
}
