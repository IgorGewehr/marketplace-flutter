import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/wallet_model.dart';
import '../../data/models/transaction_model.dart';
import 'auth_providers.dart';
import 'core_providers.dart';

/// Provider for wallet data
final walletProvider = AsyncNotifierProvider<WalletNotifier, WalletModel?>(() {
  return WalletNotifier();
});

/// Provider for wallet transactions
final walletTransactionsProvider = AsyncNotifierProvider<WalletTransactionsNotifier, List<TransactionModel>>(() {
  return WalletTransactionsNotifier();
});

/// Convenient balance provider
final walletBalanceProvider = Provider<WalletBalance?>((ref) {
  final wallet = ref.watch(walletProvider).valueOrNull;
  return wallet?.balance;
});

/// Available balance amount provider
final availableBalanceProvider = Provider<double>((ref) {
  final balance = ref.watch(walletBalanceProvider);
  return balance?.available ?? 0.0;
});

class WalletNotifier extends AsyncNotifier<WalletModel?> {
  @override
  Future<WalletModel?> build() async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null || !user.isSeller) return null;

    try {
      final repository = ref.read(walletRepositoryProvider);
      final wallet = await repository.getWallet();
      return wallet;
    } catch (e) {
      // If wallet doesn't exist yet, return null
      return null;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }

  Future<bool> requestWithdrawal({
    required double amount,
    required String pixKey,
    String? pixKeyType,
  }) async {
    if (amount <= 0) return false;
    if (pixKey.isEmpty) return false;
    if (amount > (state.valueOrNull?.balance.available ?? 0)) return false;

    try {
      final repository = ref.read(walletRepositoryProvider);

      await repository.requestWithdrawal(
        amount: amount,
        pixKey: pixKey,
        pixKeyType: pixKeyType,
      );

      // Refresh wallet data
      await refresh();

      // Refresh transactions
      ref.invalidate(walletTransactionsProvider);

      return true;
    } catch (e) {
      return false;
    }
  }
}

class WalletTransactionsNotifier extends AsyncNotifier<List<TransactionModel>> {
  @override
  Future<List<TransactionModel>> build() async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null || !user.isSeller) return [];

    try {
      final repository = ref.read(walletRepositoryProvider);
      final response = await repository.getTransactions();
      return response.transactions;
    } catch (e) {
      return [];
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }
}
