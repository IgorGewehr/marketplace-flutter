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
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user == null || !user.isSeller) return null;

    final repository = ref.read(walletRepositoryProvider);
    final wallet = await repository.getWallet();
    return wallet;
  }

  Future<void> refresh() async {
    state = const AsyncLoading<WalletModel?>().copyWithPrevious(state);
    state = await AsyncValue.guard(() => build());
  }
}

class WalletTransactionsNotifier extends AsyncNotifier<List<TransactionModel>> {
  @override
  Future<List<TransactionModel>> build() async {
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user == null || !user.isSeller) return [];

    final repository = ref.read(walletRepositoryProvider);
    final response = await repository.getTransactions();
    return response.transactions;
  }

  Future<void> refresh() async {
    state = const AsyncLoading<List<TransactionModel>>().copyWithPrevious(state);
    state = await AsyncValue.guard(() => build());
  }
}
