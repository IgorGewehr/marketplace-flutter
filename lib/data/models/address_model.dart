/// Address model matching SCHEMA.md
library;

class AddressModel {
  final String? id;
  final String? label;
  final String street;
  final String number;
  final String? complement;
  final String neighborhood;
  final String city;
  final String state;
  final String zipCode;
  final String country;
  final bool isDefault;
  final CoordinatesModel? coordinates;

  const AddressModel({
    this.id,
    this.label,
    required this.street,
    required this.number,
    this.complement,
    required this.neighborhood,
    required this.city,
    required this.state,
    required this.zipCode,
    this.country = 'BR',
    this.isDefault = false,
    this.coordinates,
  });

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      id: json['id'] as String?,
      label: json['label'] as String?,
      street: json['street'] as String? ?? '',
      number: json['number'] as String? ?? '',
      complement: json['complement'] as String?,
      neighborhood: json['neighborhood'] as String? ?? '',
      city: json['city'] as String? ?? '',
      state: json['state'] as String? ?? '',
      zipCode: json['zipCode'] as String? ?? '',
      country: json['country'] as String? ?? 'BR',
      isDefault: json['isDefault'] as bool? ?? false,
      coordinates: json['coordinates'] != null
          ? CoordinatesModel.fromJson(json['coordinates'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (label != null) 'label': label,
      'street': street,
      'number': number,
      if (complement != null) 'complement': complement,
      'neighborhood': neighborhood,
      'city': city,
      'state': state,
      'zipCode': zipCode,
      'country': country,
      'isDefault': isDefault,
      if (coordinates != null) 'coordinates': coordinates!.toJson(),
    };
  }

  /// Get formatted full address
  String get fullAddress {
    final parts = <String>[
      street,
      number,
      if (complement != null && complement!.isNotEmpty) complement!,
      neighborhood,
      '$city - $state',
      zipCode,
    ];
    return parts.join(', ');
  }

  /// Get short address (street, number - neighborhood)
  String get shortAddress {
    return '$street, $number - $neighborhood';
  }

  AddressModel copyWith({
    String? id,
    String? label,
    String? street,
    String? number,
    String? complement,
    String? neighborhood,
    String? city,
    String? state,
    String? zipCode,
    String? country,
    bool? isDefault,
    CoordinatesModel? coordinates,
  }) {
    return AddressModel(
      id: id ?? this.id,
      label: label ?? this.label,
      street: street ?? this.street,
      number: number ?? this.number,
      complement: complement ?? this.complement,
      neighborhood: neighborhood ?? this.neighborhood,
      city: city ?? this.city,
      state: state ?? this.state,
      zipCode: zipCode ?? this.zipCode,
      country: country ?? this.country,
      isDefault: isDefault ?? this.isDefault,
      coordinates: coordinates ?? this.coordinates,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AddressModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          street == other.street &&
          number == other.number &&
          city == other.city;

  @override
  int get hashCode => Object.hash(id, street, number, city);
}

class CoordinatesModel {
  final double latitude;
  final double longitude;

  const CoordinatesModel({
    required this.latitude,
    required this.longitude,
  });

  factory CoordinatesModel.fromJson(Map<String, dynamic> json) {
    return CoordinatesModel(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CoordinatesModel &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}
