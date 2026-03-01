/// Shipping repository interface
library;

import '../../data/models/delivery_zone_model.dart';
import '../../data/models/freight_option_model.dart';
import '../../data/models/pickup_point_model.dart';

abstract class ShippingRepository {
  /// Calculate freight options for the given address and items
  Future<FreightCalculationResult> calculateFreight({
    required String zipCode,
    required String city,
    required double subtotal,
    required List<FreightItemRequest> items,
    required String tenantId,
  });

  /// Get all active delivery zones
  Future<List<DeliveryZoneModel>> getZones();

  /// Get pickup points, optionally filtered by zone
  Future<List<PickupPointModel>> getPickupPoints({String? zoneId});
}

class FreightItemRequest {
  final double? weight;
  final Map<String, double>? dimensions;
  final int quantity;
  final String? shippingPolicy;

  const FreightItemRequest({
    this.weight,
    this.dimensions,
    required this.quantity,
    this.shippingPolicy,
  });

  Map<String, dynamic> toJson() {
    return {
      if (weight != null) 'weight': weight,
      if (dimensions != null) 'dimensions': dimensions,
      'quantity': quantity,
      if (shippingPolicy != null) 'shippingPolicy': shippingPolicy,
    };
  }
}

class FreightCalculationResult {
  final List<FreightOptionModel> options;
  final String? freeDeliveryMessage;
  final bool hasMixedCart;
  final int pickupOnlyCount;

  const FreightCalculationResult({
    required this.options,
    this.freeDeliveryMessage,
    this.hasMixedCart = false,
    this.pickupOnlyCount = 0,
  });

  factory FreightCalculationResult.fromJson(Map<String, dynamic> json) {
    return FreightCalculationResult(
      options: (json['options'] as List<dynamic>?)
              ?.map((e) => FreightOptionModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      freeDeliveryMessage: json['freeDeliveryMessage'] as String?,
      hasMixedCart: json['hasMixedCart'] as bool? ?? false,
      pickupOnlyCount: json['pickupOnlyCount'] as int? ?? 0,
    );
  }
}
