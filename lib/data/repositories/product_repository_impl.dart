import 'package:dio/dio.dart';

import '../../core/constants/api_constants.dart';
import '../../domain/repositories/product_repository.dart';
import '../datasources/api_client.dart';
import '../models/product_model.dart';
import '../models/category_model.dart';

/// Product Repository Implementation
class ProductRepositoryImpl implements ProductRepository {
  final ApiClient _apiClient;

  ProductRepositoryImpl({required ApiClient apiClient}) : _apiClient = apiClient;

  @override
  Future<ProductListResponse> getProducts({
    int page = 1,
    int limit = 20,
    String? categoryId,
    String? tenantId,
    String? search,
    double? minPrice,
    double? maxPrice,
    String? sortBy,
    String? sortOrder,
  }) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConstants.marketplaceProducts,
      queryParameters: {
        'page': page,
        'limit': limit,
        if (categoryId != null) 'categoryId': categoryId,
        if (tenantId != null) 'tenantId': tenantId,
        if (search != null) 'search': search,
        if (minPrice != null) 'minPrice': minPrice,
        if (maxPrice != null) 'maxPrice': maxPrice,
        if (sortBy != null) 'sortBy': sortBy,
        if (sortOrder != null) 'sortOrder': sortOrder,
      },
    );

    return ProductListResponse.fromJson(response);
  }

  @override
  Future<List<ProductModel>> getFeatured({int limit = 10}) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConstants.marketplaceProductsFeatured,
      queryParameters: {'limit': limit},
    );

    final products = (response['products'] as List<dynamic>?)
            ?.map((p) => ProductModel.fromJson(p as Map<String, dynamic>))
            .toList() ??
        [];

    return products;
  }

  @override
  Future<List<ProductModel>> getRecent({int limit = 10}) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConstants.marketplaceProductsRecent,
      queryParameters: {'limit': limit},
    );

    final products = (response['products'] as List<dynamic>?)
            ?.map((p) => ProductModel.fromJson(p as Map<String, dynamic>))
            .toList() ??
        [];

    return products;
  }

  @override
  Future<ProductModel> getById(String id) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConstants.marketplaceProductById(id),
    );

    return ProductModel.fromJson(response);
  }

  @override
  Future<ProductListResponse> search({
    required String query,
    int page = 1,
    int limit = 20,
    String? categoryId,
  }) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConstants.marketplaceSearch,
      queryParameters: {
        'q': query,
        'page': page,
        'limit': limit,
        if (categoryId != null) 'categoryId': categoryId,
      },
    );

    return ProductListResponse.fromJson(response);
  }

  @override
  Future<ProductListResponse> getByCategory(
    String categoryId, {
    int page = 1,
    int limit = 20,
  }) async {
    return getProducts(
      categoryId: categoryId,
      page: page,
      limit: limit,
    );
  }

  @override
  Future<List<CategoryModel>> getCategories() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConstants.marketplaceCategories,
    );

    final categories = (response['categories'] as List<dynamic>?)
            ?.map((c) => CategoryModel.fromJson(c as Map<String, dynamic>))
            .toList() ??
        [];

    return categories;
  }

  @override
  Future<ProductListResponse> getSellerProducts({
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConstants.products,
      queryParameters: {
        'page': page,
        'limit': limit,
        if (status != null) 'status': status,
      },
    );

    return ProductListResponse.fromJson(response);
  }

  @override
  Future<ProductModel> create(CreateProductRequest request) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiConstants.products,
      data: request.toJson(),
    );

    return ProductModel.fromJson(response);
  }

  @override
  Future<ProductModel> update(String id, UpdateProductRequest request) async {
    final response = await _apiClient.patch<Map<String, dynamic>>(
      ApiConstants.productById(id),
      data: request.toJson(),
    );

    return ProductModel.fromJson(response);
  }

  @override
  Future<void> delete(String id) async {
    await _apiClient.delete<void>(ApiConstants.productById(id));
  }

  @override
  Future<List<ProductImage>> uploadImages(
    String productId,
    List<String> imagePaths,
  ) async {
    final files = await Future.wait(
      imagePaths.map((path) => MultipartFile.fromFile(path)),
    );

    final response = await _apiClient.uploadFile<Map<String, dynamic>>(
      '${ApiConstants.productById(productId)}/images',
      files: files,
      fileField: 'images',
    );

    final images = (response['images'] as List<dynamic>?)
            ?.map((i) => ProductImage.fromJson(i as Map<String, dynamic>))
            .toList() ??
        [];

    return images;
  }
}
