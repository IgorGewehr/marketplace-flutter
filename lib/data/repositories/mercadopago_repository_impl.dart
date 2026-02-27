import '../../core/constants/api_constants.dart';
import '../../domain/repositories/mercadopago_repository.dart';
import '../datasources/api_client.dart';
import '../models/mp_connection_model.dart';

/// Mercado Pago Repository Implementation
class MercadoPagoRepositoryImpl implements MercadoPagoRepository {
  final ApiClient _apiClient;

  MercadoPagoRepositoryImpl({required ApiClient apiClient})
      : _apiClient = apiClient;

  // === OAuth ===

  @override
  Future<String> getOAuthUrl() async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiConstants.mpOAuthUrl,
      data: {'action': 'url'},
    );
    return response['url'] as String;
  }

  @override
  Future<MpConnectionModel> exchangeOAuthCode(String code, {String? state}) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiConstants.mpOAuthCallback,
      data: {
        'action': 'callback',
        'code': code,
        if (state != null) 'state': state,
      },
    );
    return MpConnectionModel.fromJson(response);
  }

  @override
  Future<MpConnectionModel> getConnectionStatus() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConstants.mpOAuthStatus,
    );
    return MpConnectionModel.fromJson(response);
  }

  @override
  Future<void> disconnect() async {
    await _apiClient.delete(ApiConstants.mpOAuthDisconnect);
  }

  // === Public Key ===

  @override
  Future<String> getPublicKey() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiConstants.mpPublicKey,
    );
    return response['publicKey'] as String;
  }
}
