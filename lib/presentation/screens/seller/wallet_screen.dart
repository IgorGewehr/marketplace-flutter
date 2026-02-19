import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/transaction_model.dart';
import '../../providers/auth_providers.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/seller/wallet_balance_card.dart';
import '../../widgets/seller/transaction_tile.dart';

/// Wallet screen with balance and transaction history
class WalletScreen extends ConsumerWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(walletProvider);
    final transactionsAsync = ref.watch(walletTransactionsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.sellerAccent,
        onRefresh: () async {
          await ref.read(walletProvider.notifier).refresh();
          await ref.read(walletTransactionsProvider.notifier).refresh();
        },
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverAppBar(
              floating: true,
              backgroundColor: AppColors.background,
              elevation: 0,
              title: const Text(
                'Carteira',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            
            // Balance Card
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                child: walletAsync.when(
                  data: (wallet) => WalletBalanceCard(
                    availableBalance: wallet?.balance.available ?? 0,
                    pendingBalance: wallet?.balance.pending ?? 0,
                    blockedBalance: wallet?.balance.blocked ?? 0,
                    onWithdraw: () => _showWithdrawSheet(context, ref, wallet?.balance.available ?? 0),
                  ),
                  loading: () => const WalletBalanceCard(
                    availableBalance: 0,
                    isLoading: true,
                  ),
                  error: (_, __) => const WalletBalanceCard(
                    availableBalance: 0,
                  ),
                ),
              ),
            ),
            
            // Transaction History Header
            const SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Histórico',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            const SliverPadding(padding: EdgeInsets.only(top: 8)),
            
            // Transactions List
            transactionsAsync.when(
              data: (transactions) {
                if (transactions.isEmpty) {
                  return SliverPadding(
                    padding: const EdgeInsets.all(32),
                    sliver: SliverToBoxAdapter(
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              size: 64,
                              color: AppColors.textHint,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Nenhuma transação ainda',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final transaction = transactions[index];
                      return TransactionTile(
                        transaction: transaction,
                        onTap: () => _showTransactionDetails(context, transaction),
                      );
                    },
                    childCount: transactions.length,
                  ),
                );
              },
              loading: () => const SliverPadding(
                padding: EdgeInsets.all(32),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.sellerAccent),
                  ),
                ),
              ),
              error: (_, __) => const SliverPadding(
                padding: EdgeInsets.all(32),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: Text('Erro ao carregar transações'),
                  ),
                ),
              ),
            ),
            
            // Bottom padding
            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          ],
        ),
      ),
    );
  }

  void _showTransactionDetails(BuildContext context, TransactionModel transaction) {
    String typeLabel;
    IconData typeIcon;
    switch (transaction.type) {
      case 'sale':
        typeLabel = 'Venda';
        typeIcon = Icons.shopping_bag_outlined;
        break;
      case 'withdrawal':
        typeLabel = 'Saque';
        typeIcon = Icons.account_balance_wallet;
        break;
      case 'refund':
        typeLabel = 'Reembolso';
        typeIcon = Icons.replay;
        break;
      case 'fee':
        typeLabel = 'Taxa';
        typeIcon = Icons.receipt_long;
        break;
      default:
        typeLabel = transaction.type;
        typeIcon = Icons.attach_money;
    }

    String statusLabel;
    Color statusColor;
    switch (transaction.status) {
      case 'completed':
        statusLabel = 'Concluída';
        statusColor = AppColors.secondary;
        break;
      case 'pending':
        statusLabel = 'Pendente';
        statusColor = AppColors.warning;
        break;
      case 'failed':
        statusLabel = 'Falhou';
        statusColor = AppColors.error;
        break;
      default:
        statusLabel = transaction.status;
        statusColor = AppColors.textHint;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Type icon + label
            Icon(typeIcon, size: 40, color: AppColors.sellerAccent),
            const SizedBox(height: 8),
            Text(
              typeLabel,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),

            // Amount
            Text(
              '${transaction.isIncome ? '+' : '-'} ${Formatters.currency(transaction.netAmount.abs())}',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: transaction.isIncome ? AppColors.secondary : AppColors.error,
              ),
            ),
            const SizedBox(height: 4),

            // Status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Details
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _DetailRow(label: 'Descrição', value: transaction.description),
                  if (transaction.fee > 0)
                    _DetailRow(
                      label: 'Taxa',
                      value: '- ${Formatters.currency(transaction.fee)}',
                    ),
                  if (transaction.amount != transaction.netAmount)
                    _DetailRow(
                      label: 'Valor bruto',
                      value: Formatters.currency(transaction.amount),
                    ),
                  if (transaction.orderId != null)
                    _DetailRow(label: 'Pedido', value: '#${transaction.orderId!.substring(0, 8)}'),
                  if (transaction.metadata?.paymentMethod != null)
                    _DetailRow(label: 'Método', value: transaction.metadata!.paymentMethod!),
                  _DetailRow(
                    label: 'Data',
                    value: Formatters.dateTime(transaction.createdAt),
                  ),
                  _DetailRow(label: 'ID', value: transaction.id.substring(0, 12)),
                ],
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  void _showWithdrawSheet(BuildContext context, WidgetRef ref, double availableBalance) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WithdrawSheet(
        availableBalance: availableBalance,
        onWithdraw: (amount, pixKey) async {
          final success = await ref.read(walletProvider.notifier).requestWithdrawal(
            amount: amount,
            pixKey: pixKey,
          );
          return success;
        },
      ),
    );
  }
}

/// Bottom sheet for withdrawal
class WithdrawSheet extends ConsumerStatefulWidget {
  final double availableBalance;
  final Future<bool> Function(double amount, String pixKey) onWithdraw;

  const WithdrawSheet({
    super.key,
    required this.availableBalance,
    required this.onWithdraw,
  });

  @override
  ConsumerState<WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends ConsumerState<WithdrawSheet> {
  final _amountController = TextEditingController();
  bool _isLoading = false;
  bool _useFullBalance = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _handleWithdraw() async {
    final amount = _useFullBalance
        ? widget.availableBalance
        : double.tryParse(_amountController.text.replaceAll(',', '.'));

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe um valor válido'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (amount > widget.availableBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saldo insuficiente'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // Use user's phone or email as PIX key
    final user = ref.read(currentUserProvider).valueOrNull;
    final pixKey = user?.phone ?? user?.email ?? '';

    try {
      final success = await widget.onWithdraw(amount, pixKey);
      if (mounted) {
        if (success) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Saque solicitado com sucesso!'),
              backgroundColor: AppColors.secondary,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Erro ao solicitar saque'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomPadding),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Title
          const Text(
            'Sacar para PIX',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'O saque será enviado para o CPF do seu cadastro',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),

          // Available balance
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.secondary.withAlpha(15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet, color: AppColors.secondary),
                const SizedBox(width: 12),
                const Text(
                  'Saldo disponível:',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
                const Spacer(),
                Text(
                  'R\$ ${widget.availableBalance.toStringAsFixed(2).replaceAll('.', ',')}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Use full balance toggle
          CheckboxListTile(
            value: _useFullBalance,
            onChanged: (value) {
              setState(() {
                _useFullBalance = value ?? false;
                if (_useFullBalance) {
                  _amountController.text = widget.availableBalance.toStringAsFixed(2);
                }
              });
            },
            title: const Text('Sacar saldo total'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: AppColors.sellerAccent,
          ),

          // Amount field
          if (!_useFullBalance) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Valor do saque',
                prefixText: 'R\$ ',
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Withdraw button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _handleWithdraw,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.pix),
              label: const Text(
                'Solicitar Saque',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
