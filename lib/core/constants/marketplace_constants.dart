/// Marketplace-specific constants
library;

/// Payment hold duration in hours (24h after delivery confirmation)
const int kPaymentHoldHours = 24;

/// Default platform fee percentage
const double kDefaultPlatformFeePercentage = 10.0;

/// Default search radius in kilometers
const int kDefaultSearchRadiusKm = 10;

/// Maximum search radius in kilometers
const int kMaxSearchRadiusKm = 50;

/// Minimum rating (1-5 stars)
const int kMinRating = 1;

/// Maximum rating (1-5 stars)
const int kMaxRating = 5;

/// Maximum images per review
const int kMaxReviewImages = 5;

/// Maximum images per report
const int kMaxReportEvidenceImages = 10;

/// Minimum helpful count to show review
const int kMinHelpfulCountToHighlight = 5;

/// Maximum report count before auto-hide
const int kMaxReportCountBeforeHide = 10;

/// Ad promotion types
class AdPromotionTypes {
  static const String cityTop = 'city_top';
  static const String categoryTop = 'category_top';
  static const String homepageFeatured = 'homepage_featured';
}

/// Delivery types
class DeliveryTypes {
  static const String pickupInPerson = 'pickup_in_person';
  static const String sellerDelivery = 'seller_delivery';
  static const String motoboy = 'motoboy';
  static const String thirdParty = 'third_party';
}

/// Order payment split status
class PaymentSplitStatus {
  static const String pending = 'pending';
  static const String held = 'held';
  static const String released = 'released';
  static const String refunded = 'refunded';
}

/// Review target types
class ReviewTargetTypes {
  static const String product = 'product';
  static const String seller = 'seller';
}

/// Report target types
class ReportTargetTypes {
  static const String product = 'product';
  static const String seller = 'seller';
  static const String user = 'user';
  static const String review = 'review';
}

/// Report status
class ReportStatus {
  static const String pending = 'pending';
  static const String underReview = 'under_review';
  static const String resolved = 'resolved';
  static const String dismissed = 'dismissed';
}

/// WhatsApp colors
class WhatsAppColors {
  static const int primary = 0xFF25D366;
  static const int dark = 0xFF128C7E;
  static const int light = 0xFF34D399;
}

/// Error messages
class MarketplaceErrorMessages {
  static const String whatsappNotAvailable = 'WhatsApp não está disponível neste dispositivo';
  static const String locationPermissionDenied = 'Permissão de localização negada';
  static const String reviewAlreadyExists = 'Você já avaliou este item';
  static const String cannotReviewWithoutPurchase = 'Você precisa comprar o produto para avaliar';
  static const String reportAlreadyExists = 'Você já denunciou este item';
  static const String paymentOnHold = 'Pagamento em espera (aguardando confirmação de entrega)';
  static const String promotionNotPaid = 'Promoção pendente de pagamento';
}

/// Success messages
class MarketplaceSuccessMessages {
  static const String reviewCreated = 'Avaliação enviada com sucesso!';
  static const String addedToWishlist = 'Produto adicionado aos favoritos';
  static const String removedFromWishlist = 'Produto removido dos favoritos';
  static const String reportSubmitted = 'Denúncia enviada. Nossa equipe irá analisar.';
  static const String deliveryConfirmed = 'Entrega confirmada! Pagamento será liberado em 24h.';
  static const String promotionCreated = 'Promoção criada com sucesso!';
}

/// Notification types
class NotificationTypes {
  static const String priceDropAlert = 'price_drop_alert';
  static const String availabilityAlert = 'availability_alert';
  static const String newProductNearby = 'new_product_nearby';
  static const String deliveryConfirmation = 'delivery_confirmation';
  static const String paymentReleased = 'payment_released';
  static const String reviewResponse = 'review_response';
  static const String promotionEnding = 'promotion_ending';
}

/// Local storage keys
class StorageKeys {
  static const String userLocation = 'user_location';
  static const String searchRadius = 'search_radius';
  static const String lastKnownCity = 'last_known_city';
  static const String favoriteCategories = 'favorite_categories';
}

/// Firestore collection names
class Collections {
  static const String reviews = 'reviews';
  static const String wishlists = 'wishlists';
  static const String reports = 'reports';
  static const String adPromotions = 'ad_promotions';
  static const String qrCodes = 'qr_codes';
}

/// Environment variable keys
class EnvKeys {
  static const String mpPublicKey = 'MP_PUBLIC_KEY';
  static const String mpAccessToken = 'MP_ACCESS_TOKEN';
  static const String mpWebhookSecret = 'MP_WEBHOOK_SECRET';
  static const String platformFeePercentage = 'PLATFORM_FEE_PERCENTAGE';
  static const String paymentHoldHours = 'PAYMENT_HOLD_HOURS';
  static const String googleMapsApiKey = 'GOOGLE_MAPS_API_KEY';
}
