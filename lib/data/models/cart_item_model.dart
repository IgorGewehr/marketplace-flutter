/// Cart item model for Compre Aqui
library;

import 'product_model.dart';

class CartModel {
  final String id;
  final String userId;
  final List<CartItemModel> items;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CartModel({
    required this.id,
    required this.userId,
    this.items = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  /// Get total items quantity
  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);

  /// Get unique items count
  int get itemsCount => items.length;

  /// Get cart subtotal
  double get subtotal => items.fold(0.0, (sum, item) => sum + item.total);

  /// Check if cart is empty
  bool get isEmpty => items.isEmpty;

  /// Check if cart has items
  bool get isNotEmpty => items.isNotEmpty;

  factory CartModel.fromJson(Map<String, dynamic> json) {
    return CartModel(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      items: (json['items'] as List<dynamic>?)
              ?.map((i) => CartItemModel.fromJson(i as Map<String, dynamic>))
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

  CartModel copyWith({
    String? id,
    String? userId,
    List<CartItemModel>? items,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CartModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      items: items ?? this.items,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Create empty cart for user
  factory CartModel.empty(String userId) {
    final now = DateTime.now();
    return CartModel(
      id: '',
      userId: userId,
      items: [],
      createdAt: now,
      updatedAt: now,
    );
  }
}

class CartItemModel {
  final String id;
  final String productId;
  final String? variantId;
  final ProductModel? product;
  final ProductVariant? variant;
  final int quantity;
  final String tenantId;
  final DateTime addedAt;

  const CartItemModel({
    required this.id,
    required this.productId,
    this.variantId,
    this.product,
    this.variant,
    required this.quantity,
    required this.tenantId,
    required this.addedAt,
  });

  /// Get item name
  String get name {
    if (product != null && variant != null) {
      return '${product!.name} - ${variant!.name}';
    }
    return product?.name ?? '';
  }

  /// Get item image URL
  String? get imageUrl => product?.mainImageUrl;

  /// Get unit price
  double get unitPrice => variant?.price ?? product?.price ?? 0.0;

  /// Get total price
  double get total => unitPrice * quantity;

  /// Check if item has discount
  bool get hasDiscount {
    final compareAt = variant?.compareAtPrice ?? product?.compareAtPrice;
    return compareAt != null && compareAt > unitPrice;
  }

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    return CartItemModel(
      id: json['id'] as String? ?? '',
      productId: json['productId'] as String? ?? '',
      variantId: json['variantId'] as String?,
      product: json['product'] != null
          ? ProductModel.fromJson(json['product'] as Map<String, dynamic>)
          : null,
      variant: json['variant'] != null
          ? ProductVariant.fromJson(json['variant'] as Map<String, dynamic>)
          : null,
      quantity: json['quantity'] as int? ?? 1,
      tenantId: json['tenantId'] as String? ?? '',
      addedAt: json['addedAt'] != null
          ? DateTime.parse(json['addedAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productId': productId,
      if (variantId != null) 'variantId': variantId,
      if (product != null) 'product': product!.toJson(),
      if (variant != null) 'variant': variant!.toJson(),
      'quantity': quantity,
      'tenantId': tenantId,
      'addedAt': addedAt.toIso8601String(),
    };
  }

  CartItemModel copyWith({
    String? id,
    String? productId,
    String? variantId,
    ProductModel? product,
    ProductVariant? variant,
    int? quantity,
    String? tenantId,
    DateTime? addedAt,
  }) {
    return CartItemModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      variantId: variantId ?? this.variantId,
      product: product ?? this.product,
      variant: variant ?? this.variant,
      quantity: quantity ?? this.quantity,
      tenantId: tenantId ?? this.tenantId,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartItemModel &&
          runtimeType == other.runtimeType &&
          productId == other.productId &&
          variantId == other.variantId;

  @override
  int get hashCode => Object.hash(productId, variantId);
}
