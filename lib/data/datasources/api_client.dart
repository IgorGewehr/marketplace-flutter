import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/constants/api_constants.dart';
import '../../core/errors/app_exception.dart';
import 'auth_interceptor.dart';
import 'cache_interceptor.dart';
import 'local_storage_service.dart';
import 'retry_interceptor.dart';

/// API Client using Dio for HTTP requests
class ApiClient {
  late final Dio _dio;

  ApiClient({
    String? baseUrl,
    List<Interceptor>? interceptors,
    LocalStorageService? localStorage,
  }) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? ApiConstants.baseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        sendTimeout: ApiConstants.sendTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        validateStatus: (status) => status != null && status >= 200 && status < 300,
      ),
    );

    // Add interceptors
    _dio.interceptors.addAll([
      AuthInterceptor(),
      if (localStorage != null)
        CacheInterceptor(storage: localStorage),
      RetryInterceptor(parentDio: _dio, maxRetries: 3),
      if (kDebugMode) LoggingInterceptor(enabled: true),
      ...?interceptors,
    ]);
  }

  Dio get dio => _dio;

  /// GET request
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
      );
      return _handleResponse(response);
    } on DioException catch (e, stackTrace) {
      throw _handleDioException(e, stackTrace);
    }
  }

  /// POST request
  Future<T> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return _handleResponse(response);
    } on DioException catch (e, stackTrace) {
      throw _handleDioException(e, stackTrace);
    }
  }

  /// PUT request
  Future<T> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return _handleResponse(response);
    } on DioException catch (e, stackTrace) {
      throw _handleDioException(e, stackTrace);
    }
  }

  /// PATCH request
  Future<T> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return _handleResponse(response);
    } on DioException catch (e, stackTrace) {
      throw _handleDioException(e, stackTrace);
    }
  }

  /// DELETE request
  Future<T> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return _handleResponse(response);
    } on DioException catch (e, stackTrace) {
      throw _handleDioException(e, stackTrace);
    }
  }

  /// Upload file(s)
  Future<T> uploadFile<T>(
    String path, {
    required List<MultipartFile> files,
    Map<String, dynamic>? data,
    String fileField = 'files',
    void Function(int, int)? onSendProgress,
  }) async {
    try {
      final formData = FormData.fromMap({
        fileField: files,
        ...?data,
      });

      final response = await _dio.post<T>(
        path,
        data: formData,
        onSendProgress: onSendProgress,
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );
      return _handleResponse(response);
    } on DioException catch (e, stackTrace) {
      throw _handleDioException(e, stackTrace);
    }
  }

  /// Handle successful response
  T _handleResponse<T>(Response<T> response) {
    return response.data as T;
  }

  /// Handle Dio exceptions
  AppException _handleDioException(DioException e, StackTrace stackTrace) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException.timeout(originalError: e, stackTrace: stackTrace);

      case DioExceptionType.connectionError:
        return ApiException.networkError(originalError: e, stackTrace: stackTrace);

      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode ?? 0;
        final responseData = e.response?.data;
        String? message;

        if (responseData is Map<String, dynamic>) {
          message = responseData['message'] as String? ??
              responseData['error'] as String?;
        }

        return ApiException.fromStatusCode(
          statusCode: statusCode,
          message: message,
          responseData: responseData is Map<String, dynamic> ? responseData : null,
          originalError: e,
          stackTrace: stackTrace,
        );

      case DioExceptionType.cancel:
        return ApiException(
          message: 'Requisição cancelada.',
          code: 'CANCELLED',
          originalError: e,
          stackTrace: stackTrace,
        );

      default:
        return ApiException.networkError(originalError: e, stackTrace: stackTrace);
    }
  }
}
