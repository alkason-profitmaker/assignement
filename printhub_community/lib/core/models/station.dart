/// Model representing a print station within a society
class Station {
  final String id;
  final String societyId;
  final String name;
  final String? locationDescription;
  final String epsonPrinterEmail;
  final String? soundboxId;
  final bool hasColor;
  final bool isActive;
  final DateTime? lastHealthCheck;
  final DateTime createdAt;

  // IoT/Display fields
  final String? stationApiKey;
  final String displayType; // 'web', 'esp32', 'tablet'
  final DateTime? lastPollAt;
  final Map<String, dynamic>? displayDeviceInfo;

  // Runtime status (not persisted)
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
    this.stationApiKey,
    this.displayType = 'web',
    this.lastPollAt,
    this.displayDeviceInfo,
    this.currentStatus,
  });

  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      id: json['id'] as String,
      societyId: json['society_id'] as String,
      name: json['name'] as String,
      locationDescription: json['location_description'] as String?,
      epsonPrinterEmail: json['epson_printer_email'] as String,
      soundboxId: json['soundbox_id'] as String?,
      hasColor: json['has_color'] as bool? ?? true,
      isActive: json['is_active'] as bool? ?? true,
      lastHealthCheck: json['last_health_check'] != null
          ? DateTime.parse(json['last_health_check'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      stationApiKey: json['station_api_key'] as String?,
      displayType: json['display_type'] as String? ?? 'web',
      lastPollAt: json['last_poll_at'] != null
          ? DateTime.parse(json['last_poll_at'] as String)
          : null,
      displayDeviceInfo: json['display_device_info'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'society_id': societyId,
      'name': name,
      'location_description': locationDescription,
      'epson_printer_email': epsonPrinterEmail,
      'soundbox_id': soundboxId,
      'has_color': hasColor,
      'is_active': isActive,
      'last_health_check': lastHealthCheck?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'station_api_key': stationApiKey,
      'display_type': displayType,
      'last_poll_at': lastPollAt?.toIso8601String(),
      'display_device_info': displayDeviceInfo,
    };
  }

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
    String? stationApiKey,
    String? displayType,
    DateTime? lastPollAt,
    Map<String, dynamic>? displayDeviceInfo,
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
      stationApiKey: stationApiKey ?? this.stationApiKey,
      displayType: displayType ?? this.displayType,
      lastPollAt: lastPollAt ?? this.lastPollAt,
      displayDeviceInfo: displayDeviceInfo ?? this.displayDeviceInfo,
      currentStatus: currentStatus ?? this.currentStatus,
    );
  }

  /// Check if station is ready for printing
  bool get isReady => isActive && (currentStatus?.isOnline ?? true);

  @override
  String toString() => 'Station(id: $id, name: $name, isActive: $isActive)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Station && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
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
      inkLevelPercent: json['ink_level'] as int? ?? 100,
      paperLevel: json['paper_level'] as int? ?? 100,
      hasPaperJam: json['error_code'] == 'PAPER_JAM',
      errorMessage: json['error_message'] as String?,
      checkedAt: DateTime.now(),
    );
  }

  factory StationStatus.offline() {
    return StationStatus(
      isOnline: false,
      checkedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'is_online': isOnline,
      'ink_level_percent': inkLevelPercent,
      'paper_level': paperLevel,
      'has_paper_jam': hasPaperJam,
      'error_message': errorMessage,
      'checked_at': checkedAt.toIso8601String(),
    };
  }
}
