import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/api_client.dart';
import '../../data/datasources/local_storage_service.dart';
import '../../data/datasources/storage_service.dart';
import '../../main.dart' show localStorageService;
import '../../data/repositories/address_repository_impl.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/repositories/cart_repository_impl.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../data/repositories/notification_repository_impl.dart';
import '../../data/repositories/order_repository_impl.dart';
import '../../data/repositories/product_repository_impl.dart';
import '../../data/repositories/service_repository_impl.dart';
import '../../data/repositories/tenant_repository_impl.dart';
import '../../data/repositories/wallet_repository_impl.dart';
import '../../data/repositories/mercadopago_repository_impl.dart';
import '../../data/repositories/review_repository_impl.dart';
import '../../domain/repositories/address_repository.dart';
import '../../domain/repositories/review_repository.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/cart_repository.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/repositories/mercadopago_repository.dart';
import '../../domain/repositories/notification_repository.dart';
import '../../domain/repositories/order_repository.dart';
import '../../domain/repositories/product_repository.dart';
import '../../domain/repositories/service_repository.dart';
import '../../domain/repositories/tenant_repository.dart';
import '../../domain/repositories/wallet_repository.dart';

/// Local Storage Service Provider (Hive boxes - opened at startup)
final localStorageProvider = Provider<LocalStorageService>((ref) {
  return localStorageService;
});

/// Gap #25: Proper state provider for biometric setting
final biometricEnabledProvider = StateProvider<bool>((ref) {
  final localStorage = ref.read(localStorageProvider);
  return localStorage.getBool('biometric_enabled') ?? false;
});

/// API Client Provider
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(localStorage: ref.read(localStorageProvider));
});

/// Firebase Auth Provider
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

/// Storage Service Provider
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

/// Address Repository Provider
final addressRepositoryProvider = Provider<AddressRepository>((ref) {
  return AddressRepositoryImpl(
    apiClient: ref.watch(apiClientProvider),
  );
});

/// Auth Repository Provider
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    apiClient: ref.watch(apiClientProvider),
    firebaseAuth: ref.watch(firebaseAuthProvider),
  );
});

/// Product Repository Provider
final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepositoryImpl(
    apiClient: ref.watch(apiClientProvider),
  );
});

/// Service Repository Provider
final serviceRepositoryProvider = Provider<ServiceRepository>((ref) {
  return ServiceRepositoryImpl(
    apiClient: ref.watch(apiClientProvider),
    storageService: ref.watch(storageServiceProvider),
  );
});

/// Cart Repository Provider
final cartRepositoryProvider = Provider<CartRepository>((ref) {
  return CartRepositoryImpl(
    apiClient: ref.watch(apiClientProvider),
  );
});

/// Order Repository Provider
final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepositoryImpl(
    apiClient: ref.watch(apiClientProvider),
  );
});

/// Wallet Repository Provider
final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepositoryImpl(
    apiClient: ref.watch(apiClientProvider),
  );
});

/// Chat Repository Provider
final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepositoryImpl(
    apiClient: ref.watch(apiClientProvider),
  );
});

/// Notification Repository Provider
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepositoryImpl(
    apiClient: ref.watch(apiClientProvider),
  );
});

/// Tenant Repository Provider
final tenantRepositoryProvider = Provider<TenantRepository>((ref) {
  return TenantRepositoryImpl(
    apiClient: ref.watch(apiClientProvider),
  );
});

/// Mercado Pago Repository Provider
final mercadoPagoRepositoryProvider = Provider<MercadoPagoRepository>((ref) {
  return MercadoPagoRepositoryImpl(
    apiClient: ref.watch(apiClientProvider),
  );
});

/// Review Repository Provider
final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return ReviewRepositoryImpl(
    apiClient: ref.watch(apiClientProvider),
  );
});
