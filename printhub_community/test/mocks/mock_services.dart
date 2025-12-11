import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:printhub_community/core/services/services.dart';
import 'package:printhub_community/core/models/models.dart';

// Mock Services
class MockSupabaseService extends Mock implements SupabaseService {}
class MockPaytmService extends Mock implements PaytmService {}
class MockEpsonService extends Mock implements EpsonService {}
class MockDocumentService extends Mock implements DocumentService {}
class MockNetworkService extends Mock implements NetworkService {}

// Mock Supabase
class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockGoTrueClient extends Mock implements GoTrueClient {}
class MockSupabaseStorageClient extends Mock implements SupabaseStorageClient {}

// Fake classes for mocktail
class FakeAppUser extends Fake implements AppUser {}
class FakeSociety extends Fake implements Society {}
class FakeStation extends Fake implements Station {}
class FakePrintOrder extends Fake implements PrintOrder {}
class FakeCredit extends Fake implements Credit {}
class FakeCreditSummary extends Fake implements CreditSummary {}

// Test data factory
class TestData {
  static AppUser createUser({
    String id = 'test-user-id',
    String phone = '9876543210',
    String name = 'Test User',
    String societyId = 'test-society-id',
    String flatNumber = 'A-101',
  }) {
    return AppUser(
      id: id,
      phone: phone,
      name: name,
      societyId: societyId,
      flatNumber: flatNumber,
      createdAt: DateTime.now(),
    );
  }

  static Society createSociety({
    String id = 'test-society-id',
    String name = 'Test Society',
    String address = '123 Test Street',
    String city = 'Mumbai',
    String pincode = '400001',
    String paytmMid = 'TEST_MID_123',
  }) {
    final now = DateTime.now();
    return Society(
      id: id,
      name: name,
      address: address,
      city: city,
      pincode: pincode,
      paytmMid: paytmMid,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    );
  }

  static Station createStation({
    String id = 'test-station-id',
    String societyId = 'test-society-id',
    String name = 'Lobby Printer',
    String? locationDescription = 'Ground Floor Lobby',
    bool isActive = true,
  }) {
    return Station(
      id: id,
      societyId: societyId,
      name: name,
      locationDescription: locationDescription,
      isActive: isActive,
      epsonPrinterEmail: 'printer@epson.connect',
      createdAt: DateTime.now(),
    );
  }

  static PrintOrder createOrder({
    String id = 'test-order-id',
    int orderNumber = 1,
    String userId = 'test-user-id',
    String societyId = 'test-society-id',
    String stationId = 'test-station-id',
    String fileName = 'test.pdf',
    int totalPages = 5,
    int bwPages = 4,
    int colorPages = 1,
    int copies = 1,
    String printStatus = 'WAITING',
    String paymentStatus = 'PENDING',
  }) {
    final now = DateTime.now();
    return PrintOrder(
      id: id,
      orderNumber: orderNumber,
      userId: userId,
      societyId: societyId,
      stationId: stationId,
      fileName: fileName,
      totalPages: totalPages,
      bwPages: bwPages,
      colorPages: colorPages,
      copies: copies,
      amountPaise: (bwPages * 300 + colorPages * 1000) * copies,
      finalAmountPaise: (bwPages * 300 + colorPages * 1000) * copies,
      printStatus: printStatus,
      paymentStatus: paymentStatus,
      createdAt: now,
      updatedAt: now,
      expiresAt: now.add(const Duration(hours: 2)),
    );
  }

  static Credit createCredit({
    String id = 'test-credit-id',
    String userId = 'test-user-id',
    int pagesBw = 5,
    int pagesColor = 2,
    String reason = 'Refund for failed print',
  }) {
    return Credit(
      id: id,
      userId: userId,
      pagesBw: pagesBw,
      pagesColor: pagesColor,
      reason: reason,
      expiresAt: DateTime.now().add(const Duration(days: 30)),
      createdAt: DateTime.now(),
    );
  }
}
