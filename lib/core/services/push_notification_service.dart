import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../router/app_router.dart';
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
      // Permission denied — notifications won't work
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
      // Token obtained successfully

      // Send token to backend
      final authRepo = _ref.read(authRepositoryProvider);
      await authRepo.updateFcmToken(fcmToken);
    } catch (e) {
      // Token registration failed
    }
  }

  /// Handle foreground messages: refresh the notifications list.
  void _handleForegroundMessage(RemoteMessage message) {
    // Foreground message received — refresh notifications

    // Refresh the in-app notifications list
    try {
      _ref.read(notificationsProvider.notifier).refresh();
    } catch (_) {}
  }

  /// Handle notification tap: navigate to the relevant screen.
  /// Gap #13: Route to the correct screen based on notification data.
  void _handleNotificationTap(RemoteMessage message) {
    // Notification tapped — navigate to relevant screen

    // Refresh notifications
    try {
      _ref.read(notificationsProvider.notifier).refresh();
    } catch (_) {}

    // Navigate based on notification data
    final data = message.data;
    final type = data['type'] as String?;
    final rawId = data['id'] as String?;

    // Sanitize ID: only allow alphanumeric, hyphens, and underscores
    final id = rawId != null && RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(rawId)
        ? rawId
        : null;

    try {
      final router = _ref.read(routerProvider);
      switch (type) {
        case 'order':
          if (id != null) router.push('/orders/$id');
          break;
        case 'seller_order':
          if (id != null) router.push('/seller/orders/$id');
          break;
        case 'chat':
          if (id != null) router.push('/chats/$id');
          break;
        case 'product':
          if (id != null) router.push('/product/$id');
          break;
        case 'delivery_confirmation':
          if (id != null) router.push('/orders/$id');
          break;
        case 'payment_released':
          router.push(AppRouter.sellerWallet);
          break;
        case 'review':
          if (id != null) router.push('/product/$id');
          break;
        default:
          router.push(AppRouter.notifications);
      }
    } catch (e) {
      // Navigation error — silently handled
    }
  }

  /// Remove FCM token on sign out.
  Future<void> removeToken() async {
    if (_currentToken == null) return;

    try {
      final authRepo = _ref.read(authRepositoryProvider);
      await authRepo.removeFcmToken(_currentToken!);
      _currentToken = null;
    } catch (e) {
      // Token removal failed
    }
  }
}

/// Provider for push notification service
final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService(ref);
});
