import 'package:json_annotation/json_annotation.dart';

part 'station.g.dart';

/// Model representing a print station within a society
@JsonSerializable()
class Station {
  final String id;
  @JsonKey(name: 'society_id')
  final String societyId;
  final String name;
  @JsonKey(name: 'location_description')
  final String? locationDescription;
  @JsonKey(name: 'epson_printer_email')
  final String epsonPrinterEmail;
  @JsonKey(name: 'soundbox_id')
  final String? soundboxId;
  @JsonKey(name: 'has_color')
  final bool hasColor;
  @JsonKey(name: 'is_active')
  final bool isActive;
  @JsonKey(name: 'last_health_check')
  final DateTime? lastHealthCheck;
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  // Runtime status (not persisted)
  @JsonKey(includeFromJson: false, includeToJson: false)
  final StationStatus? currentStatus;

  Station({
    required this.id,
    required this.societyId,
    required this.name,
    this.locationDescription,
    required this.epsonPrinterEmail,
    this.soundboxId,
    this.hasColor = true,
    this.isActive = true,
    this.lastHealthCheck,
    required this.createdAt,
    this.currentStatus,
  });

  factory Station.fromJson(Map<String, dynamic> json) => _$StationFromJson(json);
  Map<String, dynamic> toJson() => _$StationToJson(this);

  Station copyWith({
    String? id,
    String? societyId,
    String? name,
    String? locationDescription,
    String? epsonPrinterEmail,
    String? soundboxId,
    bool? hasColor,
    bool? isActive,
    DateTime? lastHealthCheck,
    DateTime? createdAt,
    StationStatus? currentStatus,
  }) {
    return Station(
      id: id ?? this.id,
      societyId: societyId ?? this.societyId,
      name: name ?? this.name,
      locationDescription: locationDescription ?? this.locationDescription,
      epsonPrinterEmail: epsonPrinterEmail ?? this.epsonPrinterEmail,
      soundboxId: soundboxId ?? this.soundboxId,
      hasColor: hasColor ?? this.hasColor,
      isActive: isActive ?? this.isActive,
      lastHealthCheck: lastHealthCheck ?? this.lastHealthCheck,
      createdAt: createdAt ?? this.createdAt,
      currentStatus: currentStatus ?? this.currentStatus,
    );
  }

  /// Check if station is ready for printing
  bool get isReady => isActive && (currentStatus?.isOnline ?? true);

  @override
  String toString() => 'Station(id: $id, name: $name, isActive: $isActive)';
}

/// Real-time status of a print station
class StationStatus {
  final bool isOnline;
  final int inkLevelPercent;
  final int paperLevel; // Approximate sheets remaining
  final bool hasPaperJam;
  final String? errorMessage;
  final DateTime checkedAt;

  StationStatus({
    required this.isOnline,
    this.inkLevelPercent = 100,
    this.paperLevel = 100,
    this.hasPaperJam = false,
    this.errorMessage,
    required this.checkedAt,
  });

  bool get hasLowInk => inkLevelPercent < 10;
  bool get hasLowPaper => paperLevel < 20;
  bool get hasError => !isOnline || hasPaperJam || errorMessage != null;

  factory StationStatus.fromEpsonResponse(Map<String, dynamic> json) {
    return StationStatus(
      isOnline: json['connection'] == 'online',
      inkLevelPercent: json['ink_level'] ?? 100,
      paperLevel: json['paper_level'] ?? 100,
      hasPaperJam: json['error_code'] == 'PAPER_JAM',
      errorMessage: json['error_message'],
      checkedAt: DateTime.now(),
    );
  }

  factory StationStatus.offline() {
    return StationStatus(
      isOnline: false,
      checkedAt: DateTime.now(),
    );
  }
}
