import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/notification_model.dart';
import 'core_providers.dart';

/// Notifications provider
class NotificationsNotifier extends AsyncNotifier<List<NotificationModel>> {
  @override
  Future<List<NotificationModel>> build() async {
    return _fetchNotifications();
  }

  Future<List<NotificationModel>> _fetchNotifications() async {
    try {
      final repo = ref.read(notificationRepositoryProvider);
      final response = await repo.getNotifications();
      return response.notifications;
    } catch (e) {
      // Return empty list on error (e.g. not authenticated)
      return [];
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _fetchNotifications());
  }

  Future<void> markAsRead(String notificationId) async {
    final notifications = state.valueOrNull ?? [];
    final index = notifications.indexWhere((n) => n.id == notificationId);
    if (index == -1) return;

    // Optimistic update
    final updated = notifications[index].copyWith(
      isRead: true,
      readAt: DateTime.now(),
    );

    final newList = [...notifications];
    newList[index] = updated;
    state = AsyncValue.data(newList);

    // Persist to backend
    try {
      final repo = ref.read(notificationRepositoryProvider);
      await repo.markAsRead(notificationId);
    } catch (_) {
      // Revert on failure
      state = AsyncValue.data(notifications);
    }
  }

  Future<void> markAllAsRead() async {
    final notifications = state.valueOrNull ?? [];
    final now = DateTime.now();

    // Optimistic update
    final updated = notifications.map((n) {
      if (!n.isRead) {
        return n.copyWith(isRead: true, readAt: now);
      }
      return n;
    }).toList();

    state = AsyncValue.data(updated);

    // Persist to backend
    try {
      final repo = ref.read(notificationRepositoryProvider);
      await repo.markAllAsRead();
    } catch (_) {
      // Revert on failure
      state = AsyncValue.data(notifications);
    }
  }

  void addNotification(NotificationModel notification) {
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data([notification, ...current]);
  }
}

final notificationsProvider = AsyncNotifierProvider<NotificationsNotifier, List<NotificationModel>>(
  () => NotificationsNotifier(),
);

/// Unread notifications count for badge
final unreadNotificationsCountProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationsProvider).valueOrNull ?? [];
  return notifications.where((n) => !n.isRead).length;
});

/// Notification settings provider
class NotificationSettingsState {
  final bool ordersEnabled;
  final bool chatEnabled;
  final bool promotionsEnabled;
  final bool paymentsEnabled;

  const NotificationSettingsState({
    this.ordersEnabled = true,
    this.chatEnabled = true,
    this.promotionsEnabled = true,
    this.paymentsEnabled = true,
  });

  NotificationSettingsState copyWith({
    bool? ordersEnabled,
    bool? chatEnabled,
    bool? promotionsEnabled,
    bool? paymentsEnabled,
  }) {
    return NotificationSettingsState(
      ordersEnabled: ordersEnabled ?? this.ordersEnabled,
      chatEnabled: chatEnabled ?? this.chatEnabled,
      promotionsEnabled: promotionsEnabled ?? this.promotionsEnabled,
      paymentsEnabled: paymentsEnabled ?? this.paymentsEnabled,
    );
  }
}

class NotificationSettingsNotifier extends Notifier<NotificationSettingsState> {
  @override
  NotificationSettingsState build() {
    _loadFromStorage();
    return const NotificationSettingsState();
  }

  Future<void> _loadFromStorage() async {
    try {
      final storage = ref.read(localStorageProvider);
      final orders = storage.getBool('notif_orders') ?? true;
      final chat = storage.getBool('notif_chat') ?? true;
      final promos = storage.getBool('notif_promotions') ?? true;
      final payments = storage.getBool('notif_payments') ?? true;
      state = NotificationSettingsState(
        ordersEnabled: orders,
        chatEnabled: chat,
        promotionsEnabled: promos,
        paymentsEnabled: payments,
      );
    } catch (_) {
      // Use defaults on error
    }
  }

  void toggleOrders(bool value) {
    state = state.copyWith(ordersEnabled: value);
    _save();
  }

  void toggleChat(bool value) {
    state = state.copyWith(chatEnabled: value);
    _save();
  }

  void togglePromotions(bool value) {
    state = state.copyWith(promotionsEnabled: value);
    _save();
  }

  void togglePayments(bool value) {
    state = state.copyWith(paymentsEnabled: value);
    _save();
  }

  void _save() {
    try {
      final storage = ref.read(localStorageProvider);
      storage.setBool('notif_orders', state.ordersEnabled);
      storage.setBool('notif_chat', state.chatEnabled);
      storage.setBool('notif_promotions', state.promotionsEnabled);
      storage.setBool('notif_payments', state.paymentsEnabled);
    } catch (_) {
      // Silently fail on storage error
    }
  }
}

final notificationSettingsProvider = NotifierProvider<NotificationSettingsNotifier, NotificationSettingsState>(
  () => NotificationSettingsNotifier(),
);
