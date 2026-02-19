import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/api_constants.dart';
import '../../data/models/order_model.dart';
import 'auth_providers.dart';
import 'core_providers.dart';

/// Filter options for seller orders
enum SellerOrdersFilter { all, newOrders, preparing, shipped, delivered }

/// Filter state for seller orders
final sellerOrdersFilterProvider = StateProvider<SellerOrdersFilter>((ref) => SellerOrdersFilter.all);

/// Provider for orders received by seller
final sellerOrdersProvider = AsyncNotifierProvider<SellerOrdersNotifier, List<OrderModel>>(() {
  return SellerOrdersNotifier();
});

/// Count of new orders (pending status)
final newOrdersCountProvider = Provider<int>((ref) {
  final ordersAsync = ref.watch(sellerOrdersProvider);
  return ordersAsync.maybeWhen(
    data: (orders) => orders.where((o) => o.status == 'pending').length,
    orElse: () => 0,
  );
});

/// Filtered orders based on status filter
final filteredSellerOrdersProvider = Provider<AsyncValue<List<OrderModel>>>((ref) {
  final ordersAsync = ref.watch(sellerOrdersProvider);
  final filter = ref.watch(sellerOrdersFilterProvider);

  return ordersAsync.whenData((orders) {
    switch (filter) {
      case SellerOrdersFilter.newOrders:
        return orders.where((o) => o.status == 'pending').toList();
      case SellerOrdersFilter.preparing:
        return orders.where((o) => o.status == 'confirmed' || o.status == 'preparing').toList();
      case SellerOrdersFilter.shipped:
        return orders.where((o) => o.status == 'shipped' || o.status == 'ready').toList();
      case SellerOrdersFilter.delivered:
        return orders.where((o) => o.status == 'delivered').toList();
      case SellerOrdersFilter.all:
        return orders;
    }
  });
});

class SellerOrdersNotifier extends AsyncNotifier<List<OrderModel>> {
  static const int _pageSize = 20;
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  @override
  Future<List<OrderModel>> build() async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null || !user.isSeller) return [];

    try {
      final repository = ref.read(orderRepositoryProvider);
      final response = await repository.getSellerOrders(page: 1, limit: _pageSize);
      _currentPage = 1;
      _hasMore = response.hasMore;
      return response.orders;
    } catch (e) {
      return [];
    }
  }

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    final current = state.valueOrNull;
    if (current == null) return;

    _isLoadingMore = true;

    try {
      final repository = ref.read(orderRepositoryProvider);
      final response = await repository.getSellerOrders(
        page: _currentPage + 1,
        limit: _pageSize,
      );
      _currentPage++;
      _hasMore = response.hasMore;
      _isLoadingMore = false;
      state = AsyncValue.data([...current, ...response.orders]);
    } catch (e) {
      _isLoadingMore = false;
    }
  }

  Future<void> updateOrderStatus(String orderId, String newStatus, {String? note}) async {
    try {
      final repository = ref.read(orderRepositoryProvider);
      await repository.updateStatus(
        orderId: orderId,
        status: newStatus,
        note: note,
      );

      // Refresh orders list
      await refresh();
    } catch (e) {
      // Handle error
      rethrow;
    }
  }

  Future<void> addTrackingCode(String orderId, String trackingCode, {String? shippingCompany}) async {
    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.patch<Map<String, dynamic>>(
        ApiConstants.sellerOrderTracking(orderId),
        data: {
          'trackingCode': trackingCode,
          if (shippingCompany != null) 'shippingCompany': shippingCompany,
        },
      );

      // Refresh orders list to get updated data
      await refresh();
    } catch (e) {
      rethrow;
    }
  }
}
