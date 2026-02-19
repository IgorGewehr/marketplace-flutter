import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

/// Centralized Hive box management.
/// All boxes are opened once at startup and reused throughout the app.
class LocalStorageService {
  static const String _favoritesBox = 'favorites';
  static const String _serviceFavoritesBox = 'service_favorites';
  static const String _cartBox = 'cart_box';
  static const String _settingsBox = 'settings_box';
  static const String _productCacheBox = 'product_cache';
  static const String _apiCacheBox = 'api_cache';

  late final Box<String> favoritesBox;
  late final Box<String> serviceFavoritesBox;
  late final Box cartBox;
  late final Box settingsBox;
  late final Box<String> productCacheBox;
  late final Box<String> apiCacheBox;

  /// Open all boxes. Must be called once after Hive.initFlutter().
  Future<void> init() async {
    favoritesBox = await Hive.openBox<String>(_favoritesBox);
    serviceFavoritesBox = await Hive.openBox<String>(_serviceFavoritesBox);
    cartBox = await Hive.openBox(_cartBox);
    settingsBox = await Hive.openBox(_settingsBox);
    productCacheBox = await Hive.openBox<String>(_productCacheBox);
    apiCacheBox = await Hive.openBox<String>(_apiCacheBox);

    // Migrate settings from cartBox to settingsBox (one-time)
    await _migrateSettings();
  }

  Future<void> _migrateSettings() async {
    final keys = cartBox.keys.where((k) => k.toString().startsWith('setting_'));
    for (final key in keys) {
      final settingKey = key.toString().replaceFirst('setting_', '');
      if (settingsBox.get(settingKey) == null) {
        await settingsBox.put(settingKey, cartBox.get(key));
      }
      await cartBox.delete(key);
    }
  }

  // ===== Favorites =====

  Set<String> loadFavoriteIds() {
    return favoritesBox.values.toSet();
  }

  Future<void> saveFavoriteIds(Set<String> ids) async {
    await favoritesBox.clear();
    for (final id in ids) {
      await favoritesBox.add(id);
    }
  }

  // ===== Service Favorites =====

  Set<String> loadServiceFavoriteIds() {
    return serviceFavoritesBox.values.toSet();
  }

  Future<void> saveServiceFavoriteIds(Set<String> ids) async {
    await serviceFavoritesBox.clear();
    for (final id in ids) {
      await serviceFavoritesBox.add(id);
    }
  }

  // ===== Product Cache (for favorites & recently viewed) =====

  void cacheProduct(String id, Map<String, dynamic> json) {
    productCacheBox.put(id, jsonEncode(json));
  }

  void cacheProducts(Map<String, Map<String, dynamic>> products) {
    for (final entry in products.entries) {
      productCacheBox.put(entry.key, jsonEncode(entry.value));
    }
  }

  Map<String, dynamic>? getCachedProduct(String id) {
    final raw = productCacheBox.get(id);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  List<Map<String, dynamic>> getCachedProducts(Set<String> ids) {
    final results = <Map<String, dynamic>>[];
    for (final id in ids) {
      final cached = getCachedProduct(id);
      if (cached != null) results.add(cached);
    }
    return results;
  }

  Future<void> clearProductCache() async {
    await productCacheBox.clear();
  }

  // ===== Cart =====

  static const String _cartKey = 'cart_items';

  List<dynamic>? loadCartItems() {
    return cartBox.get(_cartKey) as List<dynamic>?;
  }

  Future<void> saveCartItems(List<Map<String, dynamic>> items) async {
    await cartBox.put(_cartKey, items);
  }

  // ===== Settings (key-value via settingsBox) =====

  bool? getBool(String key) => settingsBox.get(key) as bool?;

  Future<void> setBool(String key, bool value) async {
    await settingsBox.put(key, value);
  }

  // ===== API Response Cache =====

  /// Store a cached API response with timestamp.
  Future<void> cacheApiResponse(String key, String responseBody) async {
    final entry = jsonEncode({
      'data': responseBody,
      'cachedAt': DateTime.now().toIso8601String(),
    });
    await apiCacheBox.put(key, entry);
  }

  /// Get a cached API response. Returns null if not found or expired.
  /// [maxAge] in seconds. If null, returns regardless of age.
  CachedApiResponse? getApiCache(String key, {int? maxAge}) {
    final raw = apiCacheBox.get(key);
    if (raw == null) return null;

    final entry = jsonDecode(raw) as Map<String, dynamic>;
    final cachedAt = DateTime.parse(entry['cachedAt'] as String);
    final age = DateTime.now().difference(cachedAt);

    final isExpired = maxAge != null && age.inSeconds > maxAge;

    return CachedApiResponse(
      data: entry['data'] as String,
      cachedAt: cachedAt,
      isExpired: isExpired,
    );
  }

  Future<void> clearApiCache() async {
    await apiCacheBox.clear();
  }
}

class CachedApiResponse {
  final String data;
  final DateTime cachedAt;
  final bool isExpired;

  const CachedApiResponse({
    required this.data,
    required this.cachedAt,
    required this.isExpired,
  });
}
