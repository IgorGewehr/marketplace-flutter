/// Product model matching SCHEMA.md
library;

import 'address_model.dart';

class ProductModel {
  final String id;
  final String tenantId;
  final String name;
  final String description;
  final String? shortDescription;
  final String categoryId;
  final String? subcategoryId;
  final List<String> tags;
  final List<ProductImage> images;
  final double price;
  final double? compareAtPrice;
  final double? costPrice;
  final String? sku;
  final String? barcode;
  final int? quantity;
  final bool trackInventory;
  final bool hasVariants;
  final List<ProductVariant> variants;
  final String visibility; // marketplace, store, both
  final String status; // active, draft, archived
  final String? ncm;
  final String? cfop;
  final ProductLocation? location; // Geolocation for filtering
  final ProductMarketplaceStats? marketplaceStats;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProductModel({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.description,
    this.shortDescription,
    required this.categoryId,
    this.subcategoryId,
    this.tags = const [],
    this.images = const [],
    required this.price,
    this.compareAtPrice,
    this.costPrice,
    this.sku,
    this.barcode,
    this.quantity,
    this.trackInventory = true,
    this.hasVariants = false,
    this.variants = const [],
    this.visibility = 'both',
    this.status = 'active',
    this.ncm,
    this.cfop,
    this.location,
    this.marketplaceStats,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Get the main image URL
  String? get mainImageUrl => images.isNotEmpty ? images.first.url : null;

  /// Check if product has a discount
  bool get hasDiscount => compareAtPrice != null && compareAtPrice! > price;

  /// Get discount percentage
  int get discountPercentage {
    if (!hasDiscount) return 0;
    return (((compareAtPrice! - price) / compareAtPrice!) * 100).round();
  }

  /// Check if product is active
  bool get isActive => status == 'active';

  /// Check if visible on marketplace
  bool get isVisibleOnMarketplace => visibility == 'marketplace' || visibility == 'both';

  /// Get average rating
  double get rating => marketplaceStats?.rating ?? 0.0;

  /// Get review count
  int get reviewCount => marketplaceStats?.reviewCount ?? 0;

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] as String? ?? '',
      tenantId: json['tenantId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      shortDescription: json['shortDescription'] as String?,
      categoryId: json['categoryId'] as String? ?? '',
      subcategoryId: json['subcategoryId'] as String?,
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
      images: (json['images'] as List<dynamic>?)
              ?.map((i) => ProductImage.fromJson(i as Map<String, dynamic>))
              .toList() ??
          [],
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      compareAtPrice: (json['compareAtPrice'] as num?)?.toDouble(),
      costPrice: (json['costPrice'] as num?)?.toDouble(),
      sku: json['sku'] as String?,
      barcode: json['barcode'] as String?,
      quantity: json['quantity'] as int?,
      trackInventory: json['trackInventory'] as bool? ?? true,
      hasVariants: json['hasVariants'] as bool? ?? false,
      variants: (json['variants'] as List<dynamic>?)
              ?.map((v) => ProductVariant.fromJson(v as Map<String, dynamic>))
              .toList() ??
          [],
      visibility: json['visibility'] as String? ?? 'both',
      status: json['status'] as String? ?? 'active',
      ncm: json['ncm'] as String?,
      cfop: json['cfop'] as String?,
      location: json['location'] != null
          ? ProductLocation.fromJson(json['location'] as Map<String, dynamic>)
          : null,
      marketplaceStats: json['marketplaceStats'] != null
          ? ProductMarketplaceStats.fromJson(json['marketplaceStats'] as Map<String, dynamic>)
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
      'name': name,
      'description': description,
      if (shortDescription != null) 'shortDescription': shortDescription,
      'categoryId': categoryId,
      if (subcategoryId != null) 'subcategoryId': subcategoryId,
      'tags': tags,
      'images': images.map((i) => i.toJson()).toList(),
      'price': price,
      if (compareAtPrice != null) 'compareAtPrice': compareAtPrice,
      if (costPrice != null) 'costPrice': costPrice,
      if (sku != null) 'sku': sku,
      if (barcode != null) 'barcode': barcode,
      if (quantity != null) 'quantity': quantity,
      'trackInventory': trackInventory,
      'hasVariants': hasVariants,
      'variants': variants.map((v) => v.toJson()).toList(),
      'visibility': visibility,
      'status': status,
      if (ncm != null) 'ncm': ncm,
      if (cfop != null) 'cfop': cfop,
      if (location != null) 'location': location!.toJson(),
      if (marketplaceStats != null) 'marketplaceStats': marketplaceStats!.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  ProductModel copyWith({
    String? id,
    String? tenantId,
    String? name,
    String? description,
    String? shortDescription,
    String? categoryId,
    String? subcategoryId,
    List<String>? tags,
    List<ProductImage>? images,
    double? price,
    double? compareAtPrice,
    double? costPrice,
    String? sku,
    String? barcode,
    int? quantity,
    bool? trackInventory,
    bool? hasVariants,
    List<ProductVariant>? variants,
    String? visibility,
    String? status,
    String? ncm,
    String? cfop,
    ProductLocation? location,
    ProductMarketplaceStats? marketplaceStats,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductModel(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      name: name ?? this.name,
      description: description ?? this.description,
      shortDescription: shortDescription ?? this.shortDescription,
      categoryId: categoryId ?? this.categoryId,
      subcategoryId: subcategoryId ?? this.subcategoryId,
      tags: tags ?? this.tags,
      images: images ?? this.images,
      price: price ?? this.price,
      compareAtPrice: compareAtPrice ?? this.compareAtPrice,
      costPrice: costPrice ?? this.costPrice,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      quantity: quantity ?? this.quantity,
      trackInventory: trackInventory ?? this.trackInventory,
      hasVariants: hasVariants ?? this.hasVariants,
      variants: variants ?? this.variants,
      visibility: visibility ?? this.visibility,
      status: status ?? this.status,
      ncm: ncm ?? this.ncm,
      cfop: cfop ?? this.cfop,
      location: location ?? this.location,
      marketplaceStats: marketplaceStats ?? this.marketplaceStats,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class ProductImage {
  final String id;
  final String url;
  final String? alt;
  final int order;

  const ProductImage({
    required this.id,
    required this.url,
    this.alt,
    this.order = 0,
  });

  factory ProductImage.fromJson(Map<String, dynamic> json) {
    return ProductImage(
      id: json['id'] as String? ?? '',
      url: json['url'] as String? ?? '',
      alt: json['alt'] as String?,
      order: json['order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      if (alt != null) 'alt': alt,
      'order': order,
    };
  }
}

class ProductVariant {
  final String id;
  final String name;
  final String? sku;
  final String? barcode;
  final double? price;
  final double? compareAtPrice;
  final double? costPrice;
  final int? quantity;
  final Map<String, String> attributes;

  const ProductVariant({
    required this.id,
    required this.name,
    this.sku,
    this.barcode,
    this.price,
    this.compareAtPrice,
    this.costPrice,
    this.quantity,
    this.attributes = const {},
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      sku: json['sku'] as String?,
      barcode: json['barcode'] as String?,
      price: (json['price'] as num?)?.toDouble(),
      compareAtPrice: (json['compareAtPrice'] as num?)?.toDouble(),
      costPrice: (json['costPrice'] as num?)?.toDouble(),
      quantity: json['quantity'] as int?,
      attributes: (json['attributes'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v.toString())) ??
          {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (sku != null) 'sku': sku,
      if (barcode != null) 'barcode': barcode,
      if (price != null) 'price': price,
      if (compareAtPrice != null) 'compareAtPrice': compareAtPrice,
      if (costPrice != null) 'costPrice': costPrice,
      if (quantity != null) 'quantity': quantity,
      'attributes': attributes,
    };
  }
}

class ProductMarketplaceStats {
  final int views;
  final int favorites;
  final int sales;
  final double rating;
  final int reviewCount;

  const ProductMarketplaceStats({
    this.views = 0,
    this.favorites = 0,
    this.sales = 0,
    this.rating = 0.0,
    this.reviewCount = 0,
  });

  factory ProductMarketplaceStats.fromJson(Map<String, dynamic> json) {
    return ProductMarketplaceStats(
      views: json['views'] as int? ?? 0,
      favorites: json['favorites'] as int? ?? 0,
      sales: json['sales'] as int? ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: json['reviewCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'views': views,
      'favorites': favorites,
      'sales': sales,
      'rating': rating,
      'reviewCount': reviewCount,
    };
  }
}

/// Product location for geolocation filtering
class ProductLocation {
  final CoordinatesModel? coordinates;
  final String? city;
  final String? state;
  final String? neighborhood;
  final String? zipCode;

  const ProductLocation({
    this.coordinates,
    this.city,
    this.state,
    this.neighborhood,
    this.zipCode,
  });

  /// Check if product has coordinates
  bool get hasCoordinates => coordinates != null;

  /// Get formatted location string
  String get formattedLocation {
    final parts = <String>[];
    if (neighborhood != null) parts.add(neighborhood!);
    if (city != null) parts.add(city!);
    if (state != null) parts.add(state!);
    return parts.join(', ');
  }

  factory ProductLocation.fromJson(Map<String, dynamic> json) {
    return ProductLocation(
      coordinates: json['coordinates'] != null
          ? CoordinatesModel.fromJson(json['coordinates'] as Map<String, dynamic>)
          : null,
      city: json['city'] as String?,
      state: json['state'] as String?,
      neighborhood: json['neighborhood'] as String?,
      zipCode: json['zipCode'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (coordinates != null) 'coordinates': coordinates!.toJson(),
      if (city != null) 'city': city,
      if (state != null) 'state': state,
      if (neighborhood != null) 'neighborhood': neighborhood,
      if (zipCode != null) 'zipCode': zipCode,
    };
  }

  ProductLocation copyWith({
    CoordinatesModel? coordinates,
    String? city,
    String? state,
    String? neighborhood,
    String? zipCode,
  }) {
    return ProductLocation(
      coordinates: coordinates ?? this.coordinates,
      city: city ?? this.city,
      state: state ?? this.state,
      neighborhood: neighborhood ?? this.neighborhood,
      zipCode: zipCode ?? this.zipCode,
    );
  }
}
