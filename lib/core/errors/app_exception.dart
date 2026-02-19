/// Custom exception classes for Compre Aqui
library;

/// Base exception class for all app exceptions
sealed class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;
  final StackTrace? stackTrace;

  const AppException({
    required this.message,
    this.code,
    this.originalError,
    this.stackTrace,
  });

  @override
  String toString() => 'AppException: $message (code: $code)';
}

/// API/Network related exceptions
class ApiException extends AppException {
  final int? statusCode;
  final Map<String, dynamic>? responseData;

  const ApiException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
    this.statusCode,
    this.responseData,
  });

  /// Check if this is a client error (4xx)
  bool get isClientError => statusCode != null && statusCode! >= 400 && statusCode! < 500;

  /// Check if this is a server error (5xx)
  bool get isServerError => statusCode != null && statusCode! >= 500;

  /// Check if this is a network/connection error
  bool get isNetworkError => statusCode == null && code == 'NETWORK_ERROR';

  /// Check if this is a timeout error
  bool get isTimeoutError => code == 'TIMEOUT';

  factory ApiException.networkError({dynamic originalError, StackTrace? stackTrace}) {
    return ApiException(
      message: 'Sem conexão com a internet. Verifique sua conexão e tente novamente.',
      code: 'NETWORK_ERROR',
      originalError: originalError,
      stackTrace: stackTrace,
    );
  }

  factory ApiException.timeout({dynamic originalError, StackTrace? stackTrace}) {
    return ApiException(
      message: 'A requisição demorou muito. Tente novamente.',
      code: 'TIMEOUT',
      originalError: originalError,
      stackTrace: stackTrace,
    );
  }

  factory ApiException.serverError({
    int? statusCode,
    Map<String, dynamic>? responseData,
    dynamic originalError,
    StackTrace? stackTrace,
  }) {
    return ApiException(
      message: 'Erro no servidor. Tente novamente mais tarde.',
      code: 'SERVER_ERROR',
      statusCode: statusCode,
      responseData: responseData,
      originalError: originalError,
      stackTrace: stackTrace,
    );
  }

  factory ApiException.fromStatusCode({
    required int statusCode,
    String? message,
    Map<String, dynamic>? responseData,
    dynamic originalError,
    StackTrace? stackTrace,
  }) {
    final defaultMessage = switch (statusCode) {
      400 => 'Requisição inválida. Verifique os dados e tente novamente.',
      401 => 'Sessão expirada. Faça login novamente.',
      403 => 'Você não tem permissão para realizar esta ação.',
      404 => 'Recurso não encontrado.',
      409 => 'Conflito de dados. Este registro já existe.',
      422 => 'Dados inválidos. Verifique as informações.',
      429 => 'Muitas requisições. Aguarde um momento.',
      >= 500 => 'Erro no servidor. Tente novamente mais tarde.',
      _ => 'Erro desconhecido. Tente novamente.',
    };

    return ApiException(
      message: message ?? defaultMessage,
      code: 'HTTP_$statusCode',
      statusCode: statusCode,
      responseData: responseData,
      originalError: originalError,
      stackTrace: stackTrace,
    );
  }

  @override
  String toString() => 'ApiException: $message (status: $statusCode, code: $code)';
}

