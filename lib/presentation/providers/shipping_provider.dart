import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/delivery_zone_model.dart';
import '../../data/models/freight_option_model.dart';
import '../../data/models/pickup_point_model.dart';
import '../../domain/repositories/shipping_repository.dart';
import 'core_providers.dart';

/// Parameters for freight calculation
class FreightParams {
  final String zipCode;
  final String city;
  final double subtotal;
  final List<FreightItemRequest> items;
  final String tenantId;

  const FreightParams({
    required this.zipCode,
    required this.city,
    required this.subtotal,
    required this.items,
    required this.tenantId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FreightParams &&
          zipCode == other.zipCode &&
          city == other.city &&
          subtotal == other.subtotal &&
          tenantId == other.tenantId;

  @override
  int get hashCode => Object.hash(zipCode, city, subtotal, tenantId);
}

/// Calculate freight options for a given address and items
final freightOptionsProvider = FutureProvider.autoDispose
    .family<FreightCalculationResult, FreightParams>((ref, params) async {
  final repo = ref.watch(shippingRepositoryProvider);
  return repo.calculateFreight(
    zipCode: params.zipCode,
    city: params.city,
    subtotal: params.subtotal,
    items: params.items,
    tenantId: params.tenantId,
  );
});

/// Selected freight option in checkout
final selectedFreightOptionProvider =
    StateProvider.autoDispose<FreightOptionModel?>((ref) => null);

/// All delivery zones (cached)
final deliveryZonesProvider = FutureProvider<List<DeliveryZoneModel>>((ref) async {
  final repo = ref.watch(shippingRepositoryProvider);
  return repo.getZones();
});

/// Pickup points filtered by zone
final pickupPointsProvider =
    FutureProvider.family<List<PickupPointModel>, String?>((ref, zoneId) async {
  final repo = ref.watch(shippingRepositoryProvider);
  return repo.getPickupPoints(zoneId: zoneId);
});
