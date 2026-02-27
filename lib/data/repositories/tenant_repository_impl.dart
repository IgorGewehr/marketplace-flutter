import '../../core/constants/api_constants.dart';
import '../../core/errors/app_exception.dart';
import '../../domain/repositories/tenant_repository.dart';
import '../datasources/api_client.dart';
import '../models/tenant_model.dart';

/// Tenant Repository Implementation
class TenantRepositoryImpl implements TenantRepository {
  final ApiClient _apiClient;

  TenantRepositoryImpl({required ApiClient apiClient}) : _apiClient = apiClient;

  @override
  Future<TenantModel?> getById(String id) async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        ApiConstants.tenantById(id),
      );
      return TenantModel.fromJson(response);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    } catch (_) {
      // Parsing or unexpected error — return null instead of crashing the provider
      return null;
    }
  }

  @override
  Future<void> updateProfile({
    String? name,
    String? description,
    String? logoUrl,
    String? coverUrl,
  }) async {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name;
    if (description != null) data['description'] = description;
    if (logoUrl != null) data['logoUrl'] = logoUrl;
    if (coverUrl != null) data['coverUrl'] = coverUrl;
    await _apiClient.patch<Map<String, dynamic>>(
      ApiConstants.sellerProfile,
      data: data,
    );
  }
}
