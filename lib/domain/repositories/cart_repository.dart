import '../../data/models/cart_item_model.dart';

/// Cart Repository Interface
abstract class CartRepository {
  /// Get current cart
  Future<CartModel> getCart();

  /// Add item to cart
  Future<CartModel> addItem({
    required String productId,
    String? variantId,
    int quantity = 1,
  });

  /// Update item quantity
  Future<CartModel> updateItemQuantity({
    required String itemId,
    required int quantity,
  });

  /// Remove item from cart
  Future<CartModel> removeItem(String itemId);

  /// Clear all items from cart
  Future<void> clearCart();

  /// Get cart item count
  Future<int> getItemCount();

  /// Check if product is in cart
  Future<bool> isInCart(String productId, {String? variantId});
}
