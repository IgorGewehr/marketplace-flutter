import '../../data/models/order_model.dart';
import '../../data/models/address_model.dart';

/// Order Repository Interface
abstract class OrderRepository {
  /// Create a new order from cart
  Future<OrderModel> create(CreateOrderRequest request);

  /// Get paginated list of orders (buyer)
  Future<OrderListResponse> getOrders({
    int page = 1,
    int limit = 20,
    String? status,
  });

  /// Get order by ID
  Future<OrderModel> getById(String id);

  /// Get seller orders (seller only)
  Future<OrderListResponse> getSellerOrders({
    int page = 1,
    int limit = 20,
    String? status,
  });

  /// Update order status (seller only)
  Future<OrderModel> updateStatus({
    required String orderId,
    required String status,
    String? note,
  });

  /// Cancel order
  Future<OrderModel> cancel(String orderId, {String? reason});

  /// Confirm delivery (buyer confirms receipt)
  Future<OrderModel> confirmDelivery(String orderId);

  /// Open a dispute for a problem with the order (buyer only)
  Future<OrderModel> disputeOrder(String orderId, {required String reason});

  /// Get order chat
  Future<String?> getOrderChatId(String orderId);
}

/// Response wrapper for paginated order lists
class OrderListResponse {
  final List<OrderModel> orders;
  final int total;
  final int page;
  final int limit;
  final bool hasMore;

  const OrderListResponse({
    required this.orders,
    required this.total,
    required this.page,
    required this.limit,
    required this.hasMore,
  });

  factory OrderListResponse.fromJson(Map<String, dynamic> json) {
    return OrderListResponse(
      orders: (json['orders'] as List<dynamic>?)
              ?.map((o) => OrderModel.fromJson(o as Map<String, dynamic>))
              .toList() ??
          [],
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      limit: json['limit'] as int? ?? 20,
      hasMore: json['hasMore'] as bool? ?? false,
    );
  }
}

/// Request model for creating an order
class CreateOrderRequest {
  final String deliveryType; // delivery, pickup
  final AddressModel? deliveryAddress;
  final String paymentMethod;
  final String? customerNotes;
  final String? couponCode;
  final String? cardTokenId; // Mercado Pago card token
  final int? installments; // Parcelas

  const CreateOrderRequest({
    required this.deliveryType,
    this.deliveryAddress,
    required this.paymentMethod,
    this.customerNotes,
    this.couponCode,
    this.cardTokenId,
    this.installments,
  });

  Map<String, dynamic> toJson() {
    return {
      'deliveryType': deliveryType,
      if (deliveryAddress != null) 'deliveryAddress': deliveryAddress!.toJson(),
      'paymentMethod': paymentMethod,
      if (customerNotes != null) 'customerNotes': customerNotes,
      if (couponCode != null) 'couponCode': couponCode,
      if (cardTokenId != null) 'cardTokenId': cardTokenId,
      if (installments != null) 'installments': installments,
    };
  }
}
