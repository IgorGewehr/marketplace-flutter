import '../../data/models/notification_model.dart';

/// Notification Repository Interface
abstract class NotificationRepository {
  /// Get paginated list of notifications
  Future<NotificationListResponse> getNotifications({
    int page = 1,
    int limit = 20,
    bool? unreadOnly,
  });

  /// Mark single notification as read
  Future<void> markAsRead(String notificationId);

  /// Mark all notifications as read
  Future<void> markAllAsRead();

  /// Get unread count
  Future<int> getUnreadCount();

  /// Delete notification
  Future<void> delete(String notificationId);

  /// Delete all notifications
  Future<void> deleteAll();

  /// Sync notification preferences with backend
  Future<void> updatePreferences(Map<String, bool> preferences);
}

/// Response wrapper for paginated notification lists
class NotificationListResponse {
  final List<NotificationModel> notifications;
  final int total;
  final int page;
  final int limit;
  final bool hasMore;
  final int unreadCount;

  const NotificationListResponse({
    required this.notifications,
    required this.total,
    required this.page,
    required this.limit,
    required this.hasMore,
    required this.unreadCount,
  });

  factory NotificationListResponse.fromJson(Map<String, dynamic> json) {
    return NotificationListResponse(
      notifications: (json['notifications'] as List<dynamic>?)
              ?.map((n) => NotificationModel.fromJson(n as Map<String, dynamic>))
              .toList() ??
          [],
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      limit: json['limit'] as int? ?? 20,
      hasMore: json['hasMore'] as bool? ?? false,
      unreadCount: json['unreadCount'] as int? ?? 0,
    );
  }
}
