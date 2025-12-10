/// Model representing user credits (goodwill credits for failures)
class Credit {
  final String id;
  final String userId;
  final int pagesBw;
  final int pagesColor;
  final int pagesBwUsed;
  final int pagesColorUsed;
  final String reason;
  final String? sourceOrderId;
  final DateTime expiresAt;
  final DateTime createdAt;

  Credit({
    required this.id,
    required this.userId,
    required this.pagesBw,
    this.pagesColor = 0,
    this.pagesBwUsed = 0,
    this.pagesColorUsed = 0,
    required this.reason,
    this.sourceOrderId,
    required this.expiresAt,
    required this.createdAt,
  });

  factory Credit.fromJson(Map<String, dynamic> json) {
    return Credit(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      pagesBw: json['pages_bw'] as int,
      pagesColor: json['pages_color'] as int? ?? 0,
      pagesBwUsed: json['pages_bw_used'] as int? ?? 0,
      pagesColorUsed: json['pages_color_used'] as int? ?? 0,
      reason: json['reason'] as String,
      sourceOrderId: json['source_order_id'] as String?,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'pages_bw': pagesBw,
      'pages_color': pagesColor,
      'pages_bw_used': pagesBwUsed,
      'pages_color_used': pagesColorUsed,
      'reason': reason,
      'source_order_id': sourceOrderId,
      'expires_at': expiresAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Remaining B/W pages
  int get remainingBwPages => pagesBw - pagesBwUsed;

  /// Remaining color pages
  int get remainingColorPages => pagesColor - pagesColorUsed;

  /// Check if credit is expired
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Check if credit has any remaining value
  bool get hasValue => !isExpired && (remainingBwPages > 0 || remainingColorPages > 0);

  Credit copyWith({
    String? id,
    String? userId,
    int? pagesBw,
    int? pagesColor,
    int? pagesBwUsed,
    int? pagesColorUsed,
    String? reason,
    String? sourceOrderId,
    DateTime? expiresAt,
    DateTime? createdAt,
  }) {
    return Credit(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      pagesBw: pagesBw ?? this.pagesBw,
      pagesColor: pagesColor ?? this.pagesColor,
      pagesBwUsed: pagesBwUsed ?? this.pagesBwUsed,
      pagesColorUsed: pagesColorUsed ?? this.pagesColorUsed,
      reason: reason ?? this.reason,
      sourceOrderId: sourceOrderId ?? this.sourceOrderId,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'Credit(id: $id, bw: $remainingBwPages, color: $remainingColorPages)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Credit && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Summary of user's available credits
class CreditSummary {
  final int totalBwPages;
  final int totalColorPages;
  final List<Credit> activeCredits;

  CreditSummary({
    required this.totalBwPages,
    required this.totalColorPages,
    required this.activeCredits,
  });

  bool get hasCredits => totalBwPages > 0 || totalColorPages > 0;

  /// Calculate credit value in paise
  int get valueInPaise {
    const bwPricePerPage = 300; // ₹3
    const colorPricePerPage = 1000; // ₹10
    return (totalBwPages * bwPricePerPage) + (totalColorPages * colorPricePerPage);
  }

  /// Calculate credit value in rupees
  double get valueInRupees => valueInPaise / 100;

  factory CreditSummary.fromCredits(List<Credit> credits) {
    final activeCredits = credits.where((c) => c.hasValue).toList();
    return CreditSummary(
      totalBwPages: activeCredits.fold(0, (sum, c) => sum + c.remainingBwPages),
      totalColorPages:
          activeCredits.fold(0, (sum, c) => sum + c.remainingColorPages),
      activeCredits: activeCredits,
    );
  }

  factory CreditSummary.empty() {
    return CreditSummary(
      totalBwPages: 0,
      totalColorPages: 0,
      activeCredits: [],
    );
  }
}
