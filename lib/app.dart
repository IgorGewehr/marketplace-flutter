import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/services/push_notification_service.dart';
import 'core/theme/app_theme.dart';
import 'presentation/providers/auth_providers.dart';

/// Compre Aqui App
class ReiDoBriqueApp extends ConsumerStatefulWidget {
  const ReiDoBriqueApp({super.key});

  @override
  ConsumerState<ReiDoBriqueApp> createState() => _ReiDoBriqueAppState();
}

class _ReiDoBriqueAppState extends ConsumerState<ReiDoBriqueApp> {
  bool _fcmInitialized = false;

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final authStatus = ref.watch(authStatusProvider);

    // Initialize push notifications when user becomes authenticated
    if (authStatus == AuthStatus.authenticated && !_fcmInitialized) {
      _fcmInitialized = true;
      Future.microtask(() {
        ref.read(pushNotificationServiceProvider).initialize();
      });
    } else if (authStatus == AuthStatus.unauthenticated && _fcmInitialized) {
      _fcmInitialized = false;
    }

    return MaterialApp.router(
      title: 'Compre Aqui',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      themeMode: ThemeMode.light,
      routerConfig: router,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
