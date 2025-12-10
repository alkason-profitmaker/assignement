import 'package:json_annotation/json_annotation.dart';

part 'credit.g.dart';

/// Model representing user credits (goodwill credits for failures)
@JsonSerializable()
class Credit {
  final String id;
  @JsonKey(name: 'user_id')
  final String userId;
  @JsonKey(name: 'pages_bw')
  final int pagesBw;
  @JsonKey(name: 'pages_color')
  final int pagesColor;
  @JsonKey(name: 'pages_bw_used')
  final int pagesBwUsed;
  @JsonKey(name: 'pages_color_used')
  final int pagesColorUsed;
  final String reason;
  @JsonKey(name: 'source_order_id')
  final String? sourceOrderId;
  @JsonKey(name: 'expires_at')
  final DateTime expiresAt;
  @JsonKey(name: 'created_at')
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

  factory Credit.fromJson(Map<String, dynamic> json) => _$CreditFromJson(json);
  Map<String, dynamic> toJson() => _$CreditToJson(this);

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
  String toString() => 'Credit(id: $id, bw: $remainingBwPages, color: $remainingColorPages)';
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
      totalColorPages: activeCredits.fold(0, (sum, c) => sum + c.remainingColorPages),
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
