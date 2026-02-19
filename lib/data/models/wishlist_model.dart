/// Wishlist/Favorites model for saved products
library;

class WishlistModel {
  final String id;
  final String userId;
  final List<WishlistItem> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WishlistModel({
    required this.id,
    required this.userId,
    this.items = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  /// Get total items count
  int get itemsCount => items.length;

  /// Check if product is in wishlist
  bool containsProduct(String productId) {
    return items.any((item) => item.productId == productId);
  }

  /// Get wishlist item by product ID
  WishlistItem? getItem(String productId) {
    try {
      return items.firstWhere((item) => item.productId == productId);
    } catch (_) {
      return null;
    }
  }

  factory WishlistModel.fromJson(Map<String, dynamic> json) {
    return WishlistModel(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      items: (json['items'] as List<dynamic>?)
              ?.map((i) => WishlistItem.fromJson(i as Map<String, dynamic>))
              .toList() ??
          [],
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
      'userId': userId,
      'items': items.map((i) => i.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  WishlistModel copyWith({
    String? id,
    String? userId,
    List<WishlistItem>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WishlistModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WishlistModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class WishlistItem {
  final String productId;
  final String? variantId;
  final String productName;
  final double price;
  final double? compareAtPrice;
  final String? imageUrl;
  final String tenantId;
  final String tenantName;
  final bool isAvailable;
  final bool notifyOnPriceDrops;
  final bool notifyOnAvailability;
  final DateTime addedAt;

  const WishlistItem({
    required this.productId,
    this.variantId,
    required this.productName,
    required this.price,
    this.compareAtPrice,
    this.imageUrl,
    required this.tenantId,
    required this.tenantName,
    this.isAvailable = true,
    this.notifyOnPriceDrops = false,
    this.notifyOnAvailability = false,
    required this.addedAt,
  });

  /// Check if product has a discount
  bool get hasDiscount => compareAtPrice != null && compareAtPrice! > price;

  /// Get discount percentage
  int get discountPercentage {
    if (!hasDiscount) return 0;
    return (((compareAtPrice! - price) / compareAtPrice!) * 100).round();
  }

  factory WishlistItem.fromJson(Map<String, dynamic> json) {
    return WishlistItem(
      productId: json['productId'] as String? ?? '',
      variantId: json['variantId'] as String?,
      productName: json['productName'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      compareAtPrice: (json['compareAtPrice'] as num?)?.toDouble(),
      imageUrl: json['imageUrl'] as String?,
      tenantId: json['tenantId'] as String? ?? '',
      tenantName: json['tenantName'] as String? ?? '',
      isAvailable: json['isAvailable'] as bool? ?? true,
      notifyOnPriceDrops: json['notifyOnPriceDrops'] as bool? ?? false,
      notifyOnAvailability: json['notifyOnAvailability'] as bool? ?? false,
      addedAt: json['addedAt'] != null
          ? DateTime.parse(json['addedAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      if (variantId != null) 'variantId': variantId,
      'productName': productName,
      'price': price,
      if (compareAtPrice != null) 'compareAtPrice': compareAtPrice,
      if (imageUrl != null) 'imageUrl': imageUrl,
      'tenantId': tenantId,
      'tenantName': tenantName,
      'isAvailable': isAvailable,
      'notifyOnPriceDrops': notifyOnPriceDrops,
      'notifyOnAvailability': notifyOnAvailability,
      'addedAt': addedAt.toIso8601String(),
    };
  }

  WishlistItem copyWith({
    String? productId,
    String? variantId,
    String? productName,
    double? price,
    double? compareAtPrice,
    String? imageUrl,
    String? tenantId,
    String? tenantName,
    bool? isAvailable,
    bool? notifyOnPriceDrops,
    bool? notifyOnAvailability,
    DateTime? addedAt,
  }) {
    return WishlistItem(
      productId: productId ?? this.productId,
      variantId: variantId ?? this.variantId,
      productName: productName ?? this.productName,
      price: price ?? this.price,
      compareAtPrice: compareAtPrice ?? this.compareAtPrice,
      imageUrl: imageUrl ?? this.imageUrl,
      tenantId: tenantId ?? this.tenantId,
      tenantName: tenantName ?? this.tenantName,
      isAvailable: isAvailable ?? this.isAvailable,
      notifyOnPriceDrops: notifyOnPriceDrops ?? this.notifyOnPriceDrops,
      notifyOnAvailability: notifyOnAvailability ?? this.notifyOnAvailability,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WishlistItem &&
          runtimeType == other.runtimeType &&
          productId == other.productId &&
          variantId == other.variantId;

  @override
  int get hashCode => Object.hash(productId, variantId);
}