/// Authentication related exceptions
class AuthException extends AppException {
  const AuthException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });

  factory AuthException.invalidCredentials() {
    return const AuthException(
      message: 'Email ou senha incorretos.',
      code: 'INVALID_CREDENTIALS',
    );
  }

  factory AuthException.userNotFound() {
    return const AuthException(
      message: 'Usuário não encontrado.',
      code: 'USER_NOT_FOUND',
    );
  }

  factory AuthException.emailAlreadyInUse() {
    return const AuthException(
      message: 'Este email já está em uso.',
      code: 'EMAIL_ALREADY_IN_USE',
    );
  }

  factory AuthException.weakPassword() {
    return const AuthException(
      message: 'A senha é muito fraca. Use pelo menos 6 caracteres.',
      code: 'WEAK_PASSWORD',
    );
  }

  factory AuthException.tokenExpired() {
    return const AuthException(
      message: 'Sua sessão expirou. Faça login novamente.',
      code: 'TOKEN_EXPIRED',
    );
  }

  factory AuthException.notAuthenticated() {
    return const AuthException(
      message: 'Você precisa estar logado para acessar esta funcionalidade.',
      code: 'NOT_AUTHENTICATED',
    );
  }

  factory AuthException.fromFirebaseCode(String code, {dynamic originalError, StackTrace? stackTrace}) {
    final message = switch (code) {
      'user-not-found' => 'Usuário não encontrado.',
      'wrong-password' => 'Senha incorreta.',
      'invalid-email' => 'Email inválido.',
      'user-disabled' => 'Esta conta foi desativada.',
      'email-already-in-use' => 'Este email já está em uso.',
      'operation-not-allowed' => 'Operação não permitida.',
      'weak-password' => 'A senha é muito fraca.',
      'invalid-credential' => 'Credenciais inválidas.',
      'account-exists-with-different-credential' => 'Uma conta já existe com um método de login diferente.',
      'requires-recent-login' => 'Esta operação requer login recente. Faça login novamente.',
      'too-many-requests' => 'Muitas tentativas. Aguarde um momento.',
      'network-request-failed' => 'Erro de conexão. Verifique sua internet.',
      _ => 'Erro de autenticação. Tente novamente.',
    };

    return AuthException(
      message: message,
      code: code,
      originalError: originalError,
      stackTrace: stackTrace,
    );
  }

  @override
  String toString() => 'AuthException: $message (code: $code)';
}

/// Validation related exceptions
class ValidationException extends AppException {
  final Map<String, List<String>>? fieldErrors;

  const ValidationException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
    this.fieldErrors,
  });

  /// Get errors for a specific field
  List<String> getFieldErrors(String field) {
    return fieldErrors?[field] ?? [];
  }

  /// Check if a specific field has errors
  bool hasFieldError(String field) {
    return fieldErrors?.containsKey(field) ?? false;
  }

  factory ValidationException.required(String field) {
    return ValidationException(
      message: 'O campo $field é obrigatório.',
      code: 'REQUIRED',
      fieldErrors: {
        field: ['Este campo é obrigatório.']
      },
    );
  }

  factory ValidationException.invalid(String field, String reason) {
    return ValidationException(
      message: 'O campo $field é inválido: $reason',
      code: 'INVALID',
      fieldErrors: {
        field: [reason]
      },
    );
  }

  factory ValidationException.fromFieldErrors(Map<String, List<String>> errors) {
    final firstError = errors.values.expand((e) => e).firstOrNull ?? 'Dados inválidos.';
    return ValidationException(
      message: firstError,
      code: 'VALIDATION_ERROR',
      fieldErrors: errors,
    );
  }

  @override
  String toString() => 'ValidationException: $message (fields: ${fieldErrors?.keys.join(", ")})';
}

/// Cache/Storage related exceptions
class CacheException extends AppException {
  const CacheException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });

  factory CacheException.notFound(String key) {
    return CacheException(
      message: 'Cache não encontrado para: $key',
      code: 'NOT_FOUND',
    );
  }

  factory CacheException.expired(String key) {
    return CacheException(
      message: 'Cache expirado para: $key',
      code: 'EXPIRED',
    );
  }

  @override
  String toString() => 'CacheException: $message (code: $code)';
}

/// Permission related exceptions
class PermissionException extends AppException {
  const PermissionException({
    required super.message,
    super.code,
    super.originalError,
    super.stackTrace,
  });

  factory PermissionException.denied(String permission) {
    return PermissionException(
      message: 'Permissão negada: $permission',
      code: 'DENIED',
    );
  }

  factory PermissionException.sellerRequired() {
    return const PermissionException(
      message: 'Esta funcionalidade está disponível apenas para vendedores.',
      code: 'SELLER_REQUIRED',
    );
  }

  @override
  String toString() => 'PermissionException: $message (code: $code)';
}
