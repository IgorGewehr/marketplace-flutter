import '../../data/models/tenant_model.dart';

/// Tenant Repository Interface
abstract class TenantRepository {
  /// Get tenant by ID. Returns null when the tenant does not exist (404).
  Future<TenantModel?> getById(String id);

  /// Update the seller's own profile (name, description, logo, cover, links).
  /// Calls PATCH /api/seller/profile — requires seller authentication.
  Future<void> updateProfile({
    String? name,
    String? description,
    String? logoUrl,
    String? coverUrl,
    String? instagramUrl,
    String? websiteUrl,
  });
}
