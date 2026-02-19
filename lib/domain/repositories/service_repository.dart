import '../../data/models/service_model.dart';
import '../../data/models/category_model.dart';

/// Service Repository Interface
abstract class ServiceRepository {
  /// Get paginated list of marketplace services
  Future<ServiceListResponse> getServices({
    int page = 1,
    int limit = 20,
    String? categoryId,
    String? subcategoryId,
    double? minPrice,
    double? maxPrice,
    String? pricingType,
    String? city,
    String? state,
    bool? isRemote,
    String? sortBy, // recent, price_asc, price_desc, rating, popular
  });

  /// Get featured services
  Future<List<MarketplaceServiceModel>> getFeatured({int limit = 10});

  /// Get recent services
  Future<List<MarketplaceServiceModel>> getRecent({int limit = 20});

  /// Get service by ID
  Future<ServiceModel> getById(String id);

  /// Search services
  Future<ServiceListResponse> search({
    required String query,
    int page = 1,
    int limit = 20,
    String? categoryId,
  });

  /// Get services by category
  Future<ServiceListResponse> getByCategory(
    String categoryId, {
    int page = 1,
    int limit = 20,
  });

  /// Get all service categories
  Future<List<CategoryModel>> getCategories();

  /// Get seller services (requires seller auth)
  Future<SellerServiceListResponse> getSellerServices({
    int page = 1,
    int limit = 20,
    String? status,
  });

  /// Create service (seller only)
  Future<ServiceModel> create(CreateServiceRequest request);

  /// Update service (seller only)
  Future<ServiceModel> update(String id, UpdateServiceRequest request);

  /// Delete service (seller only)
  Future<void> delete(String id);

  /// Upload service images
  Future<List<ServiceImage>> uploadImages(
    String serviceId,
    List<String> imagePaths, {
    String category = 'profile',
  });

  /// Delete service image
  Future<void> deleteImage(
    String serviceId,
    String imageId, {
    String category = 'profile',
  });
}

/// Response wrapper for paginated marketplace service lists
class ServiceListResponse {
  final List<MarketplaceServiceModel> services;
  final String? nextCursor;

  const ServiceListResponse({
    required this.services,
    this.nextCursor,
  });

  bool get hasMore => nextCursor != null;

  factory ServiceListResponse.fromJson(Map<String, dynamic> json) {
    return ServiceListResponse(
      services: (json['services'] as List<dynamic>?)
              ?.map((s) => MarketplaceServiceModel.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      nextCursor: json['nextCursor'] as String?,
    );
  }
}

/// Response wrapper for seller's own service lists
class SellerServiceListResponse {
  final List<ServiceModel> services;
  final String? nextCursor;

  const SellerServiceListResponse({
    required this.services,
    this.nextCursor,
  });

  bool get hasMore => nextCursor != null;

  factory SellerServiceListResponse.fromJson(Map<String, dynamic> json) {
    return SellerServiceListResponse(
      services: (json['services'] as List<dynamic>?)
              ?.map((s) => ServiceModel.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      nextCursor: json['nextCursor'] as String?,
    );
  }
}

/// Request model for creating a service
class CreateServiceRequest {
  final String name;
  final String description;
  final String? shortDescription;
  final String categoryId;
  final String? subcategoryId;
  final List<String> tags;
  final String pricingType;
  final double basePrice;
  final double? minPrice;
  final double? maxPrice;
  final List<ServiceArea> serviceAreas;
  final bool isRemote;
  final bool isOnSite;
  final ServiceDuration? duration;
  final List<String> requirements;
  final List<String> includes;
  final List<String> excludes;
  final List<String> certifications;
  final String? experience;
  final bool acceptsQuote;
  final bool instantBooking;

  const CreateServiceRequest({
    required this.name,
    required this.description,
    this.shortDescription,
    required this.categoryId,
    this.subcategoryId,
    this.tags = const [],
    required this.pricingType,
    required this.basePrice,
    this.minPrice,
    this.maxPrice,
    this.serviceAreas = const [],
    this.isRemote = false,
    this.isOnSite = true,
    this.duration,
    this.requirements = const [],
    this.includes = const [],
    this.excludes = const [],
    this.certifications = const [],
    this.experience,
    this.acceptsQuote = true,
    this.instantBooking = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      if (shortDescription != null) 'shortDescription': shortDescription,
      'categoryId': categoryId,
      if (subcategoryId != null) 'subcategoryId': subcategoryId,
      'tags': tags,
      'pricingType': pricingType,
      'basePrice': basePrice,
      if (minPrice != null) 'minPrice': minPrice,
      if (maxPrice != null) 'maxPrice': maxPrice,
      'serviceAreas': serviceAreas.map((a) => a.toJson()).toList(),
      'isRemote': isRemote,
      'isOnSite': isOnSite,
      if (duration != null) 'duration': duration!.toJson(),
      'requirements': requirements,
      'includes': includes,
      'excludes': excludes,
      'certifications': certifications,
      if (experience != null) 'experience': experience,
      'acceptsQuote': acceptsQuote,
      'instantBooking': instantBooking,
    };
  }
}

/// Request model for updating a service
class UpdateServiceRequest {
  final String? name;
  final String? description;
  final String? shortDescription;
  final String? categoryId;
  final String? subcategoryId;
  final List<String>? tags;
  final String? pricingType;
  final double? basePrice;
  final double? minPrice;
  final double? maxPrice;
  final List<ServiceArea>? serviceAreas;
  final bool? isRemote;
  final bool? isOnSite;
  final bool? isAvailable;
  final ServiceDuration? duration;
  final List<String>? requirements;
  final List<String>? includes;
  final List<String>? excludes;
  final List<String>? certifications;
  final String? experience;
  final String? status;
  final bool? acceptsQuote;
  final bool? instantBooking;

  const UpdateServiceRequest({
    this.name,
    this.description,
    this.shortDescription,
    this.categoryId,
    this.subcategoryId,
    this.tags,
    this.pricingType,
    this.basePrice,
    this.minPrice,
    this.maxPrice,
    this.serviceAreas,
    this.isRemote,
    this.isOnSite,
    this.isAvailable,
    this.duration,
    this.requirements,
    this.includes,
    this.excludes,
    this.certifications,
    this.experience,
    this.status,
    this.acceptsQuote,
    this.instantBooking,
  });

  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (shortDescription != null) 'shortDescription': shortDescription,
      if (categoryId != null) 'categoryId': categoryId,
      if (subcategoryId != null) 'subcategoryId': subcategoryId,
      if (tags != null) 'tags': tags,
      if (pricingType != null) 'pricingType': pricingType,
      if (basePrice != null) 'basePrice': basePrice,
      if (minPrice != null) 'minPrice': minPrice,
      if (maxPrice != null) 'maxPrice': maxPrice,
      if (serviceAreas != null) 'serviceAreas': serviceAreas!.map((a) => a.toJson()).toList(),
      if (isRemote != null) 'isRemote': isRemote,
      if (isOnSite != null) 'isOnSite': isOnSite,
      if (isAvailable != null) 'isAvailable': isAvailable,
      if (duration != null) 'duration': duration!.toJson(),
      if (requirements != null) 'requirements': requirements,
      if (includes != null) 'includes': includes,
      if (excludes != null) 'excludes': excludes,
      if (certifications != null) 'certifications': certifications,
      if (experience != null) 'experience': experience,
      if (status != null) 'status': status,
      if (acceptsQuote != null) 'acceptsQuote': acceptsQuote,
      if (instantBooking != null) 'instantBooking': instantBooking,
    };
  }
}
