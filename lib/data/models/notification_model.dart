/// Notification model matching SCHEMA.md
library;

import '../../core/utils/firestore_utils.dart';

class NotificationModel {
  final String id;
  final String userId;
  final String type; // order_created, order_status_changed, new_message, payment_received, withdrawal_completed
  final String title;
  final String body;
  final String? actionUrl;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime? readAt;
  final bool pushSent;
  final DateTime? pushSentAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.actionUrl,
    this.data,
    this.isRead = false,
    this.readAt,
    this.pushSent = false,
    this.pushSentAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Check if notification is unread
  bool get isUnread => !isRead;

  /// Check if notification is order related
  bool get isOrderRelated => type.startsWith('order_');

  /// Check if notification is message related
  bool get isMessageRelated => type == 'new_message';

  /// Check if notification is payment related
  bool get isPaymentRelated => type == 'payment_received' || type == 'withdrawal_completed';

  /// Get order ID from data if available
  String? get orderId => data?['orderId'] as String?;

  /// Get chat ID from data if available
  String? get chatId => data?['chatId'] as String?;

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      actionUrl: json['actionUrl'] as String?,
      data: json['data'] as Map<String, dynamic>?,
      isRead: json['isRead'] as bool? ?? false,
      readAt: parseFirestoreDate(json['readAt']),
      pushSent: json['pushSent'] as bool? ?? false,
      pushSentAt: parseFirestoreDate(json['pushSentAt']),
      createdAt: parseFirestoreDate(json['createdAt']) ?? DateTime.now(),
      updatedAt: parseFirestoreDate(json['updatedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'type': type,
      'title': title,
      'body': body,
      if (actionUrl != null) 'actionUrl': actionUrl,
      if (data != null) 'data': data,
      'isRead': isRead,
      if (readAt != null) 'readAt': readAt!.toIso8601String(),
      'pushSent': pushSent,
      if (pushSentAt != null) 'pushSentAt': pushSentAt!.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? type,
    String? title,
    String? body,
    String? actionUrl,
    Map<String, dynamic>? data,
    bool? isRead,
    DateTime? readAt,
    bool? pushSent,
    DateTime? pushSentAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      actionUrl: actionUrl ?? this.actionUrl,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      pushSent: pushSent ?? this.pushSent,
      pushSentAt: pushSentAt ?? this.pushSentAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
