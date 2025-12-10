import 'package:json_annotation/json_annotation.dart';

part 'society.g.dart';

/// Model representing a registered residential society
@JsonSerializable()
class Society {
  final String id;
  final String name;
  final String address;
  final String city;
  final String pincode;
  @JsonKey(name: 'total_flats')
  final int? totalFlats;
  @JsonKey(name: 'paytm_mid')
  final String paytmMid;
  @JsonKey(name: 'contact_name')
  final String? contactName;
  @JsonKey(name: 'contact_phone')
  final String? contactPhone;
  @JsonKey(name: 'contact_email')
  final String? contactEmail;
  @JsonKey(name: 'commission_percent')
  final double commissionPercent;
  @JsonKey(name: 'is_active')
  final bool isActive;
  @JsonKey(name: 'onboarded_at')
  final DateTime? onboardedAt;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;
  @JsonKey(name: 'updated_at')
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

  factory Society.fromJson(Map<String, dynamic> json) => _$SocietyFromJson(json);
  Map<String, dynamic> toJson() => _$SocietyToJson(this);

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
}
