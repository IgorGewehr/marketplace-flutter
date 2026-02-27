/// Service model matching backend Service interface
library;

import '../../core/utils/firestore_utils.dart';

class ServiceModel {
  final String id;
  final String tenantId;
  final String name;
  final String description;
  final String? shortDescription;
  final String categoryId;
  final String? subcategoryId;
  final List<String> tags;
  final List<ServiceImage> images;
  final List<ServiceImage> portfolioImages;
  final String pricingType; // hourly, project, monthly, fixed, on_demand
  final double basePrice;
  final double? minPrice;
  final double? maxPrice;
  final bool isAvailable;
  final List<String> availableDays;
  final ServiceHours? serviceHours;
  final List<ServiceArea> serviceAreas;
  final bool isRemote;
  final bool isOnSite;
  final ServiceDuration? duration;
  final List<String> requirements;
  final List<String> includes;
  final List<String> excludes;
  final List<String> certifications;
  final String? experience;
  final String status; // active, draft, inactive
  final bool acceptsQuote;
  final bool instantBooking;
  final ServiceMarketplaceStats? marketplaceStats;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ServiceModel({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.description,
    this.shortDescription,
    required this.categoryId,
    this.subcategoryId,
    this.tags = const [],
    this.images = const [],
    this.portfolioImages = const [],
    required this.pricingType,
    required this.basePrice,
    this.minPrice,
    this.maxPrice,
    this.isAvailable = true,
    this.availableDays = const [],
    this.serviceHours,
    this.serviceAreas = const [],
    this.isRemote = false,
    this.isOnSite = true,
    this.duration,
    this.requirements = const [],
    this.includes = const [],
    this.excludes = const [],
    this.certifications = const [],
    this.experience,
    this.status = 'active',
    this.acceptsQuote = true,
    this.instantBooking = false,
    this.marketplaceStats,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Get the main image URL
  String? get mainImageUrl => images.isNotEmpty ? images.first.url : null;

  /// Check if service is active
  bool get isActive => status == 'active';

  /// Get average rating
  double get rating => marketplaceStats?.rating ?? 0.0;

  /// Get review count
  int get reviewCount => marketplaceStats?.reviewCount ?? 0;

  /// Get completed jobs count
  int get completedJobs => marketplaceStats?.completedJobs ?? 0;

  /// Get pricing display text
  String get pricingDisplay {
    switch (pricingType) {
      case 'hourly':
        return 'R\$ ${basePrice.toStringAsFixed(2)}/hora';
      case 'project':
        if (minPrice != null && maxPrice != null) {
          return 'R\$ ${minPrice!.toStringAsFixed(2)} - R\$ ${maxPrice!.toStringAsFixed(2)}';
        }
        return 'A partir de R\$ ${basePrice.toStringAsFixed(2)}';
      case 'monthly':
        return 'R\$ ${basePrice.toStringAsFixed(2)}/mês';
      case 'fixed':
        return 'R\$ ${basePrice.toStringAsFixed(2)}';
      case 'on_demand':
        return 'Sob consulta';
      default:
        return 'R\$ ${basePrice.toStringAsFixed(2)}';
    }
  }

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: json['id'] as String? ?? '',
      tenantId: json['tenantId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      shortDescription: json['shortDescription'] as String?,
      categoryId: json['categoryId'] as String? ?? '',
      subcategoryId: json['subcategoryId'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      images: (json['images'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>().map((i) => ServiceImage.fromJson(i))
              .toList() ??
          [],
      portfolioImages: (json['portfolioImages'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>().map((i) => ServiceImage.fromJson(i))
              .toList() ??
          [],
      pricingType: json['pricingType'] as String? ?? 'fixed',
      basePrice: (json['basePrice'] as num?)?.toDouble() ?? 0.0,
      minPrice: (json['minPrice'] as num?)?.toDouble(),
      maxPrice: (json['maxPrice'] as num?)?.toDouble(),
      isAvailable: json['isAvailable'] as bool? ?? true,
      availableDays: (json['availableDays'] as List<dynamic>?)?.cast<String>() ?? [],
      serviceHours: json['serviceHours'] != null
          ? ServiceHours.fromJson(json['serviceHours'] as Map<String, dynamic>)
          : null,
      serviceAreas: (json['serviceAreas'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>().map((a) => ServiceArea.fromJson(a))
              .toList() ??
          [],
      isRemote: json['isRemote'] as bool? ?? false,
      isOnSite: json['isOnSite'] as bool? ?? true,
      duration: json['duration'] != null
          ? ServiceDuration.fromJson(json['duration'] as Map<String, dynamic>)
          : null,
      requirements: (json['requirements'] as List<dynamic>?)?.cast<String>() ?? [],
      includes: (json['includes'] as List<dynamic>?)?.cast<String>() ?? [],
      excludes: (json['excludes'] as List<dynamic>?)?.cast<String>() ?? [],
      certifications: (json['certifications'] as List<dynamic>?)?.cast<String>() ?? [],
      experience: json['experience'] as String?,
      status: json['status'] as String? ?? 'active',
      acceptsQuote: json['acceptsQuote'] as bool? ?? true,
      instantBooking: json['instantBooking'] as bool? ?? false,
      marketplaceStats: json['marketplaceStats'] != null
          ? ServiceMarketplaceStats.fromJson(json['marketplaceStats'] as Map<String, dynamic>)
          : null,
      createdAt: parseFirestoreDate(json['createdAt']) ?? DateTime.now(),
      updatedAt: parseFirestoreDate(json['updatedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenantId': tenantId,
      'name': name,
      'description': description,
      if (shortDescription != null) 'shortDescription': shortDescription,
      'categoryId': categoryId,
      if (subcategoryId != null) 'subcategoryId': subcategoryId,
      'tags': tags,
      'images': images.map((i) => i.toJson()).toList(),
      'portfolioImages': portfolioImages.map((i) => i.toJson()).toList(),
      'pricingType': pricingType,
      'basePrice': basePrice,
      if (minPrice != null) 'minPrice': minPrice,
      if (maxPrice != null) 'maxPrice': maxPrice,
      'isAvailable': isAvailable,
      'availableDays': availableDays,
      if (serviceHours != null) 'serviceHours': serviceHours!.toJson(),
      'serviceAreas': serviceAreas.map((a) => a.toJson()).toList(),
      'isRemote': isRemote,
      'isOnSite': isOnSite,
      if (duration != null) 'duration': duration!.toJson(),
      'requirements': requirements,
      'includes': includes,
      'excludes': excludes,
      'certifications': certifications,
      if (experience != null) 'experience': experience,
      'status': status,
      'acceptsQuote': acceptsQuote,
      'instantBooking': instantBooking,
      if (marketplaceStats != null) 'marketplaceStats': marketplaceStats!.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  ServiceModel copyWith({
    String? id,
    String? tenantId,
    String? name,
    String? description,
    String? shortDescription,
    String? categoryId,
    String? subcategoryId,
    List<String>? tags,
    List<ServiceImage>? images,
    List<ServiceImage>? portfolioImages,
    String? pricingType,
    double? basePrice,
    double? minPrice,
    double? maxPrice,
    bool? isAvailable,
    List<String>? availableDays,
    ServiceHours? serviceHours,
    List<ServiceArea>? serviceAreas,
    bool? isRemote,
    bool? isOnSite,
    ServiceDuration? duration,
    List<String>? requirements,
    List<String>? includes,
    List<String>? excludes,
    List<String>? certifications,
    String? experience,
    String? status,
    bool? acceptsQuote,
    bool? instantBooking,
    ServiceMarketplaceStats? marketplaceStats,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ServiceModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      name: name ?? this.name,
      description: description ?? this.description,
      shortDescription: shortDescription ?? this.shortDescription,
      categoryId: categoryId ?? this.categoryId,
      subcategoryId: subcategoryId ?? this.subcategoryId,
      tags: tags ?? this.tags,
      images: images ?? this.images,
      portfolioImages: portfolioImages ?? this.portfolioImages,
      pricingType: pricingType ?? this.pricingType,
      basePrice: basePrice ?? this.basePrice,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      isAvailable: isAvailable ?? this.isAvailable,
      availableDays: availableDays ?? this.availableDays,
      serviceHours: serviceHours ?? this.serviceHours,
      serviceAreas: serviceAreas ?? this.serviceAreas,
      isRemote: isRemote ?? this.isRemote,
      isOnSite: isOnSite ?? this.isOnSite,
      duration: duration ?? this.duration,
      requirements: requirements ?? this.requirements,
      includes: includes ?? this.includes,
      excludes: excludes ?? this.excludes,
      certifications: certifications ?? this.certifications,
      experience: experience ?? this.experience,
      status: status ?? this.status,
      acceptsQuote: acceptsQuote ?? this.acceptsQuote,
      instantBooking: instantBooking ?? this.instantBooking,
      marketplaceStats: marketplaceStats ?? this.marketplaceStats,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServiceModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class ServiceImage {
  final String id;
  final String url;
  final String? alt;
  final int order;
  final String category; // profile, portfolio, certificate

  const ServiceImage({
    required this.id,
    required this.url,
    this.alt,
    this.order = 0,
    this.category = 'profile',
  });

  factory ServiceImage.fromJson(Map<String, dynamic> json) {
    return ServiceImage(
      id: json['id'] as String? ?? '',
      url: json['url'] as String? ?? '',
      alt: json['alt'] as String?,
      order: json['order'] as int? ?? 0,
      category: json['category'] as String? ?? 'profile',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      if (alt != null) 'alt': alt,
      'order': order,
      'category': category,
    };
  }
}

class ServiceArea {
  final String city;
  final String state;
  final String? zipCode;
  final double? radius;

  const ServiceArea({
    required this.city,
    required this.state,
    this.zipCode,
    this.radius,
  });

  factory ServiceArea.fromJson(Map<String, dynamic> json) {
    return ServiceArea(
      city: json['city'] as String? ?? '',
      state: json['state'] as String? ?? '',
      zipCode: json['zipCode'] as String?,
      radius: (json['radius'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'city': city,
      'state': state,
      if (zipCode != null) 'zipCode': zipCode,
      if (radius != null) 'radius': radius,
    };
  }

  String get displayName => '$city - $state';
}

class ServiceHours {
  final String? monday;
  final String? tuesday;
  final String? wednesday;
  final String? thursday;
  final String? friday;
  final String? saturday;
  final String? sunday;

  const ServiceHours({
    this.monday,
    this.tuesday,
    this.wednesday,
    this.thursday,
    this.friday,
    this.saturday,
    this.sunday,
  });

  factory ServiceHours.fromJson(Map<String, dynamic> json) {
    return ServiceHours(
      monday: json['monday'] as String?,
      tuesday: json['tuesday'] as String?,
      wednesday: json['wednesday'] as String?,
      thursday: json['thursday'] as String?,
      friday: json['friday'] as String?,
      saturday: json['saturday'] as String?,
      sunday: json['sunday'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (monday != null) 'monday': monday,
      if (tuesday != null) 'tuesday': tuesday,
      if (wednesday != null) 'wednesday': wednesday,
      if (thursday != null) 'thursday': thursday,
      if (friday != null) 'friday': friday,
      if (saturday != null) 'saturday': saturday,
      if (sunday != null) 'sunday': sunday,
    };
  }
}

class ServiceDuration {
  final int value;
  final String unit; // minutes, hours, days, weeks

  const ServiceDuration({
    required this.value,
    required this.unit,
  });

  factory ServiceDuration.fromJson(Map<String, dynamic> json) {
    return ServiceDuration(
      value: json['value'] as int? ?? 0,
      unit: json['unit'] as String? ?? 'hours',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'unit': unit,
    };
  }

  String get displayText {
    switch (unit) {
      case 'minutes':
        return '$value min';
      case 'hours':
        return '$value h';
      case 'days':
        return '$value ${value == 1 ? 'dia' : 'dias'}';
      case 'weeks':
        return '$value ${value == 1 ? 'semana' : 'semanas'}';
      default:
        return '$value $unit';
    }
  }
}

class ServiceMarketplaceStats {
  final int views;
  final int favorites;
  final int completedJobs;
  final double rating;
  final int reviewCount;
  final double? responseTime;
  final double? acceptanceRate;

  const ServiceMarketplaceStats({
    this.views = 0,
    this.favorites = 0,
    this.completedJobs = 0,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.responseTime,
    this.acceptanceRate,
  });

  factory ServiceMarketplaceStats.fromJson(Map<String, dynamic> json) {
    return ServiceMarketplaceStats(
      views: json['views'] as int? ?? 0,
      favorites: json['favorites'] as int? ?? 0,
      completedJobs: json['completedJobs'] as int? ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: json['reviewCount'] as int? ?? 0,
      responseTime: (json['responseTime'] as num?)?.toDouble(),
      acceptanceRate: (json['acceptanceRate'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'views': views,
      'favorites': favorites,
      'completedJobs': completedJobs,
      'rating': rating,
      'reviewCount': reviewCount,
      if (responseTime != null) 'responseTime': responseTime,
      if (acceptanceRate != null) 'acceptanceRate': acceptanceRate,
    };
  }
}

/// Marketplace service with provider info
class MarketplaceServiceModel {
  final String id;
  final String name;
  final String? shortDescription;
  final String pricingType;
  final double basePrice;
  final double? minPrice;
  final double? maxPrice;
  final List<ServiceImage> images;
  final ServiceProvider provider;
  final List<ServiceArea> serviceAreas;
  final bool isRemote;
  final double rating;
  final int reviewCount;
  final List<String> certifications;

  const MarketplaceServiceModel({
    required this.id,
    required this.name,
    this.shortDescription,
    required this.pricingType,
    required this.basePrice,
    this.minPrice,
    this.maxPrice,
    this.images = const [],
    required this.provider,
    this.serviceAreas = const [],
    this.isRemote = false,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.certifications = const [],
  });

  String? get mainImageUrl => images.isNotEmpty ? images.first.url : null;

  String get pricingDisplay {
    switch (pricingType) {
      case 'hourly':
        return 'R\$ ${basePrice.toStringAsFixed(2)}/hora';
      case 'project':
        if (minPrice != null && maxPrice != null) {
          return 'R\$ ${minPrice!.toStringAsFixed(2)} - R\$ ${maxPrice!.toStringAsFixed(2)}';
        }
        return 'A partir de R\$ ${basePrice.toStringAsFixed(2)}';
      case 'monthly':
        return 'R\$ ${basePrice.toStringAsFixed(2)}/mês';
      case 'fixed':
        return 'R\$ ${basePrice.toStringAsFixed(2)}';
      case 'on_demand':
        return 'Sob consulta';
      default:
        return 'R\$ ${basePrice.toStringAsFixed(2)}';
    }
  }

  factory MarketplaceServiceModel.fromJson(Map<String, dynamic> json) {
    return MarketplaceServiceModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      shortDescription: json['shortDescription'] as String?,
      pricingType: json['pricingType'] as String? ?? 'fixed',
      basePrice: (json['basePrice'] as num?)?.toDouble() ?? 0.0,
      minPrice: (json['minPrice'] as num?)?.toDouble(),
      maxPrice: (json['maxPrice'] as num?)?.toDouble(),
      images: (json['images'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>().map((i) => ServiceImage.fromJson(i))
              .toList() ??
          [],
      provider: json['provider'] is Map<String, dynamic>
          ? ServiceProvider.fromJson(json['provider'] as Map<String, dynamic>)
          : ServiceProvider.fromJson({}),
      serviceAreas: (json['serviceAreas'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>().map((a) => ServiceArea.fromJson(a))
              .toList() ??
          [],
      isRemote: json['isRemote'] as bool? ?? false,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: json['reviewCount'] as int? ?? 0,
      certifications: (json['certifications'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }
}

class ServiceProvider {
  final String id;
  final String name;
  final double rating;
  final int completedJobs;
  final double? responseTime;

  const ServiceProvider({
    required this.id,
    required this.name,
    this.rating = 0.0,
    this.completedJobs = 0,
    this.responseTime,
  });

  factory ServiceProvider.fromJson(Map<String, dynamic> json) {
    return ServiceProvider(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      completedJobs: json['completedJobs'] as int? ?? 0,
      responseTime: (json['responseTime'] as num?)?.toDouble(),
    );
  }
}
