import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/supabase_constants.dart';
import '../models/models.dart';

/// Service for all Supabase database operations
class SupabaseService {
  final SupabaseClient _client;

  SupabaseService() : _client = Supabase.instance.client;

  // ============================================
  // Authentication
  // ============================================

  /// Get current user ID
  String? get currentUserId => _client.auth.currentUser?.id;

  /// Check if user is authenticated
  bool get isAuthenticated => _client.auth.currentUser != null;

  /// Send OTP to phone number
  Future<void> sendOtp(String phone) async {
    await _client.auth.signInWithOtp(
      phone: '+91$phone',
    );
  }

  /// Verify OTP and sign in
  Future<AuthResponse> verifyOtp(String phone, String otp) async {
    return await _client.auth.verifyOTP(
      phone: '+91$phone',
      token: otp,
      type: OtpType.sms,
    );
  }

  /// Sign out
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // ============================================
  // User Operations
  // ============================================

  /// Get current user profile
  Future<AppUser?> getCurrentUser() async {
    final userId = currentUserId;
    if (userId == null) return null;

    final response = await _client
        .from(SupabaseConstants.usersTable)
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (response == null) return null;
    return AppUser.fromJson(response);
  }

  /// Create new user profile
  Future<AppUser> createUser({
    required String phone,
    required String name,
    required String societyId,
    required String flatNumber,
    String? email,
  }) async {
    final response = await _client
        .from(SupabaseConstants.usersTable)
        .insert({
          'id': currentUserId,
          'phone': phone,
          'name': name,
          'society_id': societyId,
          'flat_number': flatNumber,
          'email': email,
        })
        .select()
        .single();

    return AppUser.fromJson(response);
  }

  /// Update user profile
  Future<AppUser> updateUser({
    required String userId,
    String? name,
    String? email,
    String? flatNumber,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (email != null) updates['email'] = email;
    if (flatNumber != null) updates['flat_number'] = flatNumber;

    final response = await _client
        .from(SupabaseConstants.usersTable)
        .update(updates)
        .eq('id', userId)
        .select()
        .single();

    return AppUser.fromJson(response);
  }

  // ============================================
  // Society Operations
  // ============================================

  /// Get society by ID
  Future<Society?> getSociety(String societyId) async {
    final response = await _client
        .from(SupabaseConstants.societiesTable)
        .select()
        .eq('id', societyId)
        .maybeSingle();

    if (response == null) return null;
    return Society.fromJson(response);
  }

  /// Search societies by city/pincode
  Future<List<Society>> searchSocieties({
    String? city,
    String? pincode,
    String? query,
  }) async {
    var queryBuilder = _client
        .from(SupabaseConstants.societiesTable)
        .select()
        .eq('is_active', true);

    if (city != null) {
      queryBuilder = queryBuilder.ilike('city', '%$city%');
    }
    if (pincode != null) {
      queryBuilder = queryBuilder.eq('pincode', pincode);
    }
    if (query != null) {
      queryBuilder = queryBuilder.or('name.ilike.%$query%,address.ilike.%$query%');
    }

    final response = await queryBuilder.order('name');
    return response.map((json) => Society.fromJson(json)).toList();
  }

  // ============================================
  // Station Operations
  // ============================================

  /// Get stations for a society
  Future<List<Station>> getStations(String societyId) async {
    final response = await _client
        .from(SupabaseConstants.stationsTable)
        .select()
        .eq('society_id', societyId)
        .eq('is_active', true)
        .order('name');

    return response.map((json) => Station.fromJson(json)).toList();
  }

  /// Get station by ID
  Future<Station?> getStation(String stationId) async {
    final response = await _client
        .from(SupabaseConstants.stationsTable)
        .select()
        .eq('id', stationId)
        .maybeSingle();

    if (response == null) return null;
    return Station.fromJson(response);
  }

  // ============================================
  // Order Operations
  // ============================================

  /// Create new order
  Future<PrintOrder> createOrder({
    required String userId,
    required String societyId,
    required String stationId,
    required String fileName,
    String? fileHash,
    required int totalPages,
    required int bwPages,
    required int colorPages,
    int copies = 1,
    required int amountPaise,
    int creditsUsedPaise = 0,
    required int finalAmountPaise,
  }) async {
    final expiresAt = DateTime.now().add(const Duration(hours: 2));

    final response = await _client
        .from(SupabaseConstants.ordersTable)
        .insert({
          'user_id': userId,
          'society_id': societyId,
          'station_id': stationId,
          'file_name': fileName,
          'file_hash': fileHash,
          'total_pages': totalPages,
          'bw_pages': bwPages,
          'color_pages': colorPages,
          'copies': copies,
          'amount_paise': amountPaise,
          'credits_used_paise': creditsUsedPaise,
          'final_amount_paise': finalAmountPaise,
          'expires_at': expiresAt.toIso8601String(),
        })
        .select()
        .single();

    return PrintOrder.fromJson(response);
  }

  /// Get user's orders
  Future<List<PrintOrder>> getUserOrders({
    required String userId,
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _client
        .from(SupabaseConstants.ordersTable)
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return response.map((json) => PrintOrder.fromJson(json)).toList();
  }

  /// Get order by ID
  Future<PrintOrder?> getOrder(String orderId) async {
    final response = await _client
        .from(SupabaseConstants.ordersTable)
        .select()
        .eq('id', orderId)
        .maybeSingle();

    if (response == null) return null;
    return PrintOrder.fromJson(response);
  }

  /// Update order with Paytm order ID
  Future<PrintOrder> updateOrderPaytmId(String orderId, String paytmOrderId) async {
    final response = await _client
        .from(SupabaseConstants.ordersTable)
        .update({'paytm_order_id': paytmOrderId})
        .eq('id', orderId)
        .select()
        .single();

    return PrintOrder.fromJson(response);
  }

  /// Subscribe to order updates
  Stream<PrintOrder> subscribeToOrder(String orderId) {
    return _client
        .from(SupabaseConstants.ordersTable)
        .stream(primaryKey: ['id'])
        .eq('id', orderId)
        .map((data) => PrintOrder.fromJson(data.first));
  }

  // ============================================
  // Credit Operations
  // ============================================

  /// Get user's available credits
  Future<List<Credit>> getUserCredits(String userId) async {
    final now = DateTime.now().toIso8601String();
    final response = await _client
        .from(SupabaseConstants.creditsTable)
        .select()
        .eq('user_id', userId)
        .gt('expires_at', now)
        .order('expires_at');

    return response.map((json) => Credit.fromJson(json)).toList();
  }

  /// Get credit summary for user
  Future<CreditSummary> getCreditSummary(String userId) async {
    final credits = await getUserCredits(userId);
    return CreditSummary.fromCredits(credits);
  }

  // ============================================
  // Realtime Subscriptions
  // ============================================

  /// Subscribe to station status changes
  Stream<List<Station>> subscribeToStations(String societyId) {
    return _client
        .from(SupabaseConstants.stationsTable)
        .stream(primaryKey: ['id'])
        .eq('society_id', societyId)
        .map((data) => data.map((json) => Station.fromJson(json)).toList());
  }

  // ============================================
  // Edge Functions
  // ============================================

  /// Call edge function
  Future<Map<String, dynamic>> callFunction(
    String functionName,
    Map<String, dynamic> body,
  ) async {
    final response = await _client.functions.invoke(
      functionName,
      body: body,
    );

    if (response.status != 200) {
      throw Exception('Function call failed: ${response.status}');
    }

    return response.data as Map<String, dynamic>;
  }
}
