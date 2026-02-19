import 'dart:io';

import 'package:dio/dio.dart';

import '../../core/config/app_config.dart';

/// Retry Interceptor with exponential backoff
/// Automatically retries failed requests due to network issues
class RetryInterceptor extends Interceptor {
  final Dio parentDio;
  final int maxRetries;
  final Duration initialDelay;
  final double backoffMultiplier;

  RetryInterceptor({
    required this.parentDio,
    this.maxRetries = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.backoffMultiplier = 2.0,
  });

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (!_shouldRetry(err)) {
      return handler.next(err);
    }

    final retryCount = err.requestOptions.extra['retryCount'] as int? ?? 0;

    if (retryCount >= maxRetries) {
      AppConfig.logger.w(
        'Max retries ($maxRetries) reached for ${err.requestOptions.uri}',
      );
      return handler.next(err);
    }

    final delay = _calculateDelay(retryCount);
    AppConfig.logger.i(
      'Retrying request ${retryCount + 1}/$maxRetries after ${delay.inMilliseconds}ms: ${err.requestOptions.uri}',
    );

    await Future.delayed(delay);

    try {
      final options = err.requestOptions;
      options.extra['retryCount'] = retryCount + 1;

      // Reuse the parent Dio instance to preserve interceptors (auth, etc.)
      final response = await parentDio.fetch(options);

      return handler.resolve(response);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }

  /// Determines if a request should be retried based on the error type
  bool _shouldRetry(DioException err) {
    // Retry on network errors
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.connectionError) {
      return true;
    }

    // Retry on specific HTTP status codes
    if (err.response?.statusCode != null) {
      final statusCode = err.response!.statusCode!;
      // Retry on server errors (5xx) and rate limiting (429)
      if (statusCode >= 500 || statusCode == 429) {
        return true;
      }
    }

    // Retry on socket exceptions
    if (err.error is SocketException) {
      return true;
    }

    return false;
  }

  /// Calculates delay with exponential backoff
  Duration _calculateDelay(int retryCount) {
    final delayMs = initialDelay.inMilliseconds *
        (backoffMultiplier * (retryCount + 1));
    return Duration(milliseconds: delayMs.toInt());
  }
}
