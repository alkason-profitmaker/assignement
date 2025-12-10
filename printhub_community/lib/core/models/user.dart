/// Model representing a registered app user
class AppUser {
  final String id;
  final String phone;
  final String name;
  final String societyId;
  final String flatNumber;
  final String? email;
  final int totalOrders;
  final int totalPages;
  final int totalSpentPaise;
  final bool isActive;
  final DateTime? lastOrderAt;
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

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      phone: json['phone'] as String,
      name: json['name'] as String,
      societyId: json['society_id'] as String,
      flatNumber: json['flat_number'] as String,
      email: json['email'] as String?,
      totalOrders: json['total_orders'] as int? ?? 0,
      totalPages: json['total_pages'] as int? ?? 0,
      totalSpentPaise: json['total_spent_paise'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      lastOrderAt: json['last_order_at'] != null
          ? DateTime.parse(json['last_order_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'name': name,
      'society_id': societyId,
      'flat_number': flatNumber,
      'email': email,
      'total_orders': totalOrders,
      'total_pages': totalPages,
      'total_spent_paise': totalSpentPaise,
      'is_active': isActive,
      'last_order_at': lastOrderAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUser && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
