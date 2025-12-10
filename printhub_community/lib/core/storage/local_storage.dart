import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../logging/app_logger.dart';

/// Local storage service for PrintHub
///
/// Uses:
/// - SharedPreferences for non-sensitive data
/// - FlutterSecureStorage for sensitive data (tokens, keys)
class LocalStorage {
  static LocalStorage? _instance;
  static SharedPreferences? _prefs;
  static FlutterSecureStorage? _secureStorage;

  LocalStorage._();

  static Future<LocalStorage> getInstance() async {
    if (_instance == null) {
      _instance = LocalStorage._();
      _prefs = await SharedPreferences.getInstance();
      _secureStorage = const FlutterSecureStorage(
        aOptions: AndroidOptions(
          encryptedSharedPreferences: true,
        ),
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
        ),
      );
    }
    return _instance!;
  }

  // ============================================
  // Non-sensitive data (SharedPreferences)
  // ============================================

  /// Save string value
  Future<bool> setString(String key, String value) async {
    try {
      return await _prefs!.setString(key, value);
    } catch (e) {
      AppLogger.error('Failed to save string', error: e, data: {'key': key});
      return false;
    }
  }

  /// Get string value
  String? getString(String key) {
    return _prefs!.getString(key);
  }

  /// Save int value
  Future<bool> setInt(String key, int value) async {
    return await _prefs!.setInt(key, value);
  }

  /// Get int value
  int? getInt(String key) {
    return _prefs!.getInt(key);
  }

  /// Save bool value
  Future<bool> setBool(String key, bool value) async {
    return await _prefs!.setBool(key, value);
  }

  /// Get bool value
  bool? getBool(String key) {
    return _prefs!.getBool(key);
  }

  /// Save JSON object
  Future<bool> setJson(String key, Map<String, dynamic> value) async {
    try {
      return await _prefs!.setString(key, jsonEncode(value));
    } catch (e) {
      AppLogger.error('Failed to save JSON', error: e, data: {'key': key});
      return false;
    }
  }

  /// Get JSON object
  Map<String, dynamic>? getJson(String key) {
    try {
      final value = _prefs!.getString(key);
      if (value == null) return null;
      return jsonDecode(value) as Map<String, dynamic>;
    } catch (e) {
      AppLogger.error('Failed to parse JSON', error: e, data: {'key': key});
      return null;
    }
  }

  /// Remove value
  Future<bool> remove(String key) async {
    return await _prefs!.remove(key);
  }

  /// Clear all non-sensitive data
  Future<bool> clear() async {
    return await _prefs!.clear();
  }

  // ============================================
  // Sensitive data (FlutterSecureStorage)
  // ============================================

  /// Save secure string
  Future<void> setSecureString(String key, String value) async {
    try {
      await _secureStorage!.write(key: key, value: value);
    } catch (e) {
      AppLogger.error('Failed to save secure string', error: e, data: {'key': key});
      rethrow;
    }
  }

  /// Get secure string
  Future<String?> getSecureString(String key) async {
    try {
      return await _secureStorage!.read(key: key);
    } catch (e) {
      AppLogger.error('Failed to read secure string', error: e, data: {'key': key});
      return null;
    }
  }

  /// Delete secure value
  Future<void> deleteSecure(String key) async {
    await _secureStorage!.delete(key: key);
  }

  /// Clear all secure data
  Future<void> clearSecure() async {
    await _secureStorage!.deleteAll();
  }

  // ============================================
  // Convenience methods for common data
  // ============================================

  static const String _keyOnboarded = 'user_onboarded';
  static const String _keyLastSocietyId = 'last_society_id';
  static const String _keyLastStationId = 'last_station_id';
  static const String _keyUserPrefs = 'user_preferences';
  static const String _keyAuthToken = 'auth_token';
  static const String _keyRefreshToken = 'refresh_token';

  /// Check if user completed onboarding
  bool get isOnboarded => getBool(_keyOnboarded) ?? false;
  Future<void> setOnboarded(bool value) => setBool(_keyOnboarded, value);

  /// Last selected society
  String? get lastSocietyId => getString(_keyLastSocietyId);
  Future<void> setLastSocietyId(String id) => setString(_keyLastSocietyId, id);

  /// Last selected station
  String? get lastStationId => getString(_keyLastStationId);
  Future<void> setLastStationId(String id) => setString(_keyLastStationId, id);

  /// User preferences
  UserPreferences get userPreferences {
    final json = getJson(_keyUserPrefs);
    return json != null ? UserPreferences.fromJson(json) : UserPreferences();
  }

  Future<void> setUserPreferences(UserPreferences prefs) => setJson(_keyUserPrefs, prefs.toJson());

  /// Auth token (secure)
  Future<String?> getAuthToken() => getSecureString(_keyAuthToken);
  Future<void> setAuthToken(String token) => setSecureString(_keyAuthToken, token);

  /// Refresh token (secure)
  Future<String?> getRefreshToken() => getSecureString(_keyRefreshToken);
  Future<void> setRefreshToken(String token) => setSecureString(_keyRefreshToken, token);

  /// Clear all auth data on logout
  Future<void> clearAuthData() async {
    await deleteSecure(_keyAuthToken);
    await deleteSecure(_keyRefreshToken);
    await remove(_keyLastSocietyId);
    await remove(_keyLastStationId);
  }
}

/// User preferences model
class UserPreferences {
  final bool notificationsEnabled;
  final bool darkModeEnabled;
  final String defaultColorMode; // 'auto', 'bw', 'color'
  final int defaultCopies;

  UserPreferences({
    this.notificationsEnabled = true,
    this.darkModeEnabled = false,
    this.defaultColorMode = 'auto',
    this.defaultCopies = 1,
  });

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      notificationsEnabled: json['notifications_enabled'] as bool? ?? true,
      darkModeEnabled: json['dark_mode_enabled'] as bool? ?? false,
      defaultColorMode: json['default_color_mode'] as String? ?? 'auto',
      defaultCopies: json['default_copies'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'notifications_enabled': notificationsEnabled,
        'dark_mode_enabled': darkModeEnabled,
        'default_color_mode': defaultColorMode,
        'default_copies': defaultCopies,
      };

  UserPreferences copyWith({
    bool? notificationsEnabled,
    bool? darkModeEnabled,
    String? defaultColorMode,
    int? defaultCopies,
  }) {
    return UserPreferences(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      darkModeEnabled: darkModeEnabled ?? this.darkModeEnabled,
      defaultColorMode: defaultColorMode ?? this.defaultColorMode,
      defaultCopies: defaultCopies ?? this.defaultCopies,
    );
  }
}
