import '../../core/constants/api_constants.dart';
import '../../domain/repositories/tenant_repository.dart';
import '../datasources/api_client.dart';
import '../models/tenant_model.dart';

/// Tenant Repository Implementation
class TenantRepositoryImpl implements TenantRepository {
  final ApiClient _apiClient;

  TenantRepositoryImpl({required ApiClient apiClient}) : _apiClient = apiClient;

  @override
  Future<TenantModel> getById(String id) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConstants.tenantById(id),
    );
    return TenantModel.fromJson(response);
  }
}
