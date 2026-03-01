/// Freight option model for delivery calculation
library;

class FreightOptionModel {
  final String zoneId;
  final String zoneName;
  final String tier; // same_day, next_day, scheduled, pickup_point
  final String tierLabel;
  final double price;
  final String estimatedDelivery; // e.g. "Hoje", "Amanhã", "2-3 dias úteis"
  final DateTime? estimatedDeliveryDate;
  final bool requiresVan;
  final bool available;
  final String? unavailableReason;
  final DeliveryFeeBreakdown? breakdown;
  final String? pickupPointId;
  final String? pickupPointName;
  final String? pickupPointAddress;
  final bool isFreeDelivery;
  final double? freeDeliveryThreshold;
  final double? amountToFreeDelivery;
  final String? sellerZoneId;
  final String? sellerZoneName;
  final int? zoneDistance;

  const FreightOptionModel({
    required this.zoneId,
    required this.zoneName,
    required this.tier,
    required this.tierLabel,
    required this.price,
    required this.estimatedDelivery,
    this.estimatedDeliveryDate,
    this.requiresVan = false,
    this.available = true,
    this.unavailableReason,
    this.breakdown,
    this.pickupPointId,
    this.pickupPointName,
    this.pickupPointAddress,
    this.isFreeDelivery = false,
    this.freeDeliveryThreshold,
    this.amountToFreeDelivery,
    this.sellerZoneId,
    this.sellerZoneName,
    this.zoneDistance,
  });

  factory FreightOptionModel.fromJson(Map<String, dynamic> json) {
    return FreightOptionModel(
      zoneId: json['zoneId'] as String? ?? '',
      zoneName: json['zoneName'] as String? ?? '',
      tier: json['tier'] as String? ?? '',
      tierLabel: json['tierLabel'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      estimatedDelivery: json['estimatedDelivery'] as String? ?? '',
      estimatedDeliveryDate: json['estimatedDeliveryDate'] != null
          ? DateTime.tryParse(json['estimatedDeliveryDate'] as String)
          : null,
      requiresVan: json['requiresVan'] as bool? ?? false,
      available: json['available'] as bool? ?? true,
      unavailableReason: json['unavailableReason'] as String?,
      breakdown: json['breakdown'] is Map<String, dynamic>
          ? DeliveryFeeBreakdown.fromJson(json['breakdown'] as Map<String, dynamic>)
          : null,
      pickupPointId: json['pickupPointId'] as String?,
      pickupPointName: json['pickupPointName'] as String?,
      pickupPointAddress: json['pickupPointAddress'] as String?,
      isFreeDelivery: json['isFreeDelivery'] as bool? ?? false,
      freeDeliveryThreshold: (json['freeDeliveryThreshold'] as num?)?.toDouble(),
      amountToFreeDelivery: (json['amountToFreeDelivery'] as num?)?.toDouble(),
      sellerZoneId: json['sellerZoneId'] as String?,
      sellerZoneName: json['sellerZoneName'] as String?,
      zoneDistance: json['zoneDistance'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'zoneId': zoneId,
      'zoneName': zoneName,
      'tier': tier,
      'tierLabel': tierLabel,
      'price': price,
      'estimatedDelivery': estimatedDelivery,
      if (estimatedDeliveryDate != null)
        'estimatedDeliveryDate': estimatedDeliveryDate!.toIso8601String(),
      'requiresVan': requiresVan,
      'available': available,
      if (unavailableReason != null) 'unavailableReason': unavailableReason,
      if (breakdown != null) 'breakdown': breakdown!.toJson(),
      if (pickupPointId != null) 'pickupPointId': pickupPointId,
      if (pickupPointName != null) 'pickupPointName': pickupPointName,
      if (pickupPointAddress != null) 'pickupPointAddress': pickupPointAddress,
      'isFreeDelivery': isFreeDelivery,
      if (freeDeliveryThreshold != null) 'freeDeliveryThreshold': freeDeliveryThreshold,
      if (amountToFreeDelivery != null) 'amountToFreeDelivery': amountToFreeDelivery,
      if (sellerZoneId != null) 'sellerZoneId': sellerZoneId,
      if (sellerZoneName != null) 'sellerZoneName': sellerZoneName,
      if (zoneDistance != null) 'zoneDistance': zoneDistance,
    };
  }
}

class DeliveryFeeBreakdown {
  final double basePrice;
  final double weightSurcharge;
  final double volumeSurcharge;
  final double tierPremium;
  final double freeDeliveryDiscount;
  final double pickupDiscount;

  const DeliveryFeeBreakdown({
    this.basePrice = 0,
    this.weightSurcharge = 0,
    this.volumeSurcharge = 0,
    this.tierPremium = 0,
    this.freeDeliveryDiscount = 0,
    this.pickupDiscount = 0,
  });

  factory DeliveryFeeBreakdown.fromJson(Map<String, dynamic> json) {
    return DeliveryFeeBreakdown(
      basePrice: (json['basePrice'] as num?)?.toDouble() ?? 0,
      weightSurcharge: (json['weightSurcharge'] as num?)?.toDouble() ?? 0,
      volumeSurcharge: (json['volumeSurcharge'] as num?)?.toDouble() ?? 0,
      tierPremium: (json['tierPremium'] as num?)?.toDouble() ?? 0,
      freeDeliveryDiscount: (json['freeDeliveryDiscount'] as num?)?.toDouble() ?? 0,
      pickupDiscount: (json['pickupDiscount'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'basePrice': basePrice,
      'weightSurcharge': weightSurcharge,
      'volumeSurcharge': volumeSurcharge,
      'tierPremium': tierPremium,
      'freeDeliveryDiscount': freeDeliveryDiscount,
      'pickupDiscount': pickupDiscount,
    };
  }
}
