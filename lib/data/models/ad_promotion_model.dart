/// Ad promotion model for boosting products/listings
library;

class AdPromotionModel {
  final String id;
  final String tenantId;
  final String targetId; // productId or tenantId
  final String targetType; // product, seller_profile
  final String promotionType; // city_top, category_top, homepage_featured
  final AdPromotionLocation location;
  final double pricePerDay;
  final double totalPrice;
  final DateTime startDate;
  final DateTime endDate;
  final String paymentStatus; // pending, paid, failed, refunded
  final String? paymentGatewayId;
  final String status; // pending, active, paused, completed, cancelled
  final AdPromotionStats? stats;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AdPromotionModel({
    required this.id,
    required this.tenantId,
    required this.targetId,
    required this.targetType,
    required this.promotionType,
    required this.location,
    required this.pricePerDay,
    required this.totalPrice,
    required this.startDate,
    required this.endDate,
    this.paymentStatus = 'pending',
    this.paymentGatewayId,
    this.status = 'pending',
    this.stats,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Get duration in days
  int get durationInDays => endDate.difference(startDate).inDays + 1;

  /// Check if promotion is active
  bool get isActive => status == 'active';

  /// Check if promotion is currently running
  bool get isCurrentlyRunning {
    if (!isActive) return false;
    final now = DateTime.now();
    return now.isAfter(startDate) && now.isBefore(endDate);
  }

  /// Check if promotion has ended
  bool get hasEnded => DateTime.now().isAfter(endDate);

  /// Check if promotion is paid
  bool get isPaid => paymentStatus == 'paid';

  factory AdPromotionModel.fromJson(Map<String, dynamic> json) {
    return AdPromotionModel(
      id: json['id'] as String? ?? '',
      tenantId: json['tenantId'] as String? ?? '',
      targetId: json['targetId'] as String? ?? '',
      targetType: json['targetType'] as String? ?? 'product',
      promotionType: json['promotionType'] as String? ?? 'city_top',
      location: AdPromotionLocation.fromJson(json['location'] as Map<String, dynamic>? ?? {}),
      pricePerDay: (json['pricePerDay'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (json['totalPrice'] as num?)?.toDouble() ?? 0.0,
      startDate: json['startDate'] != null
          ? DateTime.parse(json['startDate'] as String)
          : DateTime.now(),
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'] as String)
          : DateTime.now().add(const Duration(days: 7)),
      paymentStatus: json['paymentStatus'] as String? ?? 'pending',
      paymentGatewayId: json['paymentGatewayId'] as String?,
      status: json['status'] as String? ?? 'pending',
      stats: json['stats'] != null
          ? AdPromotionStats.fromJson(json['stats'] as Map<String, dynamic>)
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
      'tenantId': tenantId,
      'targetId': targetId,
      'targetType': targetType,
      'promotionType': promotionType,
      'location': location.toJson(),
      'pricePerDay': pricePerDay,
      'totalPrice': totalPrice,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'paymentStatus': paymentStatus,
      if (paymentGatewayId != null) 'paymentGatewayId': paymentGatewayId,
      'status': status,
      if (stats != null) 'stats': stats!.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  AdPromotionModel copyWith({
    String? id,
    String? tenantId,
    String? targetId,
    String? targetType,
    String? promotionType,
    AdPromotionLocation? location,
    double? pricePerDay,
    double? totalPrice,
    DateTime? startDate,
    DateTime? endDate,
    String? paymentStatus,
    String? paymentGatewayId,
    String? status,
    AdPromotionStats? stats,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AdPromotionModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      targetId: targetId ?? this.targetId,
      targetType: targetType ?? this.targetType,
      promotionType: promotionType ?? this.promotionType,
      location: location ?? this.location,
      pricePerDay: pricePerDay ?? this.pricePerDay,
      totalPrice: totalPrice ?? this.totalPrice,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentGatewayId: paymentGatewayId ?? this.paymentGatewayId,
      status: status ?? this.status,
      stats: stats ?? this.stats,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdPromotionModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Location targeting for ad promotion
class AdPromotionLocation {
  final String? city;
  final String? state;
  final List<String> neighborhoods;
  final String? categoryId;
  final int? radiusKm;

  const AdPromotionLocation({
    this.city,
    this.state,
    this.neighborhoods = const [],
    this.categoryId,
    this.radiusKm,
  });

  /// Check if targeting specific city
  bool get hasCity => city != null;

  /// Check if targeting specific category
  bool get hasCategory => categoryId != null;

  /// Check if targeting specific neighborhoods
  bool get hasNeighborhoods => neighborhoods.isNotEmpty;

  factory AdPromotionLocation.fromJson(Map<String, dynamic> json) {
    return AdPromotionLocation(
      city: json['city'] as String?,
      state: json['state'] as String?,
      neighborhoods: (json['neighborhoods'] as List<dynamic>?)?.cast<String>() ?? [],
      categoryId: json['categoryId'] as String?,
      radiusKm: json['radiusKm'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (city != null) 'city': city,
      if (state != null) 'state': state,
      'neighborhoods': neighborhoods,
      if (categoryId != null) 'categoryId': categoryId,
      if (radiusKm != null) 'radiusKm': radiusKm,
    };
  }
}

/// Statistics for ad promotion
class AdPromotionStats {
  final int impressions;
  final int clicks;
  final int conversions;
  final double clickThroughRate;
  final double conversionRate;

  const AdPromotionStats({
    this.impressions = 0,
    this.clicks = 0,
    this.conversions = 0,
    this.clickThroughRate = 0.0,
    this.conversionRate = 0.0,
  });

  factory AdPromotionStats.fromJson(Map<String, dynamic> json) {
    return AdPromotionStats(
      impressions: json['impressions'] as int? ?? 0,
      clicks: json['clicks'] as int? ?? 0,
      conversions: json['conversions'] as int? ?? 0,
      clickThroughRate: (json['clickThroughRate'] as num?)?.toDouble() ?? 0.0,
      conversionRate: (json['conversionRate'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'impressions': impressions,
      'clicks': clicks,
      'conversions': conversions,
      'clickThroughRate': clickThroughRate,
      'conversionRate': conversionRate,
    };
  }
}

/// Promotion type constants
class PromotionTypes {
  static const String cityTop = 'city_top'; // Top of city listings
  static const String categoryTop = 'category_top'; // Top of category
  static const String homepageFeatured = 'homepage_featured'; // Featured on homepage

  static const Map<String, String> typeLabels = {
    cityTop: 'Destaque na Cidade',
    categoryTop: 'Destaque na Categoria',
    homepageFeatured: 'Destaque na Home',
  };

  static String getLabel(String type) {
    return typeLabels[type] ?? type;
  }

  static List<String> get allTypes => typeLabels.keys.toList();
}
