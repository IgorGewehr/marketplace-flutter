import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/constants/api_constants.dart';
import '../../core/services/push_notification_service.dart';
import '../../data/models/user_model.dart';
import 'address_provider.dart';
import 'cart_provider.dart';
import 'chat_provider.dart';
import 'core_providers.dart';
import 'follows_provider.dart';
import 'mercadopago_provider.dart';
import 'my_products_provider.dart';
import 'my_services_provider.dart';
import 'notifications_provider.dart';
import 'orders_provider.dart';
import 'products_provider.dart';
import 'seller_mode_provider.dart';
import 'seller_orders_provider.dart';
import 'wallet_provider.dart';

/// Auth Status enum for router and UI
enum AuthStatus {
  loading,
  unauthenticated,
  authenticated,
  needsProfile,
}

/// Auth State Provider - Listens to Firebase auth state changes
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

/// Current Firebase User Provider
final currentFirebaseUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).valueOrNull;
});

/// Is Authenticated Provider
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(currentFirebaseUserProvider) != null;
});

/// Current User Provider - Fetches user data from backend
final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final firebaseUser = ref.watch(currentFirebaseUserProvider);

  if (firebaseUser == null) {
    return null;
  }

  try {
    final authRepository = ref.read(authRepositoryProvider);
    return await authRepository.getCurrentUser();
  } catch (e) {
    // User might not exist in backend yet (just signed up)
    return null;
  }
});

/// User Async Value Provider (for UI convenience)
final userAsyncProvider = Provider<AsyncValue<UserModel?>>((ref) {
  return ref.watch(currentUserProvider);
});

/// Auth Status Provider - Combines auth state and profile completion
final authStatusProvider = Provider<AuthStatus>((ref) {
  final authState = ref.watch(authStateProvider);
  final userAsync = ref.watch(currentUserProvider);

  return authState.when(
    loading: () => AuthStatus.loading,
    error: (_, _) => AuthStatus.unauthenticated,
    data: (firebaseUser) {
      if (firebaseUser == null) {
        return AuthStatus.unauthenticated;
      }

      // Use valueOrNull so that reloads (e.g. after becomeSeller) don't flash
      // the loading state and trigger an unnecessary router redirect to /splash.
      // Only return loading when there is genuinely no value yet (initial fetch).
      final user = userAsync.valueOrNull;
      if (user == null) {
        if (userAsync.isLoading) return AuthStatus.loading;
        return AuthStatus.needsProfile;
      }
      if (!user.hasCompletedProfile) return AuthStatus.needsProfile;
      return AuthStatus.authenticated;
    },
  );
});

/// Is Seller Provider
final isSellerProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  return user?.isSeller ?? false;
});

/// Is Buyer Provider
final isBuyerProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  return user?.isBuyer ?? false;
});

/// GoogleSignIn instance provider
final googleSignInProvider = Provider<GoogleSignIn>((ref) {
  return GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId:
        '474436537260-pgo7o50mn8c288l24vilvm8eg0njlefo.apps.googleusercontent.com',
  );
});

