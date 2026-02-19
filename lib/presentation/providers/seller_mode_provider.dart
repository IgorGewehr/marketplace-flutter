import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider to track whether the app is in seller mode
/// Persists the preference to local storage
final sellerModeProvider = StateNotifierProvider<SellerModeNotifier, bool>((ref) {
  return SellerModeNotifier();
});

/// Convenience provider to check if seller mode is active
final isSellerModeProvider = Provider<bool>((ref) {
  return ref.watch(sellerModeProvider);
});

class SellerModeNotifier extends StateNotifier<bool> {
  static const _key = 'seller_mode_active';

  SellerModeNotifier() : super(false) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getBool(_key) ?? false;
    } catch (_) {
      // Ignore errors, default to false
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
