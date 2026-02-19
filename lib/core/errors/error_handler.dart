/// Global error handler
library;

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:logger/logger.dart';

import 'app_exception.dart';

/// Exception types for categorization
enum AppExceptionType {
  network,
  timeout,
  server,
  authentication,
  unauthorized,
  forbidden,
  notFound,
  validation,
  conflict,
  tooManyRequests,
  serviceUnavailable,
  cancelled,
  badRequest,
  unknown,
}

/// Global error handler
class ErrorHandler {
  static final _logger = Logger();

  /// Handle any error and convert to AppException
  static AppException handle(dynamic error) {
    _logger.e('Error occurred', error: error);

    if (error is AppException) {
      return error;
    }

    if (error is FirebaseAuthException) {
      return AuthException.fromFirebaseCode(error.code, originalError: error);
    }

    if (error is FirebaseException) {
      return _handleFirebaseError(error);
    }

    if (error is DioException) {
      return _handleDioError(error);
    }

    return ApiException(
      message: error.toString(),
      code: 'UNKNOWN',
    );
  }


  /// Handle Firebase errors
  static AppException _handleFirebaseError(FirebaseException error) {
    final message = switch (error.code) {
      'permission-denied' => 'Você não tem permissão para acessar este recurso',
      'not-found' => 'Recurso não encontrado',
      'already-exists' => 'Este recurso já existe',
      'unavailable' => 'Serviço temporariamente indisponível',
      'unauthenticated' => 'Você precisa estar autenticado',
      'deadline-exceeded' => 'Tempo limite excedido. Tente novamente',
      _ => error.message ?? 'Erro no servidor',
    };

    // Map to appropriate exception type
    if (error.code == 'permission-denied' || error.code == 'unauthenticated') {
      return AuthException(
        message: message,
        code: error.code,
        originalError: error,
      );
    }

    return ApiException(
      message: message,
      code: error.code,
      originalError: error,
    );
  }

  /// Handle Dio errors
  static AppException _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException.timeout(originalError: error);

      case DioExceptionType.badResponse:
        return _handleHttpError(error.response!.statusCode!, error.response?.data);

      case DioExceptionType.cancel:
        return ApiException(
          message: 'Requisição cancelada',
          code: 'CANCELLED',
          originalError: error,
        );

      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        return ApiException.networkError(originalError: error);

      default:
        return ApiException(
          message: 'Erro desconhecido',
          code: 'UNKNOWN',
          originalError: error,
        );
    }
  }

  /// Handle HTTP status code errors
  static AppException _handleHttpError(int statusCode, dynamic data) {
    // Try to extract message from response
    String? message;
    if (data is Map && data.containsKey('message')) {
      message = data['message'] as String;
    }

    // Extract validation errors if present
    Map<String, List<String>>? fieldErrors;
    if (statusCode == 422 && data is Map && data.containsKey('errors')) {
      final errors = data['errors'];
      if (errors is Map) {
        fieldErrors = errors.map(
          (key, value) => MapEntry(
            key.toString(),
            (value is List) ? value.cast<String>() : [value.toString()],
          ),
        );
        return ValidationException.fromFieldErrors(fieldErrors);
      }
    }

    // Handle auth errors
    if (statusCode == 401 || statusCode == 403) {
      return AuthException(
        message: message ?? (statusCode == 401
          ? 'Não autorizado. Faça login novamente'
          : 'Acesso negado'),
        code: 'HTTP_$statusCode',
      );
    }

    // Return API exception
    return ApiException.fromStatusCode(
      statusCode: statusCode,
      message: message,
      responseData: data is Map ? data.cast<String, dynamic>() : null,
    );
  }
}

/// Dio interceptor for error handling
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final appException = ErrorHandler.handle(err);
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        error: appException,
        type: err.type,
      ),
    );
  }
}
