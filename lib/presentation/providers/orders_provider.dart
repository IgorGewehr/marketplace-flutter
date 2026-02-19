import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/order_model.dart';
import '../../domain/repositories/order_repository.dart';
import 'core_providers.dart';

/// Order status enum for use in providers/screens
enum OrderStatus {
  pending,
  pendingPayment,
  confirmed,
  processing,
  preparing,
  ready,
  shipped,
  outForDelivery,
  delivered,
  cancelled,
  refunded,
}

/// Order filter enum
enum OrderFilter {
  all,
  pending,
  processing,
  shipped,
  delivered,
  cancelled,
}

/// Orders state
class OrdersState {
  final List<OrderModel> orders;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;
  final OrderFilter filter;

  const OrdersState({
    this.orders = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
    this.filter = OrderFilter.all,
  });

  OrdersState copyWith({
    List<OrderModel>? orders,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
    OrderFilter? filter,
  }) {
    return OrdersState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: error,
      filter: filter ?? this.filter,
    );
  }

  List<OrderModel> get filteredOrders {
    if (filter == OrderFilter.all) return orders;
    return orders.where((order) {
      switch (filter) {
        case OrderFilter.pending:
          return order.status == 'pending_payment' || order.status == 'pending';
        case OrderFilter.processing:
          return order.status == 'processing' || order.status == 'preparing';
        case OrderFilter.shipped:
          return order.status == 'shipped' || order.status == 'out_for_delivery';
        case OrderFilter.delivered:
          return order.status == 'delivered';
        case OrderFilter.cancelled:
          return order.status == 'cancelled' || order.status == 'refunded';
        default:
          return true;
      }
    }).toList();
  }
}

/// Orders notifier
class OrdersNotifier extends Notifier<OrdersState> {
  static const int _pageSize = 20;
  int _currentPage = 1;

  @override
  OrdersState build() {
    _loadOrders();
    return const OrdersState(isLoading: true);
  }

  Future<void> _loadOrders() async {
    try {
      final orderRepo = ref.read(orderRepositoryProvider);
      final response = await orderRepo.getOrders(page: 1, limit: _pageSize);
      
      state = state.copyWith(
        orders: response.orders,
        isLoading: false,
        hasMore: response.orders.length >= _pageSize,
      );
      _currentPage = 1;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    await _loadOrders();
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final orderRepo = ref.read(orderRepositoryProvider);
      final response = await orderRepo.getOrders(
        page: _currentPage + 1,
        limit: _pageSize,
      );

      state = state.copyWith(
        orders: [...state.orders, ...response.orders],
        isLoadingMore: false,
        hasMore: response.orders.length >= _pageSize,
      );
      _currentPage++;
    } catch (e) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  void setFilter(OrderFilter filter) {
    state = state.copyWith(filter: filter);
  }
}

/// Orders provider
final ordersProvider = NotifierProvider<OrdersNotifier, OrdersState>(
  OrdersNotifier.new,
);

/// Order detail provider
final orderDetailProvider = FutureProvider.family<OrderModel?, String>((ref, id) async {
  final orderRepo = ref.read(orderRepositoryProvider);
  try {
    return await orderRepo.getById(id);
  } catch (_) {
    return null;
  }
});

/// Order status display helper
String getOrderStatusDisplay(String status) {
  return switch (status) {
    'pending_payment' => 'Aguardando pagamento',
    'pending' => 'Pendente',
    'confirmed' => 'Confirmado',
    'processing' => 'Em preparação',
    'preparing' => 'Preparando',
    'shipped' => 'Enviado',
    'out_for_delivery' => 'Saiu para entrega',
    'delivered' => 'Entregue',
    'cancelled' => 'Cancelado',
    'refunded' => 'Reembolsado',
    _ => status,
  };
}

/// Order status color helper
int getOrderStatusColor(String status) {
  return switch (status) {
    'pending_payment' || 'pending' => 0xFFFFA000, // Orange
    'confirmed' || 'processing' || 'preparing' => 0xFF2196F3, // Blue
    'shipped' || 'out_for_delivery' => 0xFF9C27B0, // Purple
    'delivered' => 0xFF4CAF50, // Green
    'cancelled' || 'refunded' => 0xFFF44336, // Red
    _ => 0xFF757575, // Grey
  };
}

/// Orders filter enum for screen
enum OrdersFilter {
  active,
  delivered,
  cancelled,
}

/// Orders filter provider for screen
final ordersFilterProvider = StateProvider<OrdersFilter?>((ref) => null);

/// Order status info class for display
class OrderStatusInfo {
  final String label;
  final Color backgroundColor;
  final Color textColor;

  const OrderStatusInfo({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });
}

/// Map string status from API to OrderStatus enum
OrderStatus _parseOrderStatus(String statusString) {
  return switch (statusString) {
    'pending' => OrderStatus.pending,
    'pending_payment' => OrderStatus.pendingPayment,
    'confirmed' => OrderStatus.confirmed,
    'processing' => OrderStatus.processing,
    'preparing' => OrderStatus.preparing,
    'ready' => OrderStatus.ready,
    'shipped' => OrderStatus.shipped,
    'out_for_delivery' => OrderStatus.outForDelivery,
    'delivered' => OrderStatus.delivered,
    'cancelled' => OrderStatus.cancelled,
    'refunded' => OrderStatus.refunded,
    _ => OrderStatus.pending,
  };
}

/// Get order status display info from string status
OrderStatusInfo getOrderStatusInfo(String statusString) {
  final status = _parseOrderStatus(statusString);

  return switch (status) {
    OrderStatus.pending => const OrderStatusInfo(
        label: 'Pendente',
        backgroundColor: Color(0xFFFFF3E0),
        textColor: Color(0xFFF57C00),
      ),
    OrderStatus.pendingPayment => const OrderStatusInfo(
        label: 'Aguardando pagamento',
        backgroundColor: Color(0xFFFFF3E0),
        textColor: Color(0xFFF57C00),
      ),
    OrderStatus.confirmed => const OrderStatusInfo(
        label: 'Confirmado',
        backgroundColor: Color(0xFFE3F2FD),
        textColor: Color(0xFF1976D2),
      ),
    OrderStatus.processing || OrderStatus.preparing => const OrderStatusInfo(
        label: 'Em preparação',
        backgroundColor: Color(0xFFE3F2FD),
        textColor: Color(0xFF1976D2),
      ),
    OrderStatus.ready => const OrderStatusInfo(
        label: 'Pronto para envio',
        backgroundColor: Color(0xFFE8EAF6),
        textColor: Color(0xFF3F51B5),
      ),
    OrderStatus.shipped => const OrderStatusInfo(
        label: 'Enviado',
        backgroundColor: Color(0xFFF3E5F5),
        textColor: Color(0xFF7B1FA2),
      ),
    OrderStatus.outForDelivery => const OrderStatusInfo(
        label: 'Saiu para entrega',
        backgroundColor: Color(0xFFF3E5F5),
        textColor: Color(0xFF7B1FA2),
      ),
    OrderStatus.delivered => const OrderStatusInfo(
        label: 'Entregue',
        backgroundColor: Color(0xFFE8F5E9),
        textColor: Color(0xFF388E3C),
      ),
    OrderStatus.cancelled => const OrderStatusInfo(
        label: 'Cancelado',
        backgroundColor: Color(0xFFFFEBEE),
        textColor: Color(0xFFD32F2F),
      ),
    OrderStatus.refunded => const OrderStatusInfo(
        label: 'Reembolsado',
        backgroundColor: Color(0xFFFFEBEE),
        textColor: Color(0xFFD32F2F),
      ),
  };
}
