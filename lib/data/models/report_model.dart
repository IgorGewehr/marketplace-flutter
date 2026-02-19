/// Report model for reporting suspicious or prohibited content
library;

class ReportModel {
  final String id;
  final String reporterUserId;
  final String targetId; // productId, tenantId, userId, reviewId
  final String targetType; // product, seller, user, review
  final String reason;
  final String? details;
  final List<String> evidenceImages;
  final String status; // pending, under_review, resolved, dismissed
  final String? resolution;
  final String? resolvedByUserId;
  final DateTime? resolvedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ReportModel({
    required this.id,
    required this.reporterUserId,
    required this.targetId,
    required this.targetType,
    required this.reason,
    this.details,
    this.evidenceImages = const [],
    this.status = 'pending',
    this.resolution,
    this.resolvedByUserId,
    this.resolvedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Check if report is pending
  bool get isPending => status == 'pending';

  /// Check if report is under review
  bool get isUnderReview => status == 'under_review';

  /// Check if report is resolved
  bool get isResolved => status == 'resolved';

  /// Check if report is dismissed
  bool get isDismissed => status == 'dismissed';

  /// Check if report has evidence images
  bool get hasEvidence => evidenceImages.isNotEmpty;

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      id: json['id'] as String? ?? '',
      reporterUserId: json['reporterUserId'] as String? ?? '',
      targetId: json['targetId'] as String? ?? '',
      targetType: json['targetType'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      details: json['details'] as String?,
      evidenceImages: (json['evidenceImages'] as List<dynamic>?)?.cast<String>() ?? [],
      status: json['status'] as String? ?? 'pending',
      resolution: json['resolution'] as String?,
      resolvedByUserId: json['resolvedByUserId'] as String?,
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.parse(json['resolvedAt'] as String)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reporterUserId': reporterUserId,
      'targetId': targetId,
      'targetType': targetType,
      'reason': reason,
      if (details != null) 'details': details,
      'evidenceImages': evidenceImages,
      'status': status,
      if (resolution != null) 'resolution': resolution,
      if (resolvedByUserId != null) 'resolvedByUserId': resolvedByUserId,
      if (resolvedAt != null) 'resolvedAt': resolvedAt!.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  ReportModel copyWith({
    String? id,
    String? reporterUserId,
    String? targetId,
    String? targetType,
    String? reason,
    String? details,
    List<String>? evidenceImages,
    String? status,
    String? resolution,
    String? resolvedByUserId,
    DateTime? resolvedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ReportModel(
      id: id ?? this.id,
      reporterUserId: reporterUserId ?? this.reporterUserId,
      targetId: targetId ?? this.targetId,
      targetType: targetType ?? this.targetType,
      reason: reason ?? this.reason,
      details: details ?? this.details,
      evidenceImages: evidenceImages ?? this.evidenceImages,
      status: status ?? this.status,
      resolution: resolution ?? this.resolution,
      resolvedByUserId: resolvedByUserId ?? this.resolvedByUserId,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReportModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Common report reasons
class ReportReasons {
  static const String prohibitedItem = 'prohibited_item';
  static const String counterfeitProduct = 'counterfeit_product';
  static const String misleadingInformation = 'misleading_information';
  static const String inappropriateContent = 'inappropriate_content';
  static const String scamOrFraud = 'scam_or_fraud';
  static const String spam = 'spam';
  static const String violenceOrHate = 'violence_or_hate';
  static const String other = 'other';

  static const Map<String, String> reasonLabels = {
    prohibitedItem: 'Item proibido',
    counterfeitProduct: 'Produto falsificado',
    misleadingInformation: 'Informação enganosa',
    inappropriateContent: 'Conteúdo inapropriado',
    scamOrFraud: 'Golpe ou fraude',
    spam: 'Spam',
    violenceOrHate: 'Violência ou discurso de ódio',
    other: 'Outro',
  };

  static String getLabel(String reason) {
    return reasonLabels[reason] ?? reason;
  }

  static List<String> get allReasons => reasonLabels.keys.toList();
}
