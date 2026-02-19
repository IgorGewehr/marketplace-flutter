import '../../data/models/tenant_model.dart';

/// Tenant Repository Interface
abstract class TenantRepository {
  /// Get tenant by ID
  Future<TenantModel> getById(String id);
}
