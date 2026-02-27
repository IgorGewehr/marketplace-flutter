import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/notification_model.dart';
import 'auth_providers.dart';
import 'core_providers.dart';

/// Serialize Firestore Timestamps to ISO-8601 strings so NotificationModel.fromJson works.
Map<String, dynamic> _serializeFirestoreNotification(Map<String, dynamic> data) {
  final result = <String, dynamic>{};
  for (final entry in data.entries) {
    result[entry.key] = _serializeValue(entry.value);
  }
  return result;
}

dynamic _serializeValue(dynamic value) {
  if (value is Timestamp) {
    return value.toDate().toIso8601String();
  } else if (value is Map<String, dynamic>) {
    return _serializeFirestoreNotification(value);
  } else if (value is Map) {
    return _serializeFirestoreNotification(Map<String, dynamic>.from(value));
  } else if (value is List) {
    return value.map(_serializeValue).toList();
  }
  return value;
}

/// Notifications provider
class NotificationsNotifier extends AsyncNotifier<List<NotificationModel>> {
  StreamSubscription<QuerySnapshot>? _firestoreSubscription;

  @override
  Future<List<NotificationModel>> build() async {
    final user = ref.watch(currentUserProvider).valueOrNull;

    // Set up Firestore real-time listener when user is logged in
    if (user != null) {
      _setupRealtimeListener(user.id);
    }

    // Clean up subscription on dispose
    ref.onDispose(() {
      _firestoreSubscription?.cancel();
    });

    // Initial load via REST API
    return _fetchNotifications();
  }

  /// Listen to the notifications Firestore collection for the current user.
  /// New/updated docs are merged into state on top of any REST-loaded data.
  void _setupRealtimeListener(String userId) {
    _firestoreSubscription?.cancel();
    _firestoreSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen(
      (snapshot) {
        if (snapshot.docs.isEmpty) return;

        final firestoreNotifs = snapshot.docs
            .map((doc) {
              try {
                final data = _serializeFirestoreNotification(doc.data());
                // Ensure the document id is present
                if (!data.containsKey('id') || (data['id'] as String?)?.isEmpty == true) {
                  data['id'] = doc.id;
                }
                return NotificationModel.fromJson(data);
              } catch (_) {
                return null;
              }
            })
            .whereType<NotificationModel>()
            .toList();

        // Merge with existing state: Firestore wins on conflicts (same id)
        final current = state.valueOrNull ?? [];
        final currentMap = {for (final n in current) n.id: n};
        for (final n in firestoreNotifs) {
          currentMap[n.id] = n;
        }

        // Sort by createdAt descending
        final merged = currentMap.values.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        state = AsyncValue.data(merged);
      },
      onError: (_) {
        // Silent fail — REST data remains available
      },
    );
  }

  Future<List<NotificationModel>> _fetchNotifications() async {
    final repo = ref.read(notificationRepositoryProvider);
    final response = await repo.getNotifications();
    return response.notifications;
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

  Future<void> deleteNotification(String id) async {
    // Optimistic update: remove from list immediately
    state = AsyncValue.data(
      state.valueOrNull?.where((n) => n.id != id).toList() ?? [],
    );
    try {
      final repo = ref.read(notificationRepositoryProvider);
      await repo.delete(id);
    } catch (_) {
      // Revert on failure
      ref.invalidateSelf();
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
    // Load synchronously from Hive (Hive reads are sync)
    try {
      final storage = ref.read(localStorageProvider);
      final orders = storage.getBool('notif_orders') ?? true;
      final chat = storage.getBool('notif_chat') ?? true;
      final promos = storage.getBool('notif_promotions') ?? true;
      final payments = storage.getBool('notif_payments') ?? true;
      return NotificationSettingsState(
        ordersEnabled: orders,
        chatEnabled: chat,
        promotionsEnabled: promos,
        paymentsEnabled: payments,
      );
    } catch (_) {
      return const NotificationSettingsState();
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

    // Sync with backend — capture values before async gap
    final prefs = {
      'orders': state.ordersEnabled,
      'chat': state.chatEnabled,
      'promotions': state.promotionsEnabled,
      'payments': state.paymentsEnabled,
    };
    _syncWithBackend(prefs);
  }

  Future<void> _syncWithBackend(Map<String, bool> prefs) async {
    try {
      final repo = ref.read(notificationRepositoryProvider);
      await repo.updatePreferences(prefs);
    } catch (_) {
      // Best-effort sync - local storage is the source of truth
    }
  }
}

final notificationSettingsProvider = NotifierProvider<NotificationSettingsNotifier, NotificationSettingsState>(
  () => NotificationSettingsNotifier(),
);
