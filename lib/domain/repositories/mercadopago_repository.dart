import '../../data/models/mp_connection_model.dart';
import '../../data/models/mp_subscription_model.dart';

/// Mercado Pago Repository Interface
abstract class MercadoPagoRepository {
  // === OAuth ===

  /// Gera URL de autorização OAuth do MP
  Future<String> getOAuthUrl();

  /// Troca authorization code por tokens
  Future<MpConnectionModel> exchangeOAuthCode(String code, {String? state});

  /// Status da conexão OAuth
  Future<MpConnectionModel> getConnectionStatus();

  /// Desconecta conta MP
  Future<void> disconnect();

  // === Subscriptions ===

  /// Cria assinatura do vendedor
  Future<MpSubscriptionModel> createSubscription({
    required String planType,
    String? cardTokenId,
  });

  /// Consulta assinatura atual
  Future<MpSubscriptionModel?> getCurrentSubscription();

  /// Cancela assinatura
  Future<void> cancelSubscription();

  // === Public Key ===

  /// Retorna a public key do MP para tokenização
  Future<String> getPublicKey();
}
