import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:printhub_community/core/models/models.dart';
import 'package:printhub_community/core/services/services.dart';
import 'package:printhub_community/core/error/failures.dart';
import 'package:printhub_community/data/repositories/order_repository.dart';

class MockSupabaseService extends Mock implements SupabaseService {}
class MockPaytmService extends Mock implements PaytmService {}
class MockDocumentService extends Mock implements DocumentService {}

void main() {
  late OrderRepositoryImpl repository;
  late MockSupabaseService mockSupabase;
  late MockPaytmService mockPaytm;
  late MockDocumentService mockDocument;

  setUp(() {
    mockSupabase = MockSupabaseService();
    mockPaytm = MockPaytmService();
    mockDocument = MockDocumentService();
    repository = OrderRepositoryImpl(
      mockSupabase,
      mockPaytm,
      mockDocument,
    );
  });

  group('createOrder', () {
    final testStation = Station(
      id: 'station-123',
      societyId: 'society-456',
      name: 'Test Station',
      location: 'Lobby',
      isActive: true,
      isOnline: true,
      epsonPrinterEmail: 'printer@epson.connect',
      createdAt: DateTime.now(),
    );

    final testOrder = PrintOrder(
      id: 'order-789',
      oderId: 'ORD-789',
      userId: 'user-123',
      societyId: 'society-456',
      stationId: 'station-123',
      fileName: 'test.pdf',
      totalPages: 5,
      bwPages: 4,
      colorPages: 1,
      copies: 1,
      amountPaise: 2200,
      finalAmountPaise: 2200,
      status: 'pending',
      paymentStatus: 'pending',
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(hours: 2)),
    );

    test('returns AuthFailure when user not authenticated', () async {
      when(() => mockSupabase.currentUserId).thenReturn(null);

      final request = CreateOrderRequest(
        stationId: 'station-123',
        fileName: 'test.pdf',
        totalPages: 5,
        bwPages: 4,
        colorPages: 1,
        fileBytes: [1, 2, 3],
      );

      final result = await repository.createOrder(request);

      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<AuthFailure>()),
        (_) => fail('Expected failure'),
      );
    });

    test('returns ValidationFailure for zero pages', () async {
      when(() => mockSupabase.currentUserId).thenReturn('user-123');

      final request = CreateOrderRequest(
        stationId: 'station-123',
        fileName: 'test.pdf',
        totalPages: 0,
        bwPages: 0,
        colorPages: 0,
        fileBytes: [1, 2, 3],
      );

      final result = await repository.createOrder(request);

      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<ValidationFailure>()),
        (_) => fail('Expected failure'),
      );
    });

    test('returns ServerFailure when station not found', () async {
      when(() => mockSupabase.currentUserId).thenReturn('user-123');
      when(() => mockSupabase.getStation(any())).thenAnswer((_) async => null);

      final request = CreateOrderRequest(
        stationId: 'station-123',
        fileName: 'test.pdf',
        totalPages: 5,
        bwPages: 4,
        colorPages: 1,
        fileBytes: [1, 2, 3],
      );

      final result = await repository.createOrder(request);

      expect(result.isLeft(), true);
      result.fold(
        (failure) {
          expect(failure, isA<ServerFailure>());
          expect((failure as ServerFailure).code, 'STATION_NOT_FOUND');
        },
        (_) => fail('Expected failure'),
      );
    });

    test('creates order successfully', () async {
      when(() => mockSupabase.currentUserId).thenReturn('user-123');
      when(() => mockSupabase.getStation(any())).thenAnswer((_) async => testStation);
      when(() => mockSupabase.createOrder(
        userId: any(named: 'userId'),
        societyId: any(named: 'societyId'),
        stationId: any(named: 'stationId'),
        fileName: any(named: 'fileName'),
        fileHash: any(named: 'fileHash'),
        totalPages: any(named: 'totalPages'),
        bwPages: any(named: 'bwPages'),
        colorPages: any(named: 'colorPages'),
        copies: any(named: 'copies'),
        amountPaise: any(named: 'amountPaise'),
        finalAmountPaise: any(named: 'finalAmountPaise'),
      )).thenAnswer((_) async => testOrder);

      final request = CreateOrderRequest(
        stationId: 'station-123',
        fileName: 'test.pdf',
        totalPages: 5,
        bwPages: 4,
        colorPages: 1,
        fileBytes: [1, 2, 3],
      );

      final result = await repository.createOrder(request);

      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Expected success'),
        (order) {
          expect(order.id, 'order-789');
          expect(order.fileName, 'test.pdf');
        },
      );
    });
  });

  group('getUserOrders', () {
    test('returns AuthFailure when not authenticated', () async {
      when(() => mockSupabase.currentUserId).thenReturn(null);

      final result = await repository.getUserOrders();

      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<AuthFailure>()),
        (_) => fail('Expected failure'),
      );
    });

    test('returns orders successfully', () async {
      when(() => mockSupabase.currentUserId).thenReturn('user-123');
      when(() => mockSupabase.getUserOrders(
        userId: any(named: 'userId'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      )).thenAnswer((_) async => []);

      final result = await repository.getUserOrders();

      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Expected success'),
        (orders) => expect(orders, isEmpty),
      );
    });
  });

  group('getOrderById', () {
    test('returns order when found', () async {
      final testOrder = PrintOrder(
        id: 'order-123',
        oderId: 'ORD-123',
        userId: 'user-123',
        societyId: 'society-456',
        stationId: 'station-789',
        fileName: 'test.pdf',
        totalPages: 5,
        bwPages: 4,
        colorPages: 1,
        copies: 1,
        amountPaise: 2200,
        finalAmountPaise: 2200,
        status: 'pending',
        paymentStatus: 'pending',
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 2)),
      );

      when(() => mockSupabase.getOrderById(any())).thenAnswer((_) async => testOrder);

      final result = await repository.getOrderById('order-123');

      expect(result.isRight(), true);
      result.fold(
        (_) => fail('Expected success'),
        (order) => expect(order.id, 'order-123'),
      );
    });

    test('returns failure when not found', () async {
      when(() => mockSupabase.getOrderById(any())).thenAnswer((_) async => null);

      final result = await repository.getOrderById('non-existent');

      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (_) => fail('Expected failure'),
      );
    });
  });
}
