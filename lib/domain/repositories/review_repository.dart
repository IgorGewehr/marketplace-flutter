/// Review repository interface
library;

import '../../data/models/review_model.dart';

abstract class ReviewRepository {
  /// Fetch paginated reviews for a product.
  Future<List<ReviewModel>> getProductReviews(
    String productId, {
    int page = 1,
    int limit = 10,
  });

  /// Fetch paginated reviews for all products of a seller.
  Future<List<ReviewModel>> getSellerReviews(
    String tenantId, {
    int page = 1,
    int limit = 10,
  });

  /// Returns the set of productIds already reviewed for a given order
  /// by the current authenticated user.
  Future<Set<String>> getReviewedProductIds(String orderId);

  /// Create a product review. Returns the created review.
  Future<ReviewModel> createReview({
    required String productId,
    required String tenantId,
    required String orderId,
    required double rating,
    String? comment,
  });
}
