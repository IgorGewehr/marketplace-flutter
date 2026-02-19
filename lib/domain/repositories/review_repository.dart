/// Review repository interface
library;

import '../../data/models/review_model.dart';

abstract class ReviewRepository {
  /// Get reviews for a product
  Future<List<ReviewModel>> getProductReviews(String productId);

  /// Get reviews for a seller/tenant
  Future<List<ReviewModel>> getSellerReviews(String tenantId);

  /// Get review by ID
  Future<ReviewModel?> getReviewById(String reviewId);

  /// Create a new review
  Future<ReviewModel> createReview(ReviewModel review);

  /// Update review
  Future<void> updateReview(ReviewModel review);

  /// Delete review
  Future<void> deleteReview(String reviewId);

  /// Add seller response to review
  Future<void> addSellerResponse(String reviewId, ReviewResponse response);

  /// Mark review as helpful
  Future<void> markAsHelpful(String reviewId, String userId);

  /// Report review
  Future<void> reportReview(String reviewId, String userId, String reason);

  /// Get rating summary for target
  Future<RatingSummary> getRatingSummary(String targetId, String targetType);

  /// Check if user can review (has purchased)
  Future<bool> canUserReview(String userId, String targetId);
}
