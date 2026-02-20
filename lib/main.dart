import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app.dart'; // Compre Aqui - Marketplace do Meio Oeste
import 'core/config/app_config.dart';
import 'data/datasources/local_storage_service.dart';
import 'presentation/providers/seller_mode_provider.dart';

/// Global instance initialized at startup, provided via Riverpod.
final localStorageService = LocalStorageService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment configuration
  // Use 'prod' for production builds
  await AppConfig.load(environment: 'prod');

  // Initialize Hive for local storage
  await Hive.initFlutter();

  // Open all Hive boxes once
  await localStorageService.init();

  // Initialize Firebase
  await Firebase.initializeApp();

  AppConfig.logger.i('Compre Aqui app starting...');

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Load seller mode before app starts so router navigates correctly
  final isSellerMode = await SellerModeNotifier.loadInitialValue();

  runApp(
    ProviderScope(
      overrides: [
        sellerModeInitialValueProvider.overrideWith((_) => isSellerMode),
      ],
      child: const CompreAquiApp(),
    ),
  );
}
