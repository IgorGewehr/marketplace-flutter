/// App-wide constants for Compre Aqui
library;

class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'Compre Aqui';
  static const String appVersion = '2.1.2';

  // User Types
  static const String userTypeBuyer = 'buyer';
  static const String userTypeSeller = 'seller';
  static const String userTypeErpOnly = 'erp_only';
  static const String userTypeFull = 'full';

  // Order Status
  static const String orderStatusPending = 'pending';
  static const String orderStatusConfirmed = 'confirmed';
  static const String orderStatusPreparing = 'preparing';
  static const String orderStatusReady = 'ready';
  static const String orderStatusShipped = 'shipped';
  static const String orderStatusDelivered = 'delivered';
  static const String orderStatusCancelled = 'cancelled';

  // Payment Status
  static const String paymentStatusPending = 'pending';
  static const String paymentStatusPaid = 'paid';
  static const String paymentStatusFailed = 'failed';
  static const String paymentStatusRefunded = 'refunded';

  // Payment Methods
  static const String paymentMethodPix = 'pix';
  static const String paymentMethodCreditCard = 'credit_card';
  static const String paymentMethodDebitCard = 'debit_card';
  static const String paymentMethodCash = 'cash';

  // Delivery Types
  static const String deliveryTypeDelivery = 'delivery';
  static const String deliveryTypePickup = 'pickup';

  // Product Visibility
  static const String visibilityMarketplace = 'marketplace';
  static const String visibilityStore = 'store';
  static const String visibilityBoth = 'both';

  // Transaction Types
  static const String transactionTypeSale = 'sale';
  static const String transactionTypeRefund = 'refund';
  static const String transactionTypeWithdrawal = 'withdrawal';
  static const String transactionTypeFee = 'fee';

  // Notification Types
  static const String notificationTypeOrderCreated = 'order_created';
  static const String notificationTypeOrderStatusChanged = 'order_status_changed';
  static const String notificationTypeNewMessage = 'new_message';
  static const String notificationTypePaymentReceived = 'payment_received';
  static const String notificationTypeWithdrawalCompleted = 'withdrawal_completed';

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Image Upload
  static const int maxImageSizeBytes = 5 * 1024 * 1024; // 5MB
  static const int maxProductImages = 10;
  static const List<String> allowedImageExtensions = ['jpg', 'jpeg', 'png', 'webp'];

  // Cache Keys
  static const String cacheKeyUser = 'cached_user';
  static const String cacheKeyCart = 'cached_cart';
  static const String cacheKeyCategories = 'cached_categories';

  // Cache Duration
  static const Duration cacheDurationShort = Duration(minutes: 5);
  static const Duration cacheDurationMedium = Duration(hours: 1);
  static const Duration cacheDurationLong = Duration(days: 1);

  // Support & Contact
  static const String supportWhatsAppPhone = '5547997856405';
  static const String supportEmail = 'suporte@compreaqui.com.br';

  // External URLs
  static const String helpUrl = 'https://compreaqui.com.br/ajuda';
  static const String termsUrl = 'https://compreaqui.com.br/termos';
  static const String privacyUrl = 'https://compreaqui.com.br/privacidade';
  static const String cookiesUrl = 'https://compreaqui.com.br/cookies';
}
