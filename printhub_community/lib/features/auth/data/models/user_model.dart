import '../../domain/entities/user_entity.dart';

/// User data model for API/database operations
class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.phoneNumber,
    super.name,
    super.flatNumber,
    super.tower,
    required super.societyId,
    super.email,
    super.avatarUrl,
    super.isProfileComplete,
    required super.createdAt,
    super.updatedAt,
  });

  /// Create UserModel from JSON
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      phoneNumber: json['phone_number'] as String,
      name: json['name'] as String?,
      flatNumber: json['flat_number'] as String?,
      tower: json['tower'] as String?,
      societyId: json['society_id'] as String? ?? 'pilot_society_001',
      email: json['email'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      isProfileComplete: json['is_profile_complete'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Convert UserModel to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone_number': phoneNumber,
      'name': name,
      'flat_number': flatNumber,
      'tower': tower,
      'society_id': societyId,
      'email': email,
      'avatar_url': avatarUrl,
      'is_profile_complete': isProfileComplete,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Create UserModel from UserEntity
  factory UserModel.fromEntity(UserEntity entity) {
    return UserModel(
      id: entity.id,
      phoneNumber: entity.phoneNumber,
      name: entity.name,
      flatNumber: entity.flatNumber,
      tower: entity.tower,
      societyId: entity.societyId,
      email: entity.email,
      avatarUrl: entity.avatarUrl,
      isProfileComplete: entity.isProfileComplete,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  /// Convert to UserEntity
  UserEntity toEntity() {
    return UserEntity(
      id: id,
      phoneNumber: phoneNumber,
      name: name,
      flatNumber: flatNumber,
      tower: tower,
      societyId: societyId,
      email: email,
      avatarUrl: avatarUrl,
      isProfileComplete: isProfileComplete,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  UserModel copyWith({
    String? id,
    String? phoneNumber,
    String? name,
    String? flatNumber,
    String? tower,
    String? societyId,
    String? email,
    String? avatarUrl,
    bool? isProfileComplete,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      name: name ?? this.name,
      flatNumber: flatNumber ?? this.flatNumber,
      tower: tower ?? this.tower,
      societyId: societyId ?? this.societyId,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
