import 'package:equatable/equatable.dart';

/// User entity representing an authenticated user
class UserEntity extends Equatable {
  final String id;
  final String phoneNumber;
  final String? name;
  final String? flatNumber;
  final String? tower;
  final String societyId;
  final String? email;
  final String? avatarUrl;
  final bool isProfileComplete;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const UserEntity({
    required this.id,
    required this.phoneNumber,
    this.name,
    this.flatNumber,
    this.tower,
    required this.societyId,
    this.email,
    this.avatarUrl,
    this.isProfileComplete = false,
    required this.createdAt,
    this.updatedAt,
  });

  /// Check if user has completed profile setup
  bool get hasCompletedProfile =>
      name != null &&
      name!.isNotEmpty &&
      flatNumber != null &&
      flatNumber!.isNotEmpty;

  /// Get display name (name or phone number)
  String get displayName => name ?? phoneNumber;

  /// Get initials for avatar
  String get initials {
    if (name == null || name!.isEmpty) {
      return phoneNumber.substring(0, 2);
    }
    final parts = name!.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name![0].toUpperCase();
  }

  /// Get formatted flat info
  String get flatInfo {
    if (flatNumber == null) return '';
    if (tower != null && tower!.isNotEmpty) {
      return '$tower - $flatNumber';
    }
    return flatNumber!;
  }

  UserEntity copyWith({
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
    return UserEntity(
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

  @override
  List<Object?> get props => [
        id,
        phoneNumber,
        name,
        flatNumber,
        tower,
        societyId,
        email,
        avatarUrl,
        isProfileComplete,
        createdAt,
        updatedAt,
      ];
}
