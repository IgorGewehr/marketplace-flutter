import '../../core/constants/api_constants.dart';
import '../../domain/repositories/notification_repository.dart';
import '../datasources/api_client.dart';
import '../models/notification_model.dart';

/// Notification Repository Implementation
class NotificationRepositoryImpl implements NotificationRepository {
  final ApiClient _apiClient;

  NotificationRepositoryImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  @override
  Future<NotificationListResponse> getNotifications({
    int page = 1,
    int limit = 20,
    bool? unreadOnly,
  }) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConstants.notifications,
      queryParameters: {
        'page': page,
        'limit': limit,
        if (unreadOnly == true) 'unreadOnly': true,
      },
    );

    return NotificationListResponse.fromJson(response);
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    await _apiClient.patch<void>(
      ApiConstants.notificationById(notificationId),
      data: {'isRead': true},
    );
  }

  @override
  Future<void> markAllAsRead() async {
    await _apiClient.post<void>(ApiConstants.notificationsMarkAllRead);
  }

  @override
  Future<int> getUnreadCount() async {
    final response = await getNotifications(page: 1, limit: 1);
    return response.unreadCount;
  }

  @override
  Future<void> delete(String notificationId) async {
    await _apiClient.delete<void>(
      ApiConstants.notificationById(notificationId),
    );
  }

  @override
  Future<void> deleteAll() async {
    await _apiClient.delete<void>(ApiConstants.notifications);
  }
}
