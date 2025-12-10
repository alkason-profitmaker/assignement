/// Model representing a registered residential society
class Society {
  final String id;
  final String name;
  final String address;
  final String city;
  final String pincode;
  final int? totalFlats;
  final String paytmMid;
  final String? contactName;
  final String? contactPhone;
  final String? contactEmail;
  final double commissionPercent;
  final bool isActive;
  final DateTime? onboardedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Society({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.pincode,
    this.totalFlats,
    required this.paytmMid,
    this.contactName,
    this.contactPhone,
    this.contactEmail,
    this.commissionPercent = 40.0,
    this.isActive = true,
    this.onboardedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Society.fromJson(Map<String, dynamic> json) {
    return Society(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      city: json['city'] as String,
      pincode: json['pincode'] as String,
      totalFlats: json['total_flats'] as int?,
      paytmMid: json['paytm_mid'] as String,
      contactName: json['contact_name'] as String?,
      contactPhone: json['contact_phone'] as String?,
      contactEmail: json['contact_email'] as String?,
      commissionPercent: (json['commission_percent'] as num?)?.toDouble() ?? 40.0,
      isActive: json['is_active'] as bool? ?? true,
      onboardedAt: json['onboarded_at'] != null
          ? DateTime.parse(json['onboarded_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'city': city,
      'pincode': pincode,
      'total_flats': totalFlats,
      'paytm_mid': paytmMid,
      'contact_name': contactName,
      'contact_phone': contactPhone,
      'contact_email': contactEmail,
      'commission_percent': commissionPercent,
      'is_active': isActive,
      'onboarded_at': onboardedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Society copyWith({
    String? id,
    String? name,
    String? address,
    String? city,
    String? pincode,
    int? totalFlats,
    String? paytmMid,
    String? contactName,
    String? contactPhone,
    String? contactEmail,
    double? commissionPercent,
    bool? isActive,
    DateTime? onboardedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Society(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      city: city ?? this.city,
      pincode: pincode ?? this.pincode,
      totalFlats: totalFlats ?? this.totalFlats,
      paytmMid: paytmMid ?? this.paytmMid,
      contactName: contactName ?? this.contactName,
      contactPhone: contactPhone ?? this.contactPhone,
      contactEmail: contactEmail ?? this.contactEmail,
      commissionPercent: commissionPercent ?? this.commissionPercent,
      isActive: isActive ?? this.isActive,
      onboardedAt: onboardedAt ?? this.onboardedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() => 'Society(id: $id, name: $name, city: $city)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Society && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
