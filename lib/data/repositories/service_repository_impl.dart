import '../../core/constants/api_constants.dart';
import '../../domain/repositories/service_repository.dart';
import '../datasources/api_client.dart';
import '../datasources/storage_service.dart';
import '../models/service_model.dart';
import '../models/category_model.dart';

/// Service Repository Implementation
class ServiceRepositoryImpl implements ServiceRepository {
  final ApiClient _apiClient;
  final StorageService _storageService;

  ServiceRepositoryImpl({
    required ApiClient apiClient,
    required StorageService storageService,
  })  : _apiClient = apiClient,
        _storageService = storageService;

  @override
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
    String? sortBy,
  }) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConstants.marketplaceServices,
      queryParameters: {
        'page': page,
        'limit': limit,
        if (categoryId != null) 'categoryId': categoryId,
        if (subcategoryId != null) 'subcategoryId': subcategoryId,
        if (minPrice != null) 'minPrice': minPrice,
        if (maxPrice != null) 'maxPrice': maxPrice,
        if (pricingType != null) 'pricingType': pricingType,
        if (city != null) 'city': city,
        if (state != null) 'state': state,
        if (isRemote != null) 'isRemote': isRemote,
        if (sortBy != null) 'sortBy': sortBy,
      },
    );

    return ServiceListResponse.fromJson(response);
  }

  @override
  Future<List<MarketplaceServiceModel>> getFeatured({int limit = 10}) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConstants.marketplaceServicesFeatured,
      queryParameters: {'limit': limit},
    );

    final services = (response['services'] as List<dynamic>?)
            ?.map((s) => MarketplaceServiceModel.fromJson(s as Map<String, dynamic>))
            .toList() ??
        [];

    return services;
  }

  @override
  Future<List<MarketplaceServiceModel>> getRecent({int limit = 20}) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConstants.marketplaceServicesRecent,
      queryParameters: {'limit': limit},
    );

    final services = (response['services'] as List<dynamic>?)
            ?.map((s) => MarketplaceServiceModel.fromJson(s as Map<String, dynamic>))
            .toList() ??
        [];

    return services;
  }

  @override
  Future<ServiceModel> getById(String id) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConstants.marketplaceServiceById(id),
    );

    return ServiceModel.fromJson(response);
  }

  @override
  Future<ServiceListResponse> search({
    required String query,
    int page = 1,
    int limit = 20,
    String? categoryId,
  }) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConstants.marketplaceServicesSearch,
      queryParameters: {
        'q': query,
        'page': page,
        'limit': limit,
        if (categoryId != null) 'categoryId': categoryId,
      },
    );

    return ServiceListResponse.fromJson(response);
  }

  @override
  Future<ServiceListResponse> getByCategory(
    String categoryId, {
    int page = 1,
    int limit = 20,
  }) async {
    return getServices(
      categoryId: categoryId,
      page: page,
      limit: limit,
    );
  }

  @override
  Future<List<CategoryModel>> getCategories() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConstants.marketplaceServiceCategories,
    );

    final categories = (response['categories'] as List<dynamic>?)
            ?.map((c) => CategoryModel.fromJson(c as Map<String, dynamic>))
            .toList() ??
        [];

    return categories;
  }

  @override
  Future<SellerServiceListResponse> getSellerServices({
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConstants.sellerServices,
      queryParameters: {
        'page': page,
        'limit': limit,
        if (status != null) 'status': status,
      },
    );

    return SellerServiceListResponse.fromJson(response);
  }

  @override
  Future<ServiceModel> create(CreateServiceRequest request) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiConstants.sellerServices,
      data: request.toJson(),
    );

    return ServiceModel.fromJson(response);
  }

  @override
  Future<ServiceModel> update(String id, UpdateServiceRequest request) async {
    final response = await _apiClient.patch<Map<String, dynamic>>(
      ApiConstants.sellerServiceById(id),
      data: request.toJson(),
    );

    return ServiceModel.fromJson(response);
  }

  @override
  Future<void> delete(String id) async {
    await _apiClient.delete(ApiConstants.sellerServiceById(id));
  }

  @override
  Future<List<ServiceImage>> uploadImages(
    String serviceId,
    List<String> imagePaths, {
    String category = 'profile',
  }) async {
    final uploadedImages = <ServiceImage>[];

    for (final imagePath in imagePaths) {
      final imageUrl = await _storageService.uploadServiceImage(
        serviceId,
        imagePath,
        category: category,
      );

      final imageId = 'img_${DateTime.now().millisecondsSinceEpoch}';
      uploadedImages.add(ServiceImage(
        id: imageId,
        url: imageUrl,
        order: uploadedImages.length,
        category: category,
      ));
    }

    return uploadedImages;
  }

  @override
  Future<void> deleteImage(
    String serviceId,
    String imageId, {
    String category = 'profile',
  }) async {
    await _apiClient.delete(
      ApiConstants.sellerServiceImageById(serviceId, imageId),
      queryParameters: {'category': category},
    );
  }
}
