import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider to track whether the app is in seller mode
/// Persists the preference to local storage
final sellerModeProvider = StateNotifierProvider<SellerModeNotifier, bool>((ref) {
  return SellerModeNotifier(ref.read(sellerModeInitialValueProvider));
});

/// Holds the initial value loaded from SharedPreferences before app starts
final sellerModeInitialValueProvider = StateProvider<bool>((ref) => false);

/// Convenience provider to check if seller mode is active
final isSellerModeProvider = Provider<bool>((ref) {
  return ref.watch(sellerModeProvider);
});

class SellerModeNotifier extends StateNotifier<bool> {
  static const _key = 'seller_mode_active';

  SellerModeNotifier(bool initialValue) : super(initialValue);

  /// Call this once at app startup before navigation
  static Future<bool> loadInitialValue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_key) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> toggle() async {
    state = !state;
    await _saveToPrefs();
  }

  Future<void> setMode(bool isSellerMode) async {
    if (state != isSellerMode) {
      state = isSellerMode;
      await _saveToPrefs();
    }
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, state);
    } catch (_) {
      // Ignore save errors
    }
  }
}
