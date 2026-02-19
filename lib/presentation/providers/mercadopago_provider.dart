import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/mp_connection_model.dart';
import '../../data/models/mp_subscription_model.dart';
import 'auth_providers.dart';
import 'core_providers.dart';

// ==========================================================================
// MP Connection Provider
// ==========================================================================

class MpConnectionNotifier extends AsyncNotifier<MpConnectionModel?> {
  @override
  Future<MpConnectionModel?> build() async {
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user == null || !user.isSeller) return null;

    try {
      final repo = ref.read(mercadoPagoRepositoryProvider);
      return await repo.getConnectionStatus();
    } catch (_) {
      return MpConnectionModel.disconnected();
    }
  }

  Future<String> getOAuthUrl() async {
    final repo = ref.read(mercadoPagoRepositoryProvider);
    return await repo.getOAuthUrl();
  }

  Future<void> exchangeCode(String code) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(mercadoPagoRepositoryProvider);
      return await repo.exchangeOAuthCode(code);
    });
  }

  Future<void> disconnect() async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(mercadoPagoRepositoryProvider);
      await repo.disconnect();
      state = AsyncData(MpConnectionModel.disconnected());
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(mercadoPagoRepositoryProvider);
      return await repo.getConnectionStatus();
    });
  }
}

final mpConnectionProvider =
    AsyncNotifierProvider<MpConnectionNotifier, MpConnectionModel?>(
  MpConnectionNotifier.new,
);

// ==========================================================================
// MP Subscription Provider
// ==========================================================================

class MpSubscriptionNotifier extends AsyncNotifier<MpSubscriptionModel?> {
  @override
  Future<MpSubscriptionModel?> build() async {
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user == null || !user.isSeller) return null;

    try {
      final repo = ref.read(mercadoPagoRepositoryProvider);
      return await repo.getCurrentSubscription();
    } catch (_) {
      return null;
    }
  }

  Future<MpSubscriptionModel> create(String planType,
      {String? cardTokenId}) async {
    final repo = ref.read(mercadoPagoRepositoryProvider);
    final result = await repo.createSubscription(
      planType: planType,
      cardTokenId: cardTokenId,
    );

    state = AsyncData(result);
    return result;
  }

  Future<void> cancel() async {
    state = const AsyncLoading();
    try {
      final repo = ref.read(mercadoPagoRepositoryProvider);
      await repo.cancelSubscription();
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(mercadoPagoRepositoryProvider);
      return await repo.getCurrentSubscription();
    });
  }
}

final mpSubscriptionProvider =
    AsyncNotifierProvider<MpSubscriptionNotifier, MpSubscriptionModel?>(
  MpSubscriptionNotifier.new,
);

// ==========================================================================
// Convenience Providers
// ==========================================================================

/// Whether the seller is connected to Mercado Pago
final isMpConnectedProvider = Provider<bool>((ref) {
  final connection = ref.watch(mpConnectionProvider).valueOrNull;
  return connection?.isConnected ?? false;
});

/// MP Public Key provider (cached)
final mpPublicKeyProvider = FutureProvider<String>((ref) async {
  final repo = ref.read(mercadoPagoRepositoryProvider);
  return await repo.getPublicKey();
});
