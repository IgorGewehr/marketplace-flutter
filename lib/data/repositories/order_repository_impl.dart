import '../../core/constants/api_constants.dart';
import '../../domain/repositories/order_repository.dart';
import '../datasources/api_client.dart';
import '../models/order_model.dart';

/// Order Repository Implementation
class OrderRepositoryImpl implements OrderRepository {
  final ApiClient _apiClient;

  OrderRepositoryImpl({required ApiClient apiClient}) : _apiClient = apiClient;

  @override
  Future<OrderModel> create(CreateOrderRequest request) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiConstants.orders,
      data: request.toJson(),
    );

    return OrderModel.fromJson(response);
  }

  @override
  Future<OrderListResponse> getOrders({
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConstants.orders,
      queryParameters: {
        'page': page,
        'limit': limit,
        if (status != null) 'status': status,
      },
    );

    return OrderListResponse.fromJson(response);
  }

  @override
  Future<OrderModel> getById(String id) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConstants.orderById(id),
    );

    return OrderModel.fromJson(response);
  }

  @override
  Future<OrderListResponse> getSellerOrders({
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConstants.sellerOrders,
      queryParameters: {
        'page': page,
        'limit': limit,
        if (status != null) 'status': status,
      },
    );

    return OrderListResponse.fromJson(response);
  }

  @override
  Future<OrderModel> updateStatus({
    required String orderId,
    required String status,
    String? note,
  }) async {
    final response = await _apiClient.patch<Map<String, dynamic>>(
      ApiConstants.orderStatus(orderId),
      data: {
        'status': status,
        if (note != null) 'note': note,
      },
    );

    return OrderModel.fromJson(response);
  }

  @override
  Future<OrderModel> cancel(String orderId, {String? reason}) async {
    return updateStatus(
      orderId: orderId,
      status: 'cancelled',
      note: reason,
    );
  }

  @override
  Future<String?> getOrderChatId(String orderId) async {
    final order = await getById(orderId);
    return order.chatId;
  }
}