/// Auth State Notifier for Auth Actions
class AuthNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  FirebaseAuth get _auth => ref.read(firebaseAuthProvider);
  GoogleSignIn get _googleSignIn => ref.read(googleSignInProvider);

  /// Sign in with email and password
  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    });
    return !state.hasError;
  }

  /// Sign in with Google
  Future<bool> signInWithGoogle() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw Exception('Login com Google cancelado');
      }

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      // Register with backend (idempotent — backend handles existing users)
      try {
        await ref.read(authRepositoryProvider).register(
              email: userCredential.user!.email!,
              password: '',
              displayName: userCredential.user!.displayName ?? '',
            );
      } catch (_) {
        // User may already exist in backend — that's fine
      }

      ref.invalidate(currentUserProvider);
    });
    return !state.hasError;
  }

  /// Register with email and password
  Future<bool> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).register(
            email: email,
            password: password,
            displayName: displayName,
          );
    });
    return !state.hasError;
  }

  /// Reset password
  Future<bool> resetPassword({required String email}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _auth.sendPasswordResetEmail(email: email);
    });
    return !state.hasError;
  }

  /// Sign out
  Future<void> signOut() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      // Remove FCM token before signing out
      try {
        await ref.read(pushNotificationServiceProvider).removeToken();
      } catch (_) {}

      // Sign out from Google if signed in
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      await ref.read(authRepositoryProvider).signOut();

      // Invalidate all user-specific cached providers to prevent stale data
      // from leaking into the next session.
      _invalidateUserProviders();
    });
  }

  /// Complete user profile
  Future<bool> completeProfile({
    required String fullName,
    required String phone,
    required String cpfCnpj,
    DateTime? birthDate,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).completeProfile(
            phone: phone,
            cpfCnpj: cpfCnpj,
            birthDate: birthDate,
          );
      // Refresh user data
      ref.invalidate(currentUserProvider);
    });
    return !state.hasError;
  }

  /// Become a seller
  Future<bool> becomeSeller({
    required String tradeName,
    required String documentNumber,
    required String documentType,
    String? phone,
    String? whatsapp,
    String? address,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).becomeSeller(
            tradeName: tradeName,
            documentNumber: documentNumber,
            documentType: documentType,
            phone: phone,
            whatsapp: whatsapp,
            address: address,
          );
      // Refresh user data
      ref.invalidate(currentUserProvider);
    });
    return !state.hasError;
  }

  /// Delete the current user's account permanently
  Future<bool> deleteAccount() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      try {
        await ref.read(pushNotificationServiceProvider).removeToken();
      } catch (_) {}

      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      await ref.read(authRepositoryProvider).deleteAccount();

      // Invalidate all user-specific cached providers to prevent stale data
      // from leaking into the next session.
      _invalidateUserProviders();
    });
    return !state.hasError;
  }

  /// Invalidate all user-specific providers so no stale data persists
  /// across sign-out / account deletion boundaries.
  void _invalidateUserProviders() {
    // Auth & user profile
    ref.invalidate(currentUserProvider);

    // Orders (buyer + seller)
    ref.invalidate(ordersProvider);
    ref.invalidate(sellerOrdersProvider);

    // Wallet
    ref.invalidate(walletProvider);
    ref.invalidate(walletTransactionsProvider);

    // MercadoPago connection
    ref.invalidate(mpConnectionProvider);

    // Chat & notifications
    ref.invalidate(chatsProvider);
    ref.invalidate(notificationsProvider);

    // Address book
    ref.invalidate(addressProvider);

    // Cart
    ref.invalidate(cartProvider);

    // Favorites
    ref.invalidate(favoriteProductIdsProvider);

    // Seller products & services
    ref.invalidate(myProductsProvider);
    ref.invalidate(myServicesProvider);

    // Seller mode toggle
    ref.invalidate(sellerModeProvider);

    // Follows (locally persisted set of followed tenant IDs)
    ref.invalidate(followsProvider);
  }

  /// Clear error state
  void clearError() {
    state = const AsyncValue.data(null);
  }
}

final authNotifierProvider =
    NotifierProvider<AuthNotifier, AsyncValue<void>>(AuthNotifier.new);

/// Fetches a public user profile (displayName + photoURL) by ID.
/// Uses the public API endpoint instead of direct Firestore read, because
/// Firestore rules restrict users/{id} to isOwner(userId) only.
final userByIdProvider = FutureProvider.family<UserModel?, String>((ref, userId) async {
  if (userId.isEmpty) return null;
  try {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.get<Map<String, dynamic>>(
      ApiConstants.userPublic(userId),
    );
    return UserModel.fromJson(response);
  } catch (_) {
    return null;
  }
});

/// Helper to get user-friendly error message
String getAuthErrorMessage(Object error) {
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'user-not-found' => 'Usuário não encontrado.',
      'wrong-password' => 'Senha incorreta.',
      'invalid-email' => 'Email inválido.',
      'user-disabled' => 'Esta conta foi desativada.',
      'email-already-in-use' => 'Este email já está em uso.',
      'operation-not-allowed' => 'Operação não permitida.',
      'weak-password' => 'A senha é muito fraca.',
      'invalid-credential' => 'Credenciais inválidas.',
      'too-many-requests' => 'Muitas tentativas. Aguarde um momento.',
      'network-request-failed' => 'Erro de conexão. Verifique sua internet.',
      _ => 'Erro de autenticação. Tente novamente.',
    };
  }
  return 'Erro inesperado. Tente novamente.';
}
