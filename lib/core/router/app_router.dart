import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/providers/auth_providers.dart';
import '../../presentation/screens/splash/splash_screen.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/register_screen.dart';
import '../../presentation/screens/auth/forgot_password_screen.dart';
import '../../presentation/screens/auth/complete_profile_screen.dart';
import '../../presentation/screens/auth/become_seller_screen.dart';
import '../../presentation/screens/shell/buyer_shell.dart';
import '../../presentation/screens/shell/seller_shell.dart';
import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/search/search_screen.dart';
import '../../presentation/screens/search/categories_screen.dart';
import '../../presentation/screens/product/product_details_screen.dart';
import '../../presentation/screens/cart/cart_screen.dart';
import '../../presentation/screens/checkout/checkout_screen.dart';
import '../../presentation/screens/checkout/pix_payment_screen.dart';
import '../../presentation/screens/checkout/order_success_screen.dart';
import '../../presentation/screens/orders/orders_screen.dart';
import '../../presentation/screens/orders/order_details_screen.dart';
import '../../presentation/screens/seller/seller_dashboard_screen.dart';
import '../../presentation/screens/seller/my_products_screen.dart';
import '../../presentation/screens/seller/product_form_screen.dart';
import '../../presentation/screens/seller/seller_orders_screen.dart';
import '../../presentation/screens/seller/seller_order_details_screen.dart';
import '../../presentation/screens/seller/wallet_screen.dart';
import '../../presentation/screens/seller/mp_connect_screen.dart';
import '../../presentation/screens/seller/mp_subscription_screen.dart';
import '../../presentation/screens/chat/chats_list_screen.dart';
import '../../presentation/screens/chat/conversation_screen.dart';
import '../../presentation/screens/notifications/notifications_screen.dart';
import '../../presentation/screens/profile/profile_screen.dart';
import '../../presentation/screens/profile/edit_profile_screen.dart';
import '../../presentation/screens/profile/addresses_screen.dart';
import '../../presentation/screens/settings/settings_screen.dart';
import '../../presentation/screens/settings/notification_settings_screen.dart';
import '../../presentation/screens/favorites/favorites_screen.dart';
import '../../presentation/screens/services/services_screen.dart';
import '../../presentation/screens/services/service_details_screen.dart';

/// App Router configuration with GoRouter
class AppRouter {
  AppRouter._();

  /// Route paths
  static const splash = '/splash';
  static const home = '/';
  static const search = '/search';
  static const productDetails = '/product/:id';
  static const cart = '/cart';
  static const checkout = '/checkout';
  static const pixPayment = '/checkout/pix';
  static const orderSuccess = '/checkout/success';
  static const orders = '/orders';
  static const orderDetails = '/orders/:id';
  static const profile = '/profile';
  static const editProfile = '/profile/edit';
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const completeProfile = '/complete-profile';
  static const becomeSeller = '/become-seller';
  static const sellerDashboard = '/seller';
  static const sellerProducts = '/seller/products';
  static const sellerProductNew = '/seller/products/new';
  static const sellerProductEdit = '/seller/products/:id/edit';
  static const sellerOrders = '/seller/orders';
  static const sellerOrderDetails = '/seller/orders/:id';
  static const sellerWallet = '/seller/wallet';
  static const sellerMpConnect = '/seller/mercadopago/connect';
  static const sellerSubscription = '/seller/subscription';
  static const chats = '/chats';
  static const chatDetails = '/chats/:id';
  static const notifications = '/notifications';
  static const addresses = '/profile/addresses';
  static const settings = '/settings';
  static const notificationSettings = '/settings/notifications';
  static const categories = '/categories';
  static const favorites = '/favorites';
  static const services = '/services';
  static const serviceDetails = '/service/:id';
}

/// Navigator keys for shell routes
final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _buyerShellKey = GlobalKey<NavigatorState>(debugLabel: 'buyerShell');
final _sellerShellKey = GlobalKey<NavigatorState>(debugLabel: 'sellerShell');

