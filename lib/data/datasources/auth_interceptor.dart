import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/config/app_config.dart';

/// Auth Interceptor for injecting Firebase ID Token into requests.
///
/// On 401 responses, attempts a forced token refresh before signing out.
class AuthInterceptor extends Interceptor {
  final FirebaseAuth _auth;
  bool _isRefreshing = false;

  AuthInterceptor({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final user = _auth.currentUser;

    if (user != null) {
      try {
        // Get fresh ID token (auto-refreshes if expired)
        final idToken = await user.getIdToken();
        options.headers['Authorization'] = 'Bearer $idToken';
      } catch (e) {
        // If token refresh fails, continue without auth header
        // The API will return 401 and onError will handle re-login
      }
    }

    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401 && !_isRefreshing) {
      _isRefreshing = true;

      try {
        final user = _auth.currentUser;
        if (user != null) {
          // Force refresh the token
          final newToken = await user.getIdToken(true);

          if (newToken != null) {
            // Retry the original request with the new token
            final options = err.requestOptions;
            options.headers['Authorization'] = 'Bearer $newToken';

            final response = await Dio(
              BaseOptions(
                baseUrl: options.baseUrl,
                connectTimeout: options.connectTimeout,
                receiveTimeout: options.receiveTimeout,
                sendTimeout: options.sendTimeout,
                validateStatus: (status) =>
                    status != null && status >= 200 && status < 300,
              ),
            ).fetch(options);

            _isRefreshing = false;
            return handler.resolve(response);
          }
        }

        // No user or no token - sign out
        await _auth.signOut();
      } catch (e) {
        // Refresh failed - sign out as last resort
        AppConfig.logger.w('Token refresh failed, signing out: $e');
        await _auth.signOut();
      } finally {
        _isRefreshing = false;
      }
    }

    handler.next(err);
  }
}

/// Sensitive field names that should be masked in logs
const _sensitiveFields = {
  'password',
  'cardTokenId',
  'cardToken',
  'card_token',
  'cpfCnpj',
  'cpf',
  'cnpj',
  'identificationNumber',
  'securityCode',
  'cardNumber',
  'code',
  'token',
  'accessToken',
  'access_token',
  'refreshToken',
  'refresh_token',
  'idToken',
  'id_token',
  'webhook_secret',
  'secret',
};

/// Sanitizes data by masking sensitive fields before logging.
dynamic _sanitize(dynamic data) {
  if (data is Map<String, dynamic>) {
    return data.map((key, value) {
      if (_sensitiveFields.contains(key)) {
        final str = value?.toString() ?? '';
        if (str.length <= 4) return MapEntry(key, '***');
        return MapEntry(key, '${str.substring(0, 2)}***${str.substring(str.length - 2)}');
      }
      return MapEntry(key, _sanitize(value));
    });
  }
  if (data is List) {
    return data.map(_sanitize).toList();
  }
  return data;
}

/// Logging Interceptor for debug mode with sensitive data sanitization
class LoggingInterceptor extends Interceptor {
  final bool enabled;

  LoggingInterceptor({this.enabled = true});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (enabled) {
      AppConfig.logger.d(
        '→ ${options.method} ${options.uri}',
        error: options.data != null ? 'Body: ${_sanitize(options.data)}' : null,
      );
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (enabled) {
      AppConfig.logger.i(
        '← ${response.statusCode} ${response.requestOptions.uri}',
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (enabled) {
      AppConfig.logger.e(
        '✗ ERROR ${err.response?.statusCode ?? 'UNKNOWN'} ${err.requestOptions.uri}',
        error: err.message,
      );
    }
    handler.next(err);
  }
}
