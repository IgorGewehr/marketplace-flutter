import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/order_model.dart';
import '../../data/models/review_model.dart';
import 'core_providers.dart';
import 'orders_provider.dart';

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

/// Finds a delivered order where the current user bought a specific product
/// and hasn't reviewed it yet. Returns (orderId, tenantId) or null.
final reviewableOrderForProductProvider =
    FutureProvider.autoDispose.family<({String orderId, String tenantId})?, String>(
        (ref, productId) async {
  if (productId.isEmpty) return null;

  final ordersState = ref.watch(ordersProvider).valueOrNull;
  if (ordersState == null) return null;

  for (final order in ordersState.orders) {
    if (!order.isDeliveryConfirmed) continue;
    final hasProduct = order.items.any((item) => item.productId == productId);
    if (!hasProduct) continue;

    // Check if already reviewed
    try {
      final reviewed = await ref.read(reviewRepositoryProvider).getReviewedProductIds(order.id);
      if (!reviewed.contains(productId)) {
        return (orderId: order.id, tenantId: order.tenantId);
      }
    } catch (_) {
      continue;
    }
  }
  return null;
});

/// Finds delivered orders for a given seller where the user has unreviewed products.
/// Returns list of (orderId, productId, productName, productImageUrl).
final reviewableProductsForSellerProvider = FutureProvider.autoDispose
    .family<List<({String orderId, String tenantId, OrderItemModel item})>, String>(
        (ref, tenantId) async {
  if (tenantId.isEmpty) return [];

  final ordersState = ref.watch(ordersProvider).valueOrNull;
  if (ordersState == null) return [];

  final result = <({String orderId, String tenantId, OrderItemModel item})>[];

  for (final order in ordersState.orders) {
    if (!order.isDeliveryConfirmed) continue;
    if (order.tenantId != tenantId) continue;

    try {
      final reviewed = await ref.read(reviewRepositoryProvider).getReviewedProductIds(order.id);
      for (final item in order.items) {
        if (!reviewed.contains(item.productId)) {
          result.add((orderId: order.id, tenantId: order.tenantId, item: item));
        }
      }
    } catch (_) {
      continue;
    }
  }
  return result;
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
