import 'package:flutter/services.dart';

/// Wrapper Flutter para tokenização de cartão via Mercado Pago SDK nativo.
///
/// Usa Platform Channel para acessar a API de tokenização do MP.
/// Cartões nunca são enviados ao nosso backend - apenas tokens.
class MpCardTokenizer {
  static const _channel =
      MethodChannel('com.tensorroot.marketplace/mp_tokenizer');

  static bool _initialized = false;

  /// Inicializa o SDK com a public key do Mercado Pago
  static Future<void> initialize(String publicKey) async {
    if (_initialized) return;
    await _channel.invokeMethod('initialize', {'publicKey': publicKey});
    _initialized = true;
  }

  /// Tokeniza dados do cartão e retorna o token ID.
  ///
  /// O token é gerado diretamente com o Mercado Pago, sem passar pelo backend.
  /// Retorna o tokenId, lastFourDigits e firstSixDigits.
  static Future<CardTokenResult> tokenizeCard({
    required String cardNumber,
    required String expirationMonth,
    required String expirationYear,
    required String securityCode,
    required String cardholderName,
    required String identificationNumber,
    String identificationType = 'CPF',
  }) async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'tokenizeCard',
      {
        'cardNumber': cardNumber.replaceAll(RegExp(r'\D'), ''),
        'expirationMonth': expirationMonth,
        'expirationYear': expirationYear,
        'securityCode': securityCode,
        'cardholderName': cardholderName,
        'identificationNumber':
            identificationNumber.replaceAll(RegExp(r'\D'), ''),
        'identificationType': identificationType,
      },
    );

    if (result == null || result['tokenId'] == null) {
      throw PlatformException(
        code: 'TOKENIZATION_FAILED',
        message: 'Falha ao tokenizar cartão',
      );
    }

    return CardTokenResult(
      tokenId: result['tokenId'] as String,
      lastFourDigits: result['lastFourDigits'] as String?,
      firstSixDigits: result['firstSixDigits'] as String?,
    );
  }
}

/// Resultado da tokenização de cartão
class CardTokenResult {
  final String tokenId;
  final String? lastFourDigits;
  final String? firstSixDigits;

  const CardTokenResult({
    required this.tokenId,
    this.lastFourDigits,
    this.firstSixDigits,
  });
}
