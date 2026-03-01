/// Delivery zone model
library;

class DeliveryZoneModel {
  final String id;
  final String name;
  final String? description;
  final double basePrice;
  final double? freeDeliveryMinimum;
  final bool sameDayAvailable;
  final bool nextDayAvailable;
  final bool scheduledAvailable;
  final String estimatedDelivery;
  final int sortOrder;

  const DeliveryZoneModel({
    required this.id,
    required this.name,
    this.description,
    required this.basePrice,
    this.freeDeliveryMinimum,
    this.sameDayAvailable = false,
    this.nextDayAvailable = false,
    this.scheduledAvailable = true,
    this.estimatedDelivery = '',
    this.sortOrder = 0,
  });

  factory DeliveryZoneModel.fromJson(Map<String, dynamic> json) {
    return DeliveryZoneModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      basePrice: (json['basePrice'] as num?)?.toDouble() ?? 0.0,
      freeDeliveryMinimum: (json['freeDeliveryMinimum'] as num?)?.toDouble(),
      sameDayAvailable: json['sameDayAvailable'] as bool? ?? false,
      nextDayAvailable: json['nextDayAvailable'] as bool? ?? false,
      scheduledAvailable: json['scheduledAvailable'] as bool? ?? true,
      estimatedDelivery: json['estimatedDelivery'] as String? ?? '',
      sortOrder: json['sortOrder'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (description != null) 'description': description,
      'basePrice': basePrice,
      if (freeDeliveryMinimum != null) 'freeDeliveryMinimum': freeDeliveryMinimum,
      'sameDayAvailable': sameDayAvailable,
      'nextDayAvailable': nextDayAvailable,
      'scheduledAvailable': scheduledAvailable,
      'estimatedDelivery': estimatedDelivery,
      'sortOrder': sortOrder,
    };
  }
}
