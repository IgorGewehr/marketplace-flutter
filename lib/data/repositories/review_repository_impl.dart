/// Review repository implementation
library;

import '../datasources/api_client.dart';
import '../models/review_model.dart';
import '../../domain/repositories/review_repository.dart';

class ReviewRepositoryImpl implements ReviewRepository {
  final ApiClient _apiClient;

  ReviewRepositoryImpl({required ApiClient apiClient}) : _apiClient = apiClient;

  @override
  Future<List<ReviewModel>> getProductReviews(
    String productId, {
    int page = 1,
    int limit = 10,
  }) async {
    final result = await _apiClient.get<Map<String, dynamic>>(
      '/api/marketplace/reviews',
      queryParameters: {'productId': productId, 'page': page, 'limit': limit},
    );
    final list = result['reviews'] as List<dynamic>? ?? [];
    return list
        .map((e) => ReviewModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<List<ReviewModel>> getSellerReviews(
    String tenantId, {
    int page = 1,
    int limit = 10,
  }) async {
    final result = await _apiClient.get<Map<String, dynamic>>(
      '/api/marketplace/reviews',
      queryParameters: {'tenantId': tenantId, 'page': page, 'limit': limit},
    );
    final list = result['reviews'] as List<dynamic>? ?? [];
    return list
        .map((e) => ReviewModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Set<String>> getReviewedProductIds(String orderId) async {
    try {
      final result = await _apiClient.get<Map<String, dynamic>>(
        '/api/reviews/check',
        queryParameters: {'orderId': orderId},
      );
      final ids = result['reviewedProductIds'] as List<dynamic>? ?? [];
      return ids.cast<String>().toSet();
    } catch (_) {
      return {};
    }
  }

  @override
  Future<ReviewModel> createReview({
    required String productId,
    required String tenantId,
    required String orderId,
    required double rating,
    String? comment,
  }) async {
    final result = await _apiClient.post<Map<String, dynamic>>(
      '/api/reviews',
      data: {
        'productId': productId,
        'tenantId': tenantId,
        'orderId': orderId,
        'rating': rating,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      },
    );
    return ReviewModel.fromJson(result);
  }
}
