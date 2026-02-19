/// Tenant model matching SCHEMA.md
library;

import 'address_model.dart';

class TenantModel {
  final String id;
  final String type; // seller, erp_only, full
  final String name;
  final String? tradeName;
  final String? logoURL;
  final String? coverURL;
  final String? description;
  final TenantDocument? document;
  final String? email;
  final String? phone;
  final String? whatsapp;
  final AddressModel? address;
  final TenantSettings? settings;
  final TenantMarketplace? marketplace;
  final TenantFiscal? fiscal;
  final List<String> memberIds;
  final String ownerUserId;
  final bool isActive;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TenantModel({
    required this.id,
    required this.type,
    required this.name,
    this.tradeName,
    this.logoURL,
    this.coverURL,
    this.description,
    this.document,
    this.email,
    this.phone,
    this.whatsapp,
    this.address,
    this.settings,
    this.marketplace,
    this.fiscal,
    this.memberIds = const [],
    required this.ownerUserId,
    this.isActive = true,
    this.isVerified = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Check if tenant can sell on marketplace
  bool get canSellOnMarketplace => type == 'seller' || type == 'full';

  /// Check if tenant has ERP access
  bool get hasErpAccess => type == 'erp_only' || type == 'full';

  /// Get display name (tradeName or name)
  String get displayName => tradeName ?? name;

  /// Check if marketplace is active
  bool get isMarketplaceActive => marketplace?.isActive ?? false;

  /// Get marketplace rating
  double get rating => marketplace?.rating ?? 0.0;

  factory TenantModel.fromJson(Map<String, dynamic> json) {
    return TenantModel(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'seller',
      name: json['name'] as String? ?? '',
      tradeName: json['tradeName'] as String?,
      logoURL: json['logoURL'] as String?,
      coverURL: json['coverURL'] as String?,
      description: json['description'] as String?,
      document: json['document'] != null
          ? TenantDocument.fromJson(json['document'] as Map<String, dynamic>)
          : null,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      whatsapp: json['whatsapp'] as String?,
      address: json['address'] != null
          ? AddressModel.fromJson(json['address'] as Map<String, dynamic>)
          : null,
      settings: json['settings'] != null
          ? TenantSettings.fromJson(json['settings'] as Map<String, dynamic>)
          : null,
      marketplace: json['marketplace'] != null
          ? TenantMarketplace.fromJson(json['marketplace'] as Map<String, dynamic>)
          : null,
      fiscal: json['fiscal'] != null
          ? TenantFiscal.fromJson(json['fiscal'] as Map<String, dynamic>)
          : null,
      memberIds: (json['memberIds'] as List<dynamic>?)?.cast<String>() ?? [],
      ownerUserId: json['ownerUserId'] as String? ?? '',
      isActive: json['isActive'] as bool? ?? true,
      isVerified: json['isVerified'] as bool? ?? false,
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
      'type': type,
      'name': name,
      if (tradeName != null) 'tradeName': tradeName,
      if (logoURL != null) 'logoURL': logoURL,
      if (coverURL != null) 'coverURL': coverURL,
      if (description != null) 'description': description,
      if (document != null) 'document': document!.toJson(),
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (whatsapp != null) 'whatsapp': whatsapp,
      if (address != null) 'address': address!.toJson(),
      if (settings != null) 'settings': settings!.toJson(),
      if (marketplace != null) 'marketplace': marketplace!.toJson(),
      if (fiscal != null) 'fiscal': fiscal!.toJson(),
      'memberIds': memberIds,
      'ownerUserId': ownerUserId,
      'isActive': isActive,
      'isVerified': isVerified,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  TenantModel copyWith({
    String? id,
    String? type,
    String? name,
    String? tradeName,
    String? logoURL,
    String? coverURL,
    String? description,
    TenantDocument? document,
    String? email,
    String? phone,
    String? whatsapp,
    AddressModel? address,
    TenantSettings? settings,
    TenantMarketplace? marketplace,
    TenantFiscal? fiscal,
    List<String>? memberIds,
    String? ownerUserId,
    bool? isActive,
    bool? isVerified,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TenantModel(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      tradeName: tradeName ?? this.tradeName,
      logoURL: logoURL ?? this.logoURL,
      coverURL: coverURL ?? this.coverURL,
      description: description ?? this.description,
      document: document ?? this.document,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      whatsapp: whatsapp ?? this.whatsapp,
      address: address ?? this.address,
      settings: settings ?? this.settings,
      marketplace: marketplace ?? this.marketplace,
      fiscal: fiscal ?? this.fiscal,
      memberIds: memberIds ?? this.memberIds,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      isActive: isActive ?? this.isActive,
      isVerified: isVerified ?? this.isVerified,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TenantModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class TenantDocument {
  final String type; // cpf, cnpj
  final String number;
  final String? stateRegistration;
  final String? municipalRegistration;

  const TenantDocument({
    required this.type,
    required this.number,
    this.stateRegistration,
    this.municipalRegistration,
  });

  bool get isCnpj => type == 'cnpj';
  bool get isCpf => type == 'cpf';

  factory TenantDocument.fromJson(Map<String, dynamic> json) {
    return TenantDocument(
      type: json['type'] as String? ?? 'cpf',
      number: json['number'] as String? ?? '',
      stateRegistration: json['stateRegistration'] as String?,
      municipalRegistration: json['municipalRegistration'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'number': number,
      if (stateRegistration != null) 'stateRegistration': stateRegistration,
      if (municipalRegistration != null) 'municipalRegistration': municipalRegistration,
    };
  }
}

class TenantSettings {
  final String timezone;
  final String currency;
  final String language;
  final Map<String, BusinessHours?>? businessHours;

  const TenantSettings({
    this.timezone = 'America/Sao_Paulo',
    this.currency = 'BRL',
    this.language = 'pt-BR',
    this.businessHours,
  });

  factory TenantSettings.fromJson(Map<String, dynamic> json) {
    Map<String, BusinessHours?>? hours;
    if (json['businessHours'] != null) {
      hours = {};
      final hoursMap = json['businessHours'] as Map<String, dynamic>;
      for (final entry in hoursMap.entries) {
        hours[entry.key] = entry.value != null
            ? BusinessHours.fromJson(entry.value as Map<String, dynamic>)
            : null;
      }
    }

    return TenantSettings(
      timezone: json['timezone'] as String? ?? 'America/Sao_Paulo',
      currency: json['currency'] as String? ?? 'BRL',
      language: json['language'] as String? ?? 'pt-BR',
      businessHours: hours,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timezone': timezone,
      'currency': currency,
      'language': language,
      if (businessHours != null)
        'businessHours': businessHours!.map((k, v) => MapEntry(k, v?.toJson())),
    };
  }
}

class BusinessHours {
  final String open;
  final String close;
  final String? breakStart;
  final String? breakEnd;

  const BusinessHours({
    required this.open,
    required this.close,
    this.breakStart,
    this.breakEnd,
  });

  factory BusinessHours.fromJson(Map<String, dynamic> json) {
    return BusinessHours(
      open: json['open'] as String? ?? '',
      close: json['close'] as String? ?? '',
      breakStart: json['breakStart'] as String?,
      breakEnd: json['breakEnd'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'open': open,
      'close': close,
      if (breakStart != null) 'breakStart': breakStart,
      if (breakEnd != null) 'breakEnd': breakEnd,
    };
  }
}

class TenantMarketplace {
  final bool isActive;
  final String? slug;
  final List<String> categories;
  final List<DeliveryOption> deliveryOptions;
  final List<String> paymentMethods;
  final double rating;
  final int totalReviews;
  final int totalSales;

  const TenantMarketplace({
    this.isActive = false,
    this.slug,
    this.categories = const [],
    this.deliveryOptions = const [],
    this.paymentMethods = const [],
    this.rating = 0.0,
    this.totalReviews = 0,
    this.totalSales = 0,
  });

  factory TenantMarketplace.fromJson(Map<String, dynamic> json) {
    return TenantMarketplace(
      isActive: json['isActive'] as bool? ?? false,
      slug: json['slug'] as String?,
      categories: (json['categories'] as List<dynamic>?)?.cast<String>() ?? [],
      deliveryOptions: (json['deliveryOptions'] as List<dynamic>?)
              ?.map((d) => DeliveryOption.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
      paymentMethods: (json['paymentMethods'] as List<dynamic>?)?.cast<String>() ?? [],
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      totalReviews: json['totalReviews'] as int? ?? 0,
      totalSales: json['totalSales'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'isActive': isActive,
      if (slug != null) 'slug': slug,
      'categories': categories,
      'deliveryOptions': deliveryOptions.map((d) => d.toJson()).toList(),
      'paymentMethods': paymentMethods,
      'rating': rating,
      'totalReviews': totalReviews,
      'totalSales': totalSales,
    };
  }
}

class DeliveryOption {
  final String type; // pickup_in_person, seller_delivery, motoboy, third_party
  final String? label; // Custom label for the delivery option
  final double? deliveryFee;
  final double? freeDeliveryMinimum;
  final String? estimatedTime;
  final int? deliveryRadius;
  final Map<String, double>? neighborhoodFees; // Fees by neighborhood for seller_delivery
  final String? motoboyProvider; // Provider name for motoboy integration
  final Map<String, dynamic>? providerConfig; // Configuration for third-party providers

  const DeliveryOption({
    required this.type,
    this.label,
    this.deliveryFee,
    this.freeDeliveryMinimum,
    this.estimatedTime,
    this.deliveryRadius,
    this.neighborhoodFees,
    this.motoboyProvider,
    this.providerConfig,
  });

  // Type checkers
  bool get isPickupInPerson => type == 'pickup_in_person';
  bool get isSellerDelivery => type == 'seller_delivery';
  bool get isMotoboy => type == 'motoboy';
  bool get isThirdParty => type == 'third_party';

  /// Get delivery fee for a specific neighborhood
  double? getFeeForNeighborhood(String neighborhood) {
    if (neighborhoodFees == null) return deliveryFee;
    return neighborhoodFees![neighborhood] ?? deliveryFee;
  }

  /// Get display label
  String get displayLabel {
    if (label != null) return label!;
    switch (type) {
      case 'pickup_in_person':
        return 'Retirada em Mãos';
      case 'seller_delivery':
        return 'Entrega Própria';
      case 'motoboy':
        return 'Motoboy Local';
      case 'third_party':
        return 'Entrega via Correios/Transportadora';
      default:
        return type;
    }
  }

  factory DeliveryOption.fromJson(Map<String, dynamic> json) {
    return DeliveryOption(
      type: json['type'] as String? ?? 'pickup_in_person',
      label: json['label'] as String?,
      deliveryFee: (json['deliveryFee'] as num?)?.toDouble(),
      freeDeliveryMinimum: (json['freeDeliveryMinimum'] as num?)?.toDouble(),
      estimatedTime: json['estimatedTime'] as String?,
      deliveryRadius: json['deliveryRadius'] as int?,
      neighborhoodFees: (json['neighborhoodFees'] as Map<String, dynamic>?)
          ?.map((k, v) => MapEntry(k, (v as num).toDouble())),
      motoboyProvider: json['motoboyProvider'] as String?,
      providerConfig: json['providerConfig'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      if (label != null) 'label': label,
      if (deliveryFee != null) 'deliveryFee': deliveryFee,
      if (freeDeliveryMinimum != null) 'freeDeliveryMinimum': freeDeliveryMinimum,
      if (estimatedTime != null) 'estimatedTime': estimatedTime,
      if (deliveryRadius != null) 'deliveryRadius': deliveryRadius,
      if (neighborhoodFees != null) 'neighborhoodFees': neighborhoodFees,
      if (motoboyProvider != null) 'motoboyProvider': motoboyProvider,
      if (providerConfig != null) 'providerConfig': providerConfig,
    };
  }
}

/// Delivery option types
class DeliveryTypes {
  static const String pickupInPerson = 'pickup_in_person';
  static const String sellerDelivery = 'seller_delivery';
  static const String motoboy = 'motoboy';
  static const String thirdParty = 'third_party';

  static const Map<String, String> typeLabels = {
    pickupInPerson: 'Retirada em Mãos',
    sellerDelivery: 'Entrega Própria do Vendedor',
    motoboy: 'Motoboy Local',
    thirdParty: 'Correios/Transportadora',
  };

  static String getLabel(String type) {
    return typeLabels[type] ?? type;
  }
}

class TenantFiscal {
  final String? taxRegime;
  final FiscalCertificate? certificate;
  final NfeConfig? nfeConfig;
  final NfceConfig? nfceConfig;
  final NfseConfig? nfseConfig;

  const TenantFiscal({
    this.taxRegime,
    this.certificate,
    this.nfeConfig,
    this.nfceConfig,
    this.nfseConfig,
  });

  bool get hasCertificate => certificate != null;

  factory TenantFiscal.fromJson(Map<String, dynamic> json) {
    return TenantFiscal(
      taxRegime: json['taxRegime'] as String?,
      certificate: json['certificate'] != null
          ? FiscalCertificate.fromJson(json['certificate'] as Map<String, dynamic>)
          : null,
      nfeConfig: json['nfeConfig'] != null
          ? NfeConfig.fromJson(json['nfeConfig'] as Map<String, dynamic>)
          : null,
      nfceConfig: json['nfceConfig'] != null
          ? NfceConfig.fromJson(json['nfceConfig'] as Map<String, dynamic>)
          : null,
      nfseConfig: json['nfseConfig'] != null
          ? NfseConfig.fromJson(json['nfseConfig'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (taxRegime != null) 'taxRegime': taxRegime,
      if (certificate != null) 'certificate': certificate!.toJson(),
      if (nfeConfig != null) 'nfeConfig': nfeConfig!.toJson(),
      if (nfceConfig != null) 'nfceConfig': nfceConfig!.toJson(),
      if (nfseConfig != null) 'nfseConfig': nfseConfig!.toJson(),
    };
  }
}

class FiscalCertificate {
  final String? serialNumber;
  final DateTime? expiresAt;
  final String? storagePath;

  const FiscalCertificate({
    this.serialNumber,
    this.expiresAt,
    this.storagePath,
  });

  bool get isExpired => expiresAt != null && expiresAt!.isBefore(DateTime.now());
  bool get isExpiringSoon =>
      expiresAt != null &&
      expiresAt!.difference(DateTime.now()).inDays <= 30;

  factory FiscalCertificate.fromJson(Map<String, dynamic> json) {
    return FiscalCertificate(
      serialNumber: json['serialNumber'] as String?,
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      storagePath: json['storagePath'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (serialNumber != null) 'serialNumber': serialNumber,
      if (expiresAt != null) 'expiresAt': expiresAt!.toIso8601String(),
      if (storagePath != null) 'storagePath': storagePath,
    };
  }
}

class NfeConfig {
  final int series;
  final int nextNumber;
  final String environment; // production, homologation

  const NfeConfig({
    this.series = 1,
    this.nextNumber = 1,
    this.environment = 'homologation',
  });

  factory NfeConfig.fromJson(Map<String, dynamic> json) {
    return NfeConfig(
      series: json['series'] as int? ?? 1,
      nextNumber: json['nextNumber'] as int? ?? 1,
      environment: json['environment'] as String? ?? 'homologation',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'series': series,
      'nextNumber': nextNumber,
      'environment': environment,
    };
  }
}

class NfceConfig extends NfeConfig {
  final String? cscId;
  final String? cscToken;

  const NfceConfig({
    super.series,
    super.nextNumber,
    super.environment,
    this.cscId,
    this.cscToken,
  });

  factory NfceConfig.fromJson(Map<String, dynamic> json) {
    return NfceConfig(
      series: json['series'] as int? ?? 1,
      nextNumber: json['nextNumber'] as int? ?? 1,
      environment: json['environment'] as String? ?? 'homologation',
      cscId: json['cscId'] as String?,
      cscToken: json['cscToken'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      ...super.toJson(),
      if (cscId != null) 'cscId': cscId,
      if (cscToken != null) 'cscToken': cscToken,
    };
  }
}

class NfseConfig {
  final String? municipalCode;
  final String? username;
  final String? password;
  final String environment;

  const NfseConfig({
    this.municipalCode,
    this.username,
    this.password,
    this.environment = 'homologation',
  });

  factory NfseConfig.fromJson(Map<String, dynamic> json) {
    return NfseConfig(
      municipalCode: json['municipalCode'] as String?,
      username: json['username'] as String?,
      password: json['password'] as String?,
      environment: json['environment'] as String? ?? 'homologation',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (municipalCode != null) 'municipalCode': municipalCode,
      if (username != null) 'username': username,
      if (password != null) 'password': password,
      'environment': environment,
    };
  }
}
