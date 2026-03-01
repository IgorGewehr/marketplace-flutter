/// Pickup point model
library;

import 'address_model.dart';

class PickupPointModel {
  final String id;
  final String name;
  final String type; // store, locker, partner
  final AddressModel address;
  final String zoneId;
  final Map<String, String> businessHours; // { "mon": "08:00-18:00", ... }
  final int maxHoldDays;
  final bool isActive;

  const PickupPointModel({
    required this.id,
    required this.name,
    this.type = 'store',
    required this.address,
    required this.zoneId,
    this.businessHours = const {},
    this.maxHoldDays = 7,
    this.isActive = true,
  });

  factory PickupPointModel.fromJson(Map<String, dynamic> json) {
    return PickupPointModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? 'store',
      address: json['address'] is Map<String, dynamic>
          ? AddressModel.fromJson(json['address'] as Map<String, dynamic>)
          : const AddressModel(
              street: '', number: '', neighborhood: '', city: '', state: '', zipCode: ''),
      zoneId: json['zoneId'] as String? ?? '',
      businessHours: (json['businessHours'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v.toString())) ??
          {},
      maxHoldDays: json['maxHoldDays'] as int? ?? 7,
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'address': address.toJson(),
      'zoneId': zoneId,
      'businessHours': businessHours,
      'maxHoldDays': maxHoldDays,
      'isActive': isActive,
    };
  }
}
