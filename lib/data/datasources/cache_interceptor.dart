import 'dart:convert';

import 'package:dio/dio.dart';

import 'local_storage_service.dart';

/// Dio interceptor that caches GET responses in Hive.
/// - Fresh data returned for requests within [maxAge].
/// - Stale data served on network errors (offline support).
/// - Only caches GET requests for specified path prefixes.
class CacheInterceptor extends Interceptor {
  final LocalStorageService _storage;

  /// Max cache age in seconds (default: 5 minutes)
  final int maxAge;

  /// Only cache paths starting with these prefixes
  final List<String> cachedPaths;

  CacheInterceptor({
    required LocalStorageService storage,
    this.maxAge = 300,
    this.cachedPaths = const [
      '/api/marketplace/products',
      '/api/marketplace/categories',
      '/api/marketplace/banners',
      '/api/marketplace/featured',
    ],
  }) : _storage = storage;

  String _cacheKey(RequestOptions options) {
    final uri = options.uri.toString();
    return uri;
  }

  bool _shouldCache(RequestOptions options) {
    if (options.method.toUpperCase() != 'GET') return false;
    return cachedPaths.any((prefix) => options.path.startsWith(prefix));
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!_shouldCache(options)) {
      handler.next(options);
      return;
    }

    // Check cache for fresh data
    final key = _cacheKey(options);
    final cached = _storage.getApiCache(key, maxAge: maxAge);

    if (cached != null && !cached.isExpired) {
      // Return cached response immediately
      final data = jsonDecode(cached.data);
      handler.resolve(
        Response(
          requestOptions: options,
          data: data,
          statusCode: 200,
          headers: Headers.fromMap({'x-cache': ['HIT']}),
        ),
        true, // call onResponse
      );
      return;
    }

    // Stale or no cache - proceed with network request
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // Cache successful GET responses
    if (_shouldCache(response.requestOptions) &&
        response.statusCode != null &&
        response.statusCode! >= 200 &&
        response.statusCode! < 300) {
      final key = _cacheKey(response.requestOptions);
      final body = jsonEncode(response.data);
      _storage.cacheApiResponse(key, body);
    }

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // On network error, try to serve stale cached data
    if (_shouldCache(err.requestOptions) && _isNetworkError(err)) {
      final key = _cacheKey(err.requestOptions);
      final cached = _storage.getApiCache(key); // No maxAge - accept stale

      if (cached != null) {
        final data = jsonDecode(cached.data);
        handler.resolve(
          Response(
            requestOptions: err.requestOptions,
            data: data,
            statusCode: 200,
            headers: Headers.fromMap({'x-cache': ['STALE']}),
          ),
        );
        return;
      }
    }

    handler.next(err);
  }

  bool _isNetworkError(DioException err) {
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.unknown;
  }
}
