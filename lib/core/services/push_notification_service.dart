import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presentation/providers/core_providers.dart';
import '../../presentation/providers/notifications_provider.dart';

/// Handles FCM push notification setup, token management, and message routing.
class PushNotificationService {
  final Ref _ref;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  String? _currentToken;

  PushNotificationService(this._ref);

  /// Initialize FCM: request permissions, get token, set up listeners.
  Future<void> initialize() async {
    // Request notification permission (required for Android 13+ and iOS)
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('PushNotificationService: Notification permission denied');
      return;
    }

    // Get and register FCM token
    await _registerToken();

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      _registerToken(token: newToken);
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification tap when app is in background/terminated
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check if app was opened from a terminated state via notification
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    // Show notifications as heads-up while app is in foreground
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  /// Get and register FCM token with the backend.
  Future<void> _registerToken({String? token}) async {
    try {
      final fcmToken = token ?? await _messaging.getToken();
      if (fcmToken == null) return;

      _currentToken = fcmToken;
      debugPrint('PushNotificationService: FCM token obtained');

      // Send token to backend
      final authRepo = _ref.read(authRepositoryProvider);
      await authRepo.updateFcmToken(fcmToken);
    } catch (e) {
      debugPrint('PushNotificationService: Error registering token: $e');
    }
  }

  /// Handle foreground messages: refresh the notifications list.
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('PushNotificationService: Foreground message: ${message.data}');

    // Refresh the in-app notifications list
    try {
      _ref.read(notificationsProvider.notifier).refresh();
    } catch (_) {}
  }

  /// Handle notification tap: navigate to the relevant screen.
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('PushNotificationService: Notification tapped: ${message.data}');

    // Refresh notifications
    try {
      _ref.read(notificationsProvider.notifier).refresh();
    } catch (_) {}

    // Navigation is handled via the notification screen when the user taps
    // an in-app notification tile. The push notification tap just brings
    // the user back to the app and refreshes the data.
  }

  /// Remove FCM token on sign out.
  Future<void> removeToken() async {
    if (_currentToken == null) return;

    try {
      final authRepo = _ref.read(authRepositoryProvider);
      await authRepo.removeFcmToken(_currentToken!);
      _currentToken = null;
    } catch (e) {
      debugPrint('PushNotificationService: Error removing token: $e');
    }
  }
}

/// Provider for push notification service
final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService(ref);
});
