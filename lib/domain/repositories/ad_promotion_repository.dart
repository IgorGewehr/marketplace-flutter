/// Ad promotion repository interface
library;

import '../../data/models/ad_promotion_model.dart';

abstract class AdPromotionRepository {
  /// Get all promotions for a tenant
  Future<List<AdPromotionModel>> getTenantPromotions(String tenantId);

  /// Get active promotions
  Future<List<AdPromotionModel>> getActivePromotions();

  /// Get promotion by ID
  Future<AdPromotionModel?> getPromotionById(String promotionId);

  /// Create a new promotion
  Future<AdPromotionModel> createPromotion(AdPromotionModel promotion);

  /// Update promotion
  Future<void> updatePromotion(AdPromotionModel promotion);

  /// Cancel promotion
  Future<void> cancelPromotion(String promotionId);

  /// Update promotion stats
  Future<void> updatePromotionStats(String promotionId, AdPromotionStats stats);

  /// Get promoted products for location
  Future<List<String>> getPromotedProductIds({
    String? city,
    String? categoryId,
    String promotionType = 'city_top',
  });

  /// Record impression
  Future<void> recordImpression(String promotionId);

  /// Record click
  Future<void> recordClick(String promotionId);

  /// Record conversion
  Future<void> recordConversion(String promotionId);
}
