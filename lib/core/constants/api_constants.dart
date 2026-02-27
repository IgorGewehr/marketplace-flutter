/// API Constants for Compre Aqui
/// Contains all endpoint definitions matching the next-erp backend routes
library;

import '../config/app_config.dart';

class ApiConstants {
  ApiConstants._();

  // Base URL - loaded from environment configuration
  static String get baseUrl => AppConfig.apiBaseUrl;

  // === Auth Endpoints ===
  static const String authRegister = '/api/auth/register';
  static const String authCompleteProfile = '/api/auth/complete-profile';
  static const String authBecomeSeller = '/api/auth/become-seller';
  static const String authMe = '/api/auth/me';

  // === Marketplace Endpoints ===
  static const String marketplaceProducts = '/api/marketplace/products';
  static const String marketplaceProductsFeatured = '/api/marketplace/products/featured';
  static const String marketplaceProductsRecent = '/api/marketplace/products/recent';
  static String marketplaceProductById(String id) => '/api/marketplace/products/$id';
  static const String marketplaceCategories = '/api/marketplace/categories';
  static const String marketplaceSearch = '/api/marketplace/search';
  static const String marketplaceBanners = '/api/marketplace/banners';

  // Marketplace Services
  static const String marketplaceServices = '/api/marketplace/services';
  static const String marketplaceServicesFeatured = '/api/marketplace/services/featured';
  static const String marketplaceServicesRecent = '/api/marketplace/services/recent';
  static String marketplaceServiceById(String id) => '/api/marketplace/services/$id';
  static const String marketplaceServiceCategories = '/api/marketplace/service-categories';
  static const String marketplaceServicesSearch = '/api/marketplace/services/search';

  // === Cart Endpoints ===
  static const String cart = '/api/cart';
  static const String cartItems = '/api/cart/items';
  static String cartItemById(String id) => '/api/cart/items/$id';

  // === Orders Endpoints ===
  static const String orders = '/api/orders';
  static String orderById(String id) => '/api/orders/$id';
  static String orderStatus(String id) => '/api/orders/$id/status';
  static String orderDispute(String id) => '/api/orders/$id/dispute';

  // === Payments Endpoints ===
  static const String paymentsCheckout = '/api/payments/checkout';
  static String paymentStatus(String orderId) => '/api/payments/$orderId/status';

  // === Seller Endpoints ===
  static const String sellerOrders = '/api/seller/orders';
  static const String sellerProfile = '/api/seller/profile';
  static const String sellerSummary = '/api/seller/summary';
  static const String products = '/api/products';
  static String productById(String id) => '/api/products/$id';

  // Seller Services
  static const String sellerServices = '/api/services';
  static String sellerServiceById(String id) => '/api/services/$id';
  static String sellerServiceImageById(String serviceId, String imageId) =>
      '/api/services/$serviceId/images/$imageId';

  // === Wallet Endpoints ===
  static const String wallet = '/api/wallet';
  static const String walletTransactions = '/api/wallet/transactions';
  static const String walletWithdraw = '/api/wallet/withdraw';

  // === Address Endpoints ===
  static const String addresses = '/api/addresses';
  static String addressById(String id) => '/api/addresses/$id';
  static String addressSetDefault(String id) => '/api/addresses/$id/default';

  // === Seller Tracking ===
  static String sellerOrderTracking(String orderId) => '/api/seller/orders/$orderId/tracking';

  // === Chat Endpoints ===
  static const String chats = '/api/chats';
  static String chatById(String id) => '/api/chats/$id';
  static String chatMessages(String id) => '/api/chats/$id/messages';
  static String chatReport(String id) => '/api/chats/$id/report';

  // === Notifications Endpoints ===
  static const String notifications = '/api/notifications';
  static String notificationById(String id) => '/api/notifications/$id';
  static const String notificationsMarkAllRead = '/api/notifications/mark-all-read';
  static const String notificationPreferences = '/api/notifications/preferences';

  // === User Public Profile ===
  static String userPublic(String id) => '/api/users/$id/public';

  // === Tenant Endpoints ===
  static const String tenants = '/api/marketplace/tenants';
  static String tenantById(String id) => '/api/marketplace/tenants/$id';

  // === Delivery Endpoints ===
  static const String deliveryConfirm = '/api/delivery/confirm';
  static String deliveryQr(String orderId) => '/api/delivery/qr/$orderId';

  // === Payment Link ===
  static const String paymentLink = '/api/payments/link';

  // === Reviews Endpoints ===
  static const String reviews = '/api/reviews';
  static const String reviewsCheck = '/api/reviews/check';
  static const String marketplaceReviews = '/api/marketplace/reviews';

  // === Mercado Pago Endpoints ===
  static const String mpOAuthUrl = '/api/mercadopago/oauth';
  static const String mpOAuthCallback = '/api/mercadopago/oauth';
  static const String mpOAuthStatus = '/api/mercadopago/oauth';
  static const String mpOAuthDisconnect = '/api/mercadopago/oauth';
  static const String mpPublicKey = '/api/mercadopago/public-key';

  // === Timeouts ===
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 60);
  static const Duration sendTimeout = Duration(seconds: 30);
}
