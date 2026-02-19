// ===========================================================================
// Compre Aqui - Application Configuration
// Gerencia variáveis de ambiente e configurações globais
// ===========================================================================

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logger/logger.dart';

/// Configuração global da aplicação
class AppConfig {
  /// Nome do aplicativo
  static String get appName => dotenv.get('APP_NAME', fallback: 'Compre Aqui');

  /// URL base da API
  static String get apiBaseUrl =>
      dotenv.get('API_BASE_URL', fallback: 'https://api.nexerp.com.br');

  /// Nível de log (debug, info, warning, error)
  static String get logLevel => dotenv.get('LOG_LEVEL', fallback: 'info');

  /// Se deve habilitar logging
  static bool get enableLogging =>
      dotenv.get('ENABLE_LOGGING', fallback: 'true') == 'true';

  /// Mercado Pago Public Key (for card tokenization on client)
  static String get mpPublicKey =>
      dotenv.get('MP_PUBLIC_KEY', fallback: '');

  /// Platform fee percentage
  static double get platformFeePercentage =>
      double.tryParse(dotenv.get('PLATFORM_FEE_PERCENTAGE', fallback: '10.0')) ?? 10.0;

  /// Payment hold hours after delivery confirmation
  static int get paymentHoldHours =>
      int.tryParse(dotenv.get('PAYMENT_HOLD_HOURS', fallback: '24')) ?? 24;

  /// Instância do logger configurado
  static final Logger logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
    level: _getLogLevel(),
  );

  /// Converte string do log level para enum Level
  static Level _getLogLevel() {
    if (!enableLogging) return Level.off;

    switch (logLevel.toLowerCase()) {
      case 'debug':
        return Level.debug;
      case 'info':
        return Level.info;
      case 'warning':
        return Level.warning;
      case 'error':
        return Level.error;
      default:
        return Level.info;
    }
  }

  /// Carrega o arquivo .env apropriado
  static Future<void> load({String environment = 'dev'}) async {
    final envFile = environment == 'prod' ? '.env.prod' : '.env.dev';
    await dotenv.load(fileName: envFile);
    logger.i('Configuration loaded from $envFile');
    logger.i('API Base URL: $apiBaseUrl');
  }
}
