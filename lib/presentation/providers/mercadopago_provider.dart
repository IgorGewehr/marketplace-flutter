import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/mp_connection_model.dart';
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

  Future<void> exchangeCode(String code, {String? state}) async {
    this.state = const AsyncLoading();
    this.state = await AsyncValue.guard(() async {
      final repo = ref.read(mercadoPagoRepositoryProvider);
      return await repo.exchangeOAuthCode(code, state: state);
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
    // Preserve previous value during reload so isMpConnected doesn't
    // momentarily flip to false and trigger spurious MP-connect dialogs.
    state = const AsyncLoading<MpConnectionModel?>().copyWithPrevious(state);
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
// Convenience Providers
// ==========================================================================

/// Whether the seller is connected to Mercado Pago.
///
/// Uses [valueOrNull] which safely returns previous data during loading
/// (when hasValue is true) without throwing on error/initial-loading states.
final isMpConnectedProvider = Provider<bool>((ref) {
  final asyncConnection = ref.watch(mpConnectionProvider);
  final connection = asyncConnection.valueOrNull;
  return connection?.isConnected ?? false;
});

/// Whether the MP connection status is still loading (initial fetch).
final isMpConnectionLoadingProvider = Provider<bool>((ref) {
  final asyncConnection = ref.watch(mpConnectionProvider);
  return asyncConnection.isLoading && !asyncConnection.hasValue;
});

/// MP Public Key provider (cached)
final mpPublicKeyProvider = FutureProvider<String>((ref) async {
  final repo = ref.read(mercadoPagoRepositoryProvider);
  return await repo.getPublicKey();
});

// ==========================================================================
// Installment Options Provider
// ==========================================================================

/// Installment option model
class InstallmentOption {
  final int installments;
  final double installmentAmount;
  final double totalAmount;
  final String recommendedMessage;
  final bool interestFree;

  const InstallmentOption({
    required this.installments,
    required this.installmentAmount,
    required this.totalAmount,
    required this.recommendedMessage,
    required this.interestFree,
  });

  factory InstallmentOption.fromJson(Map<String, dynamic> json) {
    return InstallmentOption(
      installments: (json['installments'] as num).toInt(),
      installmentAmount: (json['installmentAmount'] as num).toDouble(),
      totalAmount: (json['totalAmount'] as num).toDouble(),
      recommendedMessage: json['recommendedMessage'] as String? ?? '',
      interestFree: json['interestFree'] as bool? ?? true,
    );
  }
}

/// Parameters for installments query
class InstallmentsParams {
  final double amount;
  final String bin;

  const InstallmentsParams({required this.amount, required this.bin});

  @override
  bool operator ==(Object other) =>
      other is InstallmentsParams && other.amount == amount && other.bin == bin;

  @override
  int get hashCode => Object.hash(amount, bin);
}

/// Fetch real installment options from MP via backend
final installmentOptionsProvider =
    FutureProvider.family<List<InstallmentOption>, InstallmentsParams>(
  (ref, params) async {
    if (params.bin.length < 6) return [];
    final apiClient = ref.read(apiClientProvider);
    try {
      final response = await apiClient.get<List<dynamic>>(
        '/api/payments/installments',
        queryParameters: {
          'amount': params.amount.toStringAsFixed(2),
          'bin': params.bin,
        },
      );
      return response
          .map((e) => InstallmentOption.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      // Fallback: simple installments without fees
      return List.generate(12, (i) {
        final n = i + 1;
        final value = params.amount / n;
        return InstallmentOption(
          installments: n,
          installmentAmount: value,
          totalAmount: params.amount,
          recommendedMessage: n == 1
              ? '1x de R\$ ${value.toStringAsFixed(2)} (à vista)'
              : '${n}x de R\$ ${value.toStringAsFixed(2)}',
          interestFree: true,
        );
      });
    }
  },
);
