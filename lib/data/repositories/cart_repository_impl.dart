import '../../core/constants/api_constants.dart';
import '../../domain/repositories/cart_repository.dart';
import '../datasources/api_client.dart';
import '../models/cart_item_model.dart';

/// Cart Repository Implementation
class CartRepositoryImpl implements CartRepository {
  final ApiClient _apiClient;

  CartRepositoryImpl({required ApiClient apiClient}) : _apiClient = apiClient;

  @override
  Future<CartModel> getCart() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConstants.cart,
    );

    return CartModel.fromJson(response);
  }

  @override
  Future<CartModel> addItem({
    required String productId,
    String? variantId,
    int quantity = 1,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiConstants.cartItems,
      data: {
        'productId': productId,
        if (variantId != null) 'variantId': variantId,
        'quantity': quantity,
      },
    );

    return CartModel.fromJson(response);
  }

  @override
  Future<CartModel> updateItemQuantity({
    required String itemId,
    required int quantity,
  }) async {
    final response = await _apiClient.patch<Map<String, dynamic>>(
      ApiConstants.cartItemById(itemId),
      data: {'quantity': quantity},
    );

    return CartModel.fromJson(response);
  }

  @override
  Future<CartModel> removeItem(String itemId) async {
    final response = await _apiClient.delete<Map<String, dynamic>>(
      ApiConstants.cartItemById(itemId),
    );

    return CartModel.fromJson(response);
  }

  @override
  Future<void> clearCart() async {
    await _apiClient.delete<void>(ApiConstants.cart);
  }

  @override
  Future<int> getItemCount() async {
    final cart = await getCart();
    return cart.totalQuantity;
  }

  @override
  Future<bool> isInCart(String productId, {String? variantId}) async {
    final cart = await getCart();
    return cart.items.any(
      (item) =>
          item.productId == productId &&
          (variantId == null || item.variantId == variantId),
    );
  }
}
