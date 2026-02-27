import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/review_model.dart';
import 'core_providers.dart';

/// Reviews for a specific product (public).
final productReviewsProvider =
    FutureProvider.family<List<ReviewModel>, String>((ref, productId) async {
  if (productId.isEmpty) return [];
  return ref.read(reviewRepositoryProvider).getProductReviews(productId);
});

/// Reviews for all products of a seller (public).
final sellerReviewsProvider =
    FutureProvider.family<List<ReviewModel>, String>((ref, tenantId) async {
  if (tenantId.isEmpty) return [];
  return ref.read(reviewRepositoryProvider).getSellerReviews(tenantId);
});

/// Which productIds the current user has already reviewed for a given order.
final reviewedProductIdsProvider =
    FutureProvider.family<Set<String>, String>((ref, orderId) async {
  if (orderId.isEmpty) return {};
  return ref.read(reviewRepositoryProvider).getReviewedProductIds(orderId);
});

// ---------------------------------------------------------------------------
// Submit review — StateNotifier
// ---------------------------------------------------------------------------

class ReviewSubmitState {
  final bool isLoading;
  final ReviewModel? review;
  final String? error;

  const ReviewSubmitState({
    this.isLoading = false,
    this.review,
    this.error,
  });

  ReviewSubmitState copyWith({
    bool? isLoading,
    ReviewModel? review,
    String? error,
  }) {
    return ReviewSubmitState(
      isLoading: isLoading ?? this.isLoading,
      review: review ?? this.review,
      error: error,
    );
  }
}

class ReviewSubmitNotifier extends StateNotifier<ReviewSubmitState> {
  final Ref _ref;

  ReviewSubmitNotifier(this._ref) : super(const ReviewSubmitState());

  Future<bool> submit({
    required String productId,
    required String tenantId,
    required String orderId,
    required double rating,
    String? comment,
  }) async {
    state = const ReviewSubmitState(isLoading: true);
    try {
      final review = await _ref.read(reviewRepositoryProvider).createReview(
            productId: productId,
            tenantId: tenantId,
            orderId: orderId,
            rating: rating,
            comment: comment,
          );
      state = ReviewSubmitState(review: review);

      // Invalidate caches so product/seller pages refresh
      _ref.invalidate(productReviewsProvider(productId));
      _ref.invalidate(sellerReviewsProvider(tenantId));
      _ref.invalidate(reviewedProductIdsProvider(orderId));

      return true;
    } catch (e) {
      String msg = 'Erro ao enviar avaliação';
      final str = e.toString();
      if (str.contains('409') || str.contains('já avaliou')) {
        msg = 'Você já avaliou este produto';
      } else if (str.contains('400')) {
        msg = 'Pedido ainda não entregue';
      }
      state = ReviewSubmitState(error: msg);
      return false;
    }
  }

  void reset() => state = const ReviewSubmitState();
}

final reviewSubmitProvider =
    StateNotifierProvider.autoDispose<ReviewSubmitNotifier, ReviewSubmitState>(
  (ref) => ReviewSubmitNotifier(ref),
);
