import 'package:json_annotation/json_annotation.dart';

part 'user.g.dart';

/// Model representing a registered app user
@JsonSerializable()
class AppUser {
  final String id;
  final String phone;
  final String name;
  @JsonKey(name: 'society_id')
  final String societyId;
  @JsonKey(name: 'flat_number')
  final String flatNumber;
  final String? email;
  @JsonKey(name: 'total_orders')
  final int totalOrders;
  @JsonKey(name: 'total_pages')
  final int totalPages;
  @JsonKey(name: 'total_spent_paise')
  final int totalSpentPaise;
  @JsonKey(name: 'is_active')
  final bool isActive;
  @JsonKey(name: 'last_order_at')
  final DateTime? lastOrderAt;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  AppUser({
    required this.id,
    required this.phone,
    required this.name,
    required this.societyId,
    required this.flatNumber,
    this.email,
    this.totalOrders = 0,
    this.totalPages = 0,
    this.totalSpentPaise = 0,
    this.isActive = true,
    this.lastOrderAt,
    required this.createdAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => _$AppUserFromJson(json);
  Map<String, dynamic> toJson() => _$AppUserToJson(this);

  AppUser copyWith({
    String? id,
    String? phone,
    String? name,
    String? societyId,
    String? flatNumber,
    String? email,
    int? totalOrders,
    int? totalPages,
    int? totalSpentPaise,
    bool? isActive,
    DateTime? lastOrderAt,
    DateTime? createdAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      name: name ?? this.name,
      societyId: societyId ?? this.societyId,
      flatNumber: flatNumber ?? this.flatNumber,
      email: email ?? this.email,
      totalOrders: totalOrders ?? this.totalOrders,
      totalPages: totalPages ?? this.totalPages,
      totalSpentPaise: totalSpentPaise ?? this.totalSpentPaise,
      isActive: isActive ?? this.isActive,
      lastOrderAt: lastOrderAt ?? this.lastOrderAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Get total spent in rupees
  double get totalSpentRupees => totalSpentPaise / 100;

  /// Get formatted phone for display
  String get displayPhone => '+91 ${phone.substring(0, 5)} ${phone.substring(5)}';

  @override
  String toString() => 'AppUser(id: $id, name: $name, phone: $phone)';
}
