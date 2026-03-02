/// Product model matching SCHEMA.md
library;

import 'address_model.dart';
import '../../core/utils/firestore_utils.dart';

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
  final int quantity;
  final bool trackInventory;
  final bool hasVariants;
  final List<ProductVariant> variants;
  final String visibility; // marketplace, store, both
  final String status; // active, draft, archived
  final String? ncm;
  final String? cfop;
  final ProductLocation? location; // Geolocation for filtering
  final ProductMarketplaceStats? marketplaceStats;
  // Shipping fields
  final double? weight; // kg
  final ProductDimensions? dimensions; // cm
  final bool isPerishable;
  final String? shippingCategory; // standard, fragile, heavy, perishable
  final String shippingPolicy; // delivery, pickup_only, seller_arranges
  // Rental fields
  final String productType; // product, rental
  final RentalInfo? rentalInfo;
  // Listing type (product vs job)
  final String listingType; // 'product' (default), 'job'
  // Job fields (only used when listingType == 'job')
  final String? companyName;
  final String? salary;
  final bool salaryNegotiable;
  final String? jobType; // clt, pj, freelance, estagio, temporario
  final String? workMode; // presencial, remoto, hibrido
  final List<String> requirements;
  final List<String> benefits;
  final String? contactEmail;
  final String? contactPhone;
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
    this.quantity = 0,
    this.trackInventory = true,
    this.hasVariants = false,
    this.variants = const [],
    this.visibility = 'both',
    this.status = 'active',
    this.ncm,
    this.cfop,
    this.location,
    this.marketplaceStats,
    this.weight,
    this.dimensions,
    this.isPerishable = false,
    this.shippingCategory,
    this.shippingPolicy = 'delivery',
    this.productType = 'product',
    this.rentalInfo,
    this.listingType = 'product',
    this.companyName,
    this.salary,
    this.salaryNegotiable = false,
    this.jobType,
    this.workMode,
    this.requirements = const [],
    this.benefits = const [],
    this.contactEmail,
    this.contactPhone,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Check if this product is a rental listing
  bool get isRental => productType == 'rental';

  /// Check if this is a job listing
  bool get isJob => listingType == 'job';

  /// Salary display string
  String get salaryDisplay {
    if (salary == null || salary!.isEmpty || salaryNegotiable) return 'A combinar';
    return salary!;
  }

  /// Human-readable job type label
  String get jobTypeLabel {
    switch (jobType) {
      case 'clt': return 'CLT';
      case 'pj': return 'PJ';
      case 'freelance': return 'Freelance';
      case 'estagio': return 'Estágio';
      case 'temporario': return 'Temporário';
      default: return jobType ?? '';
    }
  }

  /// Human-readable work mode label
  String get workModeLabel {
    switch (workMode) {
      case 'presencial': return 'Presencial';
      case 'remoto': return 'Remoto';
      case 'hibrido': return 'Híbrido';
      default: return workMode ?? '';
    }
  }

  /// Formatted rental price with period suffix (e.g. "R$ 1.500/mês")
  String? get rentalPriceDisplay {
    if (!isRental || rentalInfo == null) return null;
    return 'R\$ ${price.toStringAsFixed(price.truncateToDouble() == price ? 0 : 2)}/${rentalInfo!.periodSuffix}';
  }

  /// Check if product is oversized (any dimension > 40x30x30 cm)
  bool get isOversized =>
      dimensions != null &&
      (dimensions!.width > 40 || dimensions!.height > 30 || dimensions!.length > 30);

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
              ?.whereType<Map<String, dynamic>>()
              .map((i) => ProductImage.fromJson(i))
              .toList() ??
          [],
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      compareAtPrice: (json['compareAtPrice'] as num?)?.toDouble(),
      costPrice: (json['costPrice'] as num?)?.toDouble(),
      sku: json['sku'] as String?,
      barcode: json['barcode'] as String?,
      quantity: (json['quantity'] as int?) ?? 0,
      trackInventory: json['trackInventory'] as bool? ?? true,
      hasVariants: json['hasVariants'] as bool? ?? false,
      variants: (json['variants'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map((v) => ProductVariant.fromJson(v))
              .toList() ??
          [],
      visibility: json['visibility'] as String? ?? 'both',
      status: json['status'] as String? ?? 'active',
      ncm: json['ncm'] as String?,
      cfop: json['cfop'] as String?,
      location: json['location'] is Map<String, dynamic>
          ? ProductLocation.fromJson(json['location'] as Map<String, dynamic>)
          : null,
      marketplaceStats: json['marketplaceStats'] is Map<String, dynamic>
          ? ProductMarketplaceStats.fromJson(json['marketplaceStats'] as Map<String, dynamic>)
          : null,
      weight: (json['weight'] as num?)?.toDouble(),
      dimensions: json['dimensions'] is Map<String, dynamic>
          ? ProductDimensions.fromJson(json['dimensions'] as Map<String, dynamic>)
          : null,
      isPerishable: json['isPerishable'] as bool? ?? false,
      shippingCategory: json['shippingCategory'] as String?,
      shippingPolicy: json['shippingPolicy'] as String? ?? 'delivery',
      productType: json['productType'] as String? ?? 'product',
      rentalInfo: json['rentalInfo'] is Map<String, dynamic>
          ? RentalInfo.fromJson(json['rentalInfo'] as Map<String, dynamic>)
          : null,
      listingType: json['listingType'] as String? ?? 'product',
      companyName: json['companyName'] as String?,
      salary: json['salary'] as String?,
      salaryNegotiable: json['salaryNegotiable'] as bool? ?? false,
      jobType: json['jobType'] as String?,
      workMode: json['workMode'] as String?,
      requirements: (json['requirements'] as List<dynamic>?)?.cast<String>() ?? [],
      benefits: (json['benefits'] as List<dynamic>?)?.cast<String>() ?? [],
      contactEmail: json['contactEmail'] as String?,
      contactPhone: json['contactPhone'] as String?,
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
      'price': price,
      if (compareAtPrice != null) 'compareAtPrice': compareAtPrice,
      if (costPrice != null) 'costPrice': costPrice,
      if (sku != null) 'sku': sku,
      if (barcode != null) 'barcode': barcode,
      'quantity': quantity,
      'trackInventory': trackInventory,
      'hasVariants': hasVariants,
      'variants': variants.map((v) => v.toJson()).toList(),
      'visibility': visibility,
      'status': status,
      if (ncm != null) 'ncm': ncm,
      if (cfop != null) 'cfop': cfop,
      if (location != null) 'location': location!.toJson(),
      if (marketplaceStats != null) 'marketplaceStats': marketplaceStats!.toJson(),
      if (weight != null) 'weight': weight,
      if (dimensions != null) 'dimensions': dimensions!.toJson(),
      'isPerishable': isPerishable,
      if (shippingCategory != null) 'shippingCategory': shippingCategory,
      'shippingPolicy': shippingPolicy,
      'productType': productType,
      if (rentalInfo != null) 'rentalInfo': rentalInfo!.toJson(),
      'listingType': listingType,
      if (companyName != null) 'companyName': companyName,
      if (salary != null) 'salary': salary,
      if (salaryNegotiable) 'salaryNegotiable': salaryNegotiable,
      if (jobType != null) 'jobType': jobType,
      if (workMode != null) 'workMode': workMode,
      if (requirements.isNotEmpty) 'requirements': requirements,
      if (benefits.isNotEmpty) 'benefits': benefits,
      if (contactEmail != null) 'contactEmail': contactEmail,
      if (contactPhone != null) 'contactPhone': contactPhone,
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
    double? weight,
    ProductDimensions? dimensions,
    bool? isPerishable,
    String? shippingCategory,
    String? shippingPolicy,
    String? productType,
    RentalInfo? rentalInfo,
    String? listingType,
    String? companyName,
    String? salary,
    bool? salaryNegotiable,
    String? jobType,
    String? workMode,
    List<String>? requirements,
    List<String>? benefits,
    String? contactEmail,
    String? contactPhone,
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
      weight: weight ?? this.weight,
      dimensions: dimensions ?? this.dimensions,
      isPerishable: isPerishable ?? this.isPerishable,
      shippingCategory: shippingCategory ?? this.shippingCategory,
      shippingPolicy: shippingPolicy ?? this.shippingPolicy,
      productType: productType ?? this.productType,
      rentalInfo: rentalInfo ?? this.rentalInfo,
      listingType: listingType ?? this.listingType,
      companyName: companyName ?? this.companyName,
      salary: salary ?? this.salary,
      salaryNegotiable: salaryNegotiable ?? this.salaryNegotiable,
      jobType: jobType ?? this.jobType,
      workMode: workMode ?? this.workMode,
      requirements: requirements ?? this.requirements,
      benefits: benefits ?? this.benefits,
      contactEmail: contactEmail ?? this.contactEmail,
      contactPhone: contactPhone ?? this.contactPhone,
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

/// Product dimensions in centimeters
class ProductDimensions {
  final double width;
  final double height;
  final double length;

  const ProductDimensions({
    required this.width,
    required this.height,
    required this.length,
  });

  factory ProductDimensions.fromJson(Map<String, dynamic> json) {
    return ProductDimensions(
      width: (json['width'] as num?)?.toDouble() ?? 0,
      height: (json['height'] as num?)?.toDouble() ?? 0,
      length: (json['length'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'width': width,
      'height': height,
      'length': length,
    };
  }

  ProductDimensions copyWith({
    double? width,
    double? height,
    double? length,
  }) {
    return ProductDimensions(
      width: width ?? this.width,
      height: height ?? this.height,
      length: length ?? this.length,
    );
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

/// Rental-specific information for products with productType == 'rental'
class RentalInfo {
  final String rentalType; // imovel, equipamento, veiculo, outro
  final String rentalPeriod; // diario, semanal, mensal, anual
  final double? deposit; // caução
  final bool isAvailable;
  final String? availabilityNotes;
  // Imóvel fields
  final int? bedrooms;
  final int? bathrooms;
  final double? area; // m²
  final String? propertyType; // apartamento, casa, sala_comercial, terreno, kitnet
  final bool? furnished;
  final bool? petsAllowed;
  // Veículo fields
  final int? year;
  final String? brand;
  final String? model;

  const RentalInfo({
    required this.rentalType,
    required this.rentalPeriod,
    this.deposit,
    this.isAvailable = true,
    this.availabilityNotes,
    this.bedrooms,
    this.bathrooms,
    this.area,
    this.propertyType,
    this.furnished,
    this.petsAllowed,
    this.year,
    this.brand,
    this.model,
  });

  /// Short period suffix for price display (e.g. "mês", "dia")
  String get periodSuffix {
    switch (rentalPeriod) {
      case 'diario':
        return 'dia';
      case 'semanal':
        return 'sem';
      case 'mensal':
        return 'mês';
      case 'anual':
        return 'ano';
      default:
        return 'mês';
    }
  }

  /// Full period display (e.g. "Mensal", "Diário")
  String get periodDisplayFull {
    switch (rentalPeriod) {
      case 'diario':
        return 'Diário';
      case 'semanal':
        return 'Semanal';
      case 'mensal':
        return 'Mensal';
      case 'anual':
        return 'Anual';
      default:
        return 'Mensal';
    }
  }

  /// Display label for rental type
  String get rentalTypeDisplay {
    switch (rentalType) {
      case 'imovel':
        return 'Imóvel';
      case 'equipamento':
        return 'Equipamento';
      case 'veiculo':
        return 'Veículo';
      case 'outro':
        return 'Outro';
      default:
        return rentalType;
    }
  }

  /// Display label for property type
  String get propertyTypeDisplay {
    switch (propertyType) {
      case 'apartamento':
        return 'Apartamento';
      case 'casa':
        return 'Casa';
      case 'sala_comercial':
        return 'Sala Comercial';
      case 'terreno':
        return 'Terreno';
      case 'kitnet':
        return 'Kitnet';
      default:
        return propertyType ?? '';
    }
  }

  factory RentalInfo.fromJson(Map<String, dynamic> json) {
    return RentalInfo(
      rentalType: json['rentalType'] as String? ?? 'outro',
      rentalPeriod: json['rentalPeriod'] as String? ?? 'mensal',
      deposit: (json['deposit'] as num?)?.toDouble(),
      isAvailable: json['isAvailable'] as bool? ?? true,
      availabilityNotes: json['availabilityNotes'] as String?,
      bedrooms: json['bedrooms'] as int?,
      bathrooms: json['bathrooms'] as int?,
      area: (json['area'] as num?)?.toDouble(),
      propertyType: json['propertyType'] as String?,
      furnished: json['furnished'] as bool?,
      petsAllowed: json['petsAllowed'] as bool?,
      year: json['year'] as int?,
      brand: json['brand'] as String?,
      model: json['model'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rentalType': rentalType,
      'rentalPeriod': rentalPeriod,
      if (deposit != null) 'deposit': deposit,
      'isAvailable': isAvailable,
      if (availabilityNotes != null) 'availabilityNotes': availabilityNotes,
      if (bedrooms != null) 'bedrooms': bedrooms,
      if (bathrooms != null) 'bathrooms': bathrooms,
      if (area != null) 'area': area,
      if (propertyType != null) 'propertyType': propertyType,
      if (furnished != null) 'furnished': furnished,
      if (petsAllowed != null) 'petsAllowed': petsAllowed,
      if (year != null) 'year': year,
      if (brand != null) 'brand': brand,
      if (model != null) 'model': model,
    };
  }

  RentalInfo copyWith({
    String? rentalType,
    String? rentalPeriod,
    double? deposit,
    bool? isAvailable,
    String? availabilityNotes,
    int? bedrooms,
    int? bathrooms,
    double? area,
    String? propertyType,
    bool? furnished,
    bool? petsAllowed,
    int? year,
    String? brand,
    String? model,
  }) {
    return RentalInfo(
      rentalType: rentalType ?? this.rentalType,
      rentalPeriod: rentalPeriod ?? this.rentalPeriod,
      deposit: deposit ?? this.deposit,
      isAvailable: isAvailable ?? this.isAvailable,
      availabilityNotes: availabilityNotes ?? this.availabilityNotes,
      bedrooms: bedrooms ?? this.bedrooms,
      bathrooms: bathrooms ?? this.bathrooms,
      area: area ?? this.area,
      propertyType: propertyType ?? this.propertyType,
      furnished: furnished ?? this.furnished,
      petsAllowed: petsAllowed ?? this.petsAllowed,
      year: year ?? this.year,
      brand: brand ?? this.brand,
      model: model ?? this.model,
    );
  }
}