/// Router provider — created once, refreshed via refreshListenable
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRouter.splash,
    debugLogDiagnostics: kDebugMode,
    refreshListenable: RouterRefreshStream(ref),
    redirect: (context, state) {
      // Read auth state fresh each time redirect runs
      final authState = ref.read(authStatusProvider);
      final isLoading = authState == AuthStatus.loading;
      final isAuthenticated = authState == AuthStatus.authenticated;
      final needsProfile = authState == AuthStatus.needsProfile;
      final isOnSplash = state.matchedLocation == AppRouter.splash;
      final isOnAuth = _isAuthRoute(state.matchedLocation);
      final isOnCompleteProfile =
          state.matchedLocation == AppRouter.completeProfile;

      // Show splash while loading
      if (isLoading && !isOnSplash) {
        return AppRouter.splash;
      }

      // After loading, redirect from splash
      if (!isLoading && isOnSplash) {
        if (needsProfile) return AppRouter.completeProfile;
        return AppRouter.home;
      }

      // If needs profile completion, redirect there
      if (needsProfile && !isOnCompleteProfile && !isOnAuth) {
        return AppRouter.completeProfile;
      }

      // If on auth routes but already authenticated
      if (isAuthenticated && isOnAuth) {
        return AppRouter.home;
      }

      // Protected routes check
      if (_isProtectedRoute(state.matchedLocation)) {
        if (!isAuthenticated && !needsProfile) {
          return '${AppRouter.login}?redirect=${state.matchedLocation}';
        }
      }

      // Seller routes require seller status
      if (_isSellerRoute(state.matchedLocation)) {
        final user = ref.read(currentUserProvider).valueOrNull;
        if (user == null || !user.isSeller) {
          return AppRouter.becomeSeller;
        }
      }

      return null;
    },
    routes: [
      // Splash
      GoRoute(
        path: AppRouter.splash,
        builder: (context, state) => const SplashScreen(),
      ),

      // Auth Routes
      GoRoute(
        path: AppRouter.login,
        builder: (context, state) {
          final redirect = state.uri.queryParameters['redirect'];
          return LoginScreen(redirectPath: redirect);
        },
      ),
      GoRoute(
        path: AppRouter.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRouter.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRouter.completeProfile,
        builder: (context, state) => const CompleteProfileScreen(),
      ),

      // Seller onboarding
      GoRoute(
        path: AppRouter.becomeSeller,
        builder: (context, state) => const BecomeSellerScreen(),
      ),

      // Buyer shell with bottom navigation
      ShellRoute(
        navigatorKey: _buyerShellKey,
        builder: (context, state, child) => BuyerShell(child: child),
        routes: [
          GoRoute(
            path: AppRouter.home,
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: AppRouter.search,
            builder: (context, state) => const SearchScreen(),
          ),
          GoRoute(
            path: AppRouter.profile,
            builder: (context, state) => const ProfileScreen(),
            routes: [
              GoRoute(
                parentNavigatorKey: _rootNavigatorKey,
                path: 'edit',
                builder: (context, state) => const EditProfileScreen(),
              ),
              GoRoute(
                parentNavigatorKey: _rootNavigatorKey,
                path: 'addresses',
                builder: (context, state) => const AddressesScreen(),
              ),
            ],
          ),
          GoRoute(
            path: AppRouter.chats,
            builder: (context, state) => const ChatsListScreen(),
            routes: [
              GoRoute(
                parentNavigatorKey: _rootNavigatorKey,
                path: ':id',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return ConversationScreen(chatId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: AppRouter.notifications,
            builder: (context, state) => const NotificationsScreen(),
          ),
        ],
      ),

      // Detail routes — top-level so they are reachable from any shell
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRouter.productDetails,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ProductDetailsScreen(productId: id);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRouter.categories,
        builder: (context, state) => const CategoriesScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRouter.favorites,
        builder: (context, state) => const FavoritesScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRouter.services,
        builder: (context, state) => const ServicesScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRouter.serviceDetails,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ServiceDetailsScreen(serviceId: id);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRouter.cart,
        builder: (context, state) => const CartScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRouter.checkout,
        builder: (context, state) => const CheckoutScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRouter.pixPayment,
        builder: (context, state) => const PixPaymentScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRouter.orderSuccess,
        builder: (context, state) => const OrderSuccessScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRouter.orders,
        builder: (context, state) => const OrdersScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRouter.orderDetails,
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return OrderDetailsScreen(orderId: id);
        },
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRouter.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRouter.notificationSettings,
        builder: (context, state) => const NotificationSettingsScreen(),
      ),

      // Seller shell with bottom navigation
      ShellRoute(
        navigatorKey: _sellerShellKey,
        builder: (context, state, child) => SellerShell(child: child),
        routes: [
          GoRoute(
            path: AppRouter.sellerDashboard,
            builder: (context, state) => const SellerDashboardScreen(),
          ),
          GoRoute(
            path: AppRouter.sellerProducts,
            builder: (context, state) => const MyProductsScreen(),
            routes: [
              GoRoute(
                parentNavigatorKey: _rootNavigatorKey,
                path: 'new',
                builder: (context, state) => const ProductFormScreen(),
              ),
              GoRoute(
                parentNavigatorKey: _rootNavigatorKey,
                path: ':id/edit',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return ProductFormScreen(productId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: AppRouter.sellerOrders,
            builder: (context, state) => const SellerOrdersScreen(),
            routes: [
              GoRoute(
                parentNavigatorKey: _rootNavigatorKey,
                path: ':id',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return SellerOrderDetailsScreen(orderId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: AppRouter.sellerWallet,
            builder: (context, state) => const WalletScreen(),
          ),
        ],
      ),

      // Seller detail routes without shell path conflicts
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRouter.sellerMpConnect,
        builder: (context, state) => const MpConnectScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootNavigatorKey,
        path: AppRouter.sellerSubscription,
        builder: (context, state) => const MpSubscriptionScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Página não encontrada'),
            const SizedBox(height: 8),
            Text(state.uri.toString(),
                style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    ),
  );
});

/// Check if route is an auth route
bool _isAuthRoute(String location) {
  return location == AppRouter.login ||
      location == AppRouter.register ||
      location == AppRouter.forgotPassword;
}

/// Check if route requires authentication
bool _isProtectedRoute(String location) {
  return location == AppRouter.cart ||
      location == AppRouter.checkout ||
      location == AppRouter.pixPayment ||
      location == AppRouter.orderSuccess ||
      location == AppRouter.orders ||
      location.startsWith('/orders/') ||
      location == AppRouter.profile ||
      location == AppRouter.editProfile ||
      location == AppRouter.addresses ||
      location == AppRouter.favorites ||
      location == AppRouter.chats ||
      location.startsWith('/chats/') ||
      location == AppRouter.notifications ||
      location == AppRouter.settings ||
      location == AppRouter.notificationSettings ||
      _isSellerRoute(location);
}

/// Check if route requires seller status
bool _isSellerRoute(String location) {
  return location.startsWith('/seller');
}

/// Listenable for router refresh on auth state change
class RouterRefreshStream extends ChangeNotifier {
  RouterRefreshStream(this._ref) {
    _ref.listen(authStatusProvider, (previous, next) {
      notifyListeners();
    });
  }

  final Ref _ref;
}
