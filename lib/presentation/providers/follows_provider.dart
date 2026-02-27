import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core_providers.dart';

/// Persisted set of seller tenant IDs that the current user is following.
/// State is loaded from the Hive 'follows' box on construction and saved back
/// after every toggle (offline-first). No backend API call is made because
/// no follow endpoint exists in the current backend.
final followsProvider = StateNotifierProvider<FollowsNotifier, Set<String>>(
  (ref) => FollowsNotifier(ref),
);

class FollowsNotifier extends StateNotifier<Set<String>> {
  final Ref _ref;
  Timer? _syncDebounce;

  FollowsNotifier(this._ref) : super({}) {
    _loadFollows();
  }

  Future<void> _loadFollows() async {
    try {
      final storage = _ref.read(localStorageProvider);
      final local = storage.loadFollowedIds();
      // Merge with any toggles that may have happened while loading.
      state = state.union(local);
    } catch (_) {
      // Silent fail — start with empty set.
    }
  }

  /// Toggle follow state for [tenantId].
  /// Persists locally immediately (offline-first). Server sync is skipped
  /// because no follow endpoint exists yet.
  Future<void> toggleFollow(String tenantId) async {
    final updated = {...state};

    if (updated.contains(tenantId)) {
      updated.remove(tenantId);
    } else {
      updated.add(tenantId);
    }

    // Optimistic local update + Hive persistence.
    state = updated;
    await _ref.read(localStorageProvider).saveFollowedIds(updated);

    // Debounced server sync placeholder (1 500 ms).
    // Replace the body with an API call once a follow endpoint exists.
    _syncDebounce?.cancel();
    _syncDebounce = Timer(const Duration(milliseconds: 1500), () {
      // No-op: local-only persistence is sufficient for M4.
    });
  }

  bool isFollowing(String tenantId) => state.contains(tenantId);

  @override
  void dispose() {
    _syncDebounce?.cancel();
    super.dispose();
  }
}
