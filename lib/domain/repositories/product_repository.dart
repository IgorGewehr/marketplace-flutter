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
    String? productType,
    String? listingType,
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

  /// Get featured jobs
  Future<List<ProductModel>> getFeaturedJobs({int limit = 10});

  /// Get recent jobs
  Future<List<ProductModel>> getRecentJobs({int limit = 20});

  /// Get paginated jobs with filters
  Future<ProductListResponse> getJobs({
    int page = 1,
    int limit = 20,
    String? jobType,
    String? workMode,
    String? sortBy,
    String? search,
  });

  /// Get featured rentals
  Future<List<ProductModel>> getFeaturedRentals({int limit = 10});

  /// Get recent rentals
  Future<List<ProductModel>> getRecentRentals({int limit = 10});

  /// Get paginated rentals
  Future<ProductListResponse> getRentals({
    int page = 1,
    int limit = 20,
    String? rentalType,
    String? rentalPeriod,
    double? minPrice,
    double? maxPrice,
    String? city,
    int? bedrooms,
    double? minArea,
    String? sortBy,
    String? search,
  });
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
  final List<ProductImage>? images;
  final List<String>? tags;
  final int quantity;
  final bool trackInventory;
  final bool? hasVariants;
  final String productType;
  final Map<String, dynamic>? rentalInfo;
  final Map<String, dynamic>? location;
  // Job fields
  final String listingType;
  final String? companyName;
  final String? salary;
  final bool? salaryNegotiable;
  final String? jobType;
  final String? workMode;
  final List<String>? requirements;
  final List<String>? benefits;
  final String? contactEmail;
  final String? contactPhone;

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
    this.images,
    this.tags,
    this.quantity = 0,
    this.trackInventory = true,
    this.hasVariants,
    this.productType = 'product',
    this.rentalInfo,
    this.location,
    this.listingType = 'product',
    this.companyName,
    this.salary,
    this.salaryNegotiable,
    this.jobType,
    this.workMode,
    this.requirements,
    this.benefits,
    this.contactEmail,
    this.contactPhone,
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
      if (images != null) 'images': images!.map((i) => i.toJson()).toList(),
      if (tags != null && tags!.isNotEmpty) 'tags': tags,
      'quantity': quantity,
      'trackInventory': trackInventory,
      if (hasVariants != null) 'hasVariants': hasVariants,
      'productType': productType,
      if (rentalInfo != null) 'rentalInfo': rentalInfo,
      if (location != null) 'location': location,
      'listingType': listingType,
      if (companyName != null) 'companyName': companyName,
      if (salary != null) 'salary': salary,
      if (salaryNegotiable != null) 'salaryNegotiable': salaryNegotiable,
      if (jobType != null) 'jobType': jobType,
      if (workMode != null) 'workMode': workMode,
      if (requirements != null && requirements!.isNotEmpty) 'requirements': requirements,
      if (benefits != null && benefits!.isNotEmpty) 'benefits': benefits,
      if (contactEmail != null) 'contactEmail': contactEmail,
      if (contactPhone != null) 'contactPhone': contactPhone,
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
  final List<ProductImage>? images;
  final List<String>? tags;
  final List<Map<String, dynamic>>? variants;
  final int? quantity;
  final bool? trackInventory;
  final bool? hasVariants;
  final String? productType;
  final Map<String, dynamic>? rentalInfo;
  final Map<String, dynamic>? location;
  // Job fields
  final String? listingType;
  final String? companyName;
  final String? salary;
  final bool? salaryNegotiable;
  final String? jobType;
  final String? workMode;
  final List<String>? requirements;
  final List<String>? benefits;
  final String? contactEmail;
  final String? contactPhone;

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
    this.images,
    this.tags,
    this.variants,
    this.quantity,
    this.trackInventory,
    this.hasVariants,
    this.productType,
    this.rentalInfo,
    this.location,
    this.listingType,
    this.companyName,
    this.salary,
    this.salaryNegotiable,
    this.jobType,
    this.workMode,
    this.requirements,
    this.benefits,
    this.contactEmail,
    this.contactPhone,
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
      if (images != null) 'images': images!.map((i) => i.toJson()).toList(),
      if (tags != null) 'tags': tags,
      if (variants != null) 'variants': variants,
      if (quantity != null) 'quantity': quantity,
      if (trackInventory != null) 'trackInventory': trackInventory,
      if (hasVariants != null) 'hasVariants': hasVariants,
      if (productType != null) 'productType': productType,
      if (rentalInfo != null) 'rentalInfo': rentalInfo,
      if (location != null) 'location': location,
      if (listingType != null) 'listingType': listingType,
      if (companyName != null) 'companyName': companyName,
      if (salary != null) 'salary': salary,
      if (salaryNegotiable != null) 'salaryNegotiable': salaryNegotiable,
      if (jobType != null) 'jobType': jobType,
      if (workMode != null) 'workMode': workMode,
      if (requirements != null) 'requirements': requirements,
      if (benefits != null) 'benefits': benefits,
      if (contactEmail != null) 'contactEmail': contactEmail,
      if (contactPhone != null) 'contactPhone': contactPhone,
    };
  }
}
