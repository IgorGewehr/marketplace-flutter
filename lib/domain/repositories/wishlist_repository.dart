/// Wishlist repository interface
library;

import '../../data/models/wishlist_model.dart';

abstract class WishlistRepository {
  /// Get user's wishlist
  Future<WishlistModel?> getUserWishlist(String userId);

  /// Add product to wishlist
  Future<void> addToWishlist(String userId, WishlistItem item);

  /// Remove product from wishlist
  Future<void> removeFromWishlist(String userId, String productId);

  /// Check if product is in wishlist
  Future<bool> isInWishlist(String userId, String productId);

  /// Update wishlist item settings
  Future<void> updateWishlistItem(String userId, WishlistItem item);

  /// Clear entire wishlist
  Future<void> clearWishlist(String userId);

  /// Get wishlist items count
  Future<int> getWishlistCount(String userId);
}
