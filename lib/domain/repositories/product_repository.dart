import '../../data/models/product_model.dart';
import '../../data/models/category_model.dart';

/// Product Repository Interface
abstract class ProductRepository {
  /// Get paginated list of products
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
  });

  /// Get featured products
  Future<List<ProductModel>> getFeatured({int limit = 10});

  /// Get recent products
  Future<List<ProductModel>> getRecent({int limit = 10});

  /// Get product by ID
  Future<ProductModel> getById(String id);

  /// Search products
  Future<ProductListResponse> search({
    required String query,
    int page = 1,
    int limit = 20,
    String? categoryId,
  });

  /// Get products by category
  Future<ProductListResponse> getByCategory(
    String categoryId, {
    int page = 1,
    int limit = 20,
  });

  /// Get all categories
  Future<List<CategoryModel>> getCategories();

  /// Get seller products (requires seller auth)
  Future<ProductListResponse> getSellerProducts({
    int page = 1,
    int limit = 20,
    String? status,
  });

  /// Create product (seller only)
  Future<ProductModel> create(CreateProductRequest request);

  /// Update product (seller only)
  Future<ProductModel> update(String id, UpdateProductRequest request);

  /// Delete product (seller only)
  Future<void> delete(String id);

  /// Upload product images
  Future<List<ProductImage>> uploadImages(String productId, List<String> imagePaths);
}

/// Response wrapper for paginated product lists
class ProductListResponse {
  final List<ProductModel> products;
  final int total;
  final int page;
  final int limit;
  final bool hasMore;

  const ProductListResponse({
    required this.products,
    required this.total,
    required this.page,
    required this.limit,
    required this.hasMore,
  });

  factory ProductListResponse.fromJson(Map<String, dynamic> json) {
    return ProductListResponse(
      products: (json['products'] as List<dynamic>?)
              ?.map((p) => ProductModel.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      limit: json['limit'] as int? ?? 20,
      hasMore: json['hasMore'] as bool? ?? false,
    );
  }
}

/// Request model for creating a product
class CreateProductRequest {
  final String name;
  final String description;
  final String? shortDescription;
  final String categoryId;
  final double price;
  final double? compareAtPrice;
  final String? sku;
  final String visibility;
  final List<Map<String, dynamic>>? variants;

  const CreateProductRequest({
    required this.name,
    required this.description,
    this.shortDescription,
    required this.categoryId,
    required this.price,
    this.compareAtPrice,
    this.sku,
    this.visibility = 'both',
    this.variants,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      if (shortDescription != null) 'shortDescription': shortDescription,
      'categoryId': categoryId,
      'price': price,
      if (compareAtPrice != null) 'compareAtPrice': compareAtPrice,
      if (sku != null) 'sku': sku,
      'visibility': visibility,
      if (variants != null) 'variants': variants,
    };
  }
}

/// Request model for updating a product
class UpdateProductRequest {
  final String? name;
  final String? description;
  final String? shortDescription;
  final String? categoryId;
  final double? price;
  final double? compareAtPrice;
  final String? sku;
  final String? visibility;
  final String? status;

  const UpdateProductRequest({
    this.name,
    this.description,
    this.shortDescription,
    this.categoryId,
    this.price,
    this.compareAtPrice,
    this.sku,
    this.visibility,
    this.status,
  });

  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (shortDescription != null) 'shortDescription': shortDescription,
      if (categoryId != null) 'categoryId': categoryId,
      if (price != null) 'price': price,
      if (compareAtPrice != null) 'compareAtPrice': compareAtPrice,
      if (sku != null) 'sku': sku,
      if (visibility != null) 'visibility': visibility,
      if (status != null) 'status': status,
    };
  }
}
