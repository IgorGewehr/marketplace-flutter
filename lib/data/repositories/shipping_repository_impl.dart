/// Shipping repository implementation
library;

import '../datasources/api_client.dart';
import '../models/delivery_zone_model.dart';
import '../models/freight_option_model.dart';
import '../models/pickup_point_model.dart';
import '../../domain/repositories/shipping_repository.dart';

class ShippingRepositoryImpl implements ShippingRepository {
  final ApiClient _apiClient;

  ShippingRepositoryImpl({required ApiClient apiClient}) : _apiClient = apiClient;

  @override
  Future<FreightCalculationResult> calculateFreight({
    required String zipCode,
    required String city,
    required double subtotal,
    required List<FreightItemRequest> items,
    required String tenantId,
  }) async {
    final result = await _apiClient.post<Map<String, dynamic>>(
      '/api/shipping/calculate',
      data: {
        'zipCode': zipCode,
        'city': city,
        'subtotal': subtotal,
        'items': items.map((i) => i.toJson()).toList(),
        'tenantId': tenantId,
      },
    );
    return FreightCalculationResult.fromJson(result);
  }

  @override
  Future<List<DeliveryZoneModel>> getZones() async {
    final result = await _apiClient.get<Map<String, dynamic>>(
      '/api/shipping/zones',
    );
    final list = result['zones'] as List<dynamic>? ?? [];
    return list
        .map((e) => DeliveryZoneModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<PickupPointModel>> getPickupPoints({String? zoneId}) async {
    final result = await _apiClient.get<Map<String, dynamic>>(
      '/api/shipping/pickup-points',
      queryParameters: {
        if (zoneId != null) 'zoneId': zoneId,
      },
    );
    final list = result['pickupPoints'] as List<dynamic>? ?? [];
    return list
        .map((e) => PickupPointModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
