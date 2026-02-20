import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/transaction_model.dart';
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
              title: Text(
                'Carteira',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
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
            
            // MP info banner
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF009EE3).withAlpha(15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF009EE3).withAlpha(40)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF009EE3).withAlpha(30),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet,
                          color: Color(0xFF009EE3),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Saques via Mercado Pago',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Para sacar seu saldo, use o aplicativo do Mercado Pago. '
                              'O dinheiro das vendas é depositado automaticamente na sua conta MP.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SliverPadding(padding: EdgeInsets.only(top: 16)),

            // Transaction History Header
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: Builder(builder: (context) => Text(
                  'Histórico',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                )),
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
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
