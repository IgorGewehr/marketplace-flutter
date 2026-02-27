import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/marketplace_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/transaction_model.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/seller/wallet_balance_card.dart';
import '../../widgets/shared/app_feedback.dart';

/// Wallet screen — informative only.
/// Shows held, released, and total earned amounts, plus transaction history.
/// Sellers manage withdrawals directly in the Mercado Pago app.
class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  Future<void> _openMercadoPagoApp() async {
    try {
      final mpDeeplink = Uri.parse('mercadopago://');
      if (await canLaunchUrl(mpDeeplink)) {
        await launchUrl(mpDeeplink);
      } else {
        final mpWebsite = Uri.parse('https://www.mercadopago.com.br');
        final launched = await launchUrl(mpWebsite, mode: LaunchMode.externalApplication);
        if (!launched && mounted) {
          AppFeedback.showError(context, 'Não foi possível abrir o Mercado Pago');
        }
      }
    } catch (e) {
      if (mounted) AppFeedback.showError(context, 'Erro ao abrir o Mercado Pago');
    }
  }

  @override
  Widget build(BuildContext context) {
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
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              title: const Text(
                'Carteira',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // MP info banner — prominent at top
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF009EE3).withAlpha(15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF009EE3).withAlpha(50)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                              'Seu dinheiro está no Mercado Pago',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'O valor das suas vendas é depositado automaticamente '
                              'na sua conta do Mercado Pago. '
                              'Gerencie seus saques diretamente no app do Mercado Pago.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _openMercadoPagoApp,
                                icon: const Icon(Icons.open_in_new, size: 16),
                                label: const Text('Abrir app Mercado Pago'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF009EE3),
                                  side: const BorderSide(
                                      color: Color(0xFF009EE3)),
                                ),
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

            // Balance Card (Total ganho = released + held)
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

            // Stat cards row: Aguardando entrega | Liberado
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: walletAsync.when(
                  data: (wallet) {
                    final held = wallet?.balance.pending ?? 0;
                    final released = wallet?.balance.available ?? 0;
                    return Row(
                      children: [
                        Expanded(
                          child: _InfoStatCard(
                            icon: Icons.schedule,
                            label: 'Aguardando entrega',
                            value: Formatters.currency(held),
                            animatedValue: held,
                            color: AppColors.warning,
                            tooltip:
                                'Valor retido enquanto a entrega não é confirmada',
                            subtitle: 'Aguardando confirmação de entrega',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _InfoStatCard(
                            icon: Icons.check_circle_outline,
                            label: 'Liberado',
                            value: Formatters.currency(released),
                            animatedValue: released,
                            color: AppColors.secondary,
                            tooltip:
                                'Valor já disponível na sua conta Mercado Pago',
                            subtitle: 'Disponível para saque no app MP',
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () => Row(
                    children: [
                      Expanded(
                          child: _InfoStatCard(
                        icon: Icons.schedule,
                        label: 'Aguardando entrega',
                        value: '-',
                        color: AppColors.warning,
                        isLoading: true,
                      )),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _InfoStatCard(
                        icon: Icons.check_circle_outline,
                        label: 'Liberado',
                        value: '-',
                        color: AppColors.secondary,
                        isLoading: true,
                      )),
                    ],
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),
            ),
            const SliverPadding(padding: EdgeInsets.only(top: 24)),

            // Transaction History Header
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Histórico de transações',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
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
                      return _TransactionRow(
                        transaction: transaction,
                        onTap: () =>
                            _showTransactionDetails(context, transaction),
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
                    child: CircularProgressIndicator(
                        color: AppColors.sellerAccent),
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

  void _showTransactionDetails(
      BuildContext context, TransactionModel transaction) {
    final splitStatus = transaction.metadata != null
        ? (transaction.status == 'pending'
            ? PaymentSplitStatus.held
            : PaymentSplitStatus.released)
        : null;

    String typeLabel;
    IconData typeIcon;
    switch (transaction.type) {
      case 'sale':
        typeLabel = 'Venda';
        typeIcon = Icons.shopping_bag_outlined;
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
    switch (splitStatus ?? transaction.status) {
      case PaymentSplitStatus.held:
      case 'pending':
        statusLabel = 'Aguardando entrega';
        statusColor = AppColors.warning;
        break;
      case PaymentSplitStatus.released:
      case 'completed':
        statusLabel = 'Liberado';
        statusColor = AppColors.secondary;
        break;
      case PaymentSplitStatus.refunded:
        statusLabel = 'Reembolsado';
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
                color:
                    transaction.isIncome ? AppColors.secondary : AppColors.error,
              ),
            ),
            const SizedBox(height: 4),

            // Status chip
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                  _DetailRow(
                      label: 'Descrição', value: transaction.description),
                  if (transaction.fee > 0)
                    _DetailRow(
                      label: 'Taxa da plataforma',
                      value: '- ${Formatters.currency(transaction.fee)}',
                    ),
                  if (transaction.amount != transaction.netAmount)
                    _DetailRow(
                      label: 'Valor bruto',
                      value: Formatters.currency(transaction.amount),
                    ),
                  if (transaction.orderId != null)
                    _DetailRow(
                        label: 'Pedido',
                        value:
                            '#${transaction.orderId!.substring(0, 8).toUpperCase()}'),
                  if (transaction.metadata?.paymentMethod != null)
                    _DetailRow(
                        label: 'Método',
                        value: transaction.metadata!.paymentMethod!),
                  _DetailRow(
                    label: 'Data',
                    value: Formatters.dateTime(transaction.createdAt),
                  ),
                  _DetailRow(
                      label: 'ID', value: transaction.id.substring(0, 12)),
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

/// Animated currency counter — counts up from 0 to [value] on first render.
class _AnimatedCurrencyText extends StatelessWidget {
  final double value;
  final TextStyle? style;

  const _AnimatedCurrencyText({required this.value, this.style});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      builder: (context, animatedValue, _) {
        return Text(
          Formatters.currency(animatedValue),
          style: style,
        );
      },
    );
  }
}

/// Small informational stat card (no action button)
class _InfoStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? tooltip;
  final String? subtitle;
  final bool isLoading;
  /// When provided, animates value from 0 → [animatedValue] using [_AnimatedCurrencyText]
  final double? animatedValue;

  const _InfoStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.tooltip,
    this.subtitle,
    this.isLoading = false,
    this.animatedValue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const Spacer(),
              if (tooltip != null)
                Tooltip(
                  message: tooltip!,
                  child: Icon(
                    Icons.info_outline,
                    size: 14,
                    color: AppColors.textHint,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textHint,
            ),
          ),
          const SizedBox(height: 2),
          isLoading
              ? Container(
                  width: 60,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                )
              : animatedValue != null
                  ? _AnimatedCurrencyText(
                      value: animatedValue!,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    )
                  : Text(
                      value,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
          if (!isLoading && subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textHint,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Transaction row in the history list
class _TransactionRow extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback onTap;

  const _TransactionRow({
    required this.transaction,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Map transaction status to split payment status
    String statusLabel;
    Color statusColor;
    IconData statusIcon;

    final isHeld = transaction.status == 'pending';
    final isRefund = transaction.type == 'refund';

    if (isRefund) {
      statusLabel = 'Reembolsado';
      statusColor = AppColors.error;
      statusIcon = Icons.replay;
    } else if (isHeld) {
      statusLabel = 'Aguardando entrega';
      statusColor = AppColors.warning;
      statusIcon = Icons.schedule;
    } else {
      statusLabel = 'Liberado';
      statusColor = AppColors.secondary;
      statusIcon = Icons.check_circle_outline;
    }

    final amountPrefix = transaction.isIncome ? '+' : '-';
    final amountColor =
        transaction.isIncome ? AppColors.secondary : AppColors.error;

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border.withAlpha(60)),
        ),
        child: Row(
          children: [
            // Status icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: statusColor.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(statusIcon, color: statusColor, size: 20),
            ),
            const SizedBox(width: 12),

            // Order info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.orderId != null
                        ? 'Pedido #${transaction.orderId!.substring(0, 8).toUpperCase()}'
                        : transaction.description,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withAlpha(15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        Formatters.date(transaction.createdAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$amountPrefix ${Formatters.currency(transaction.netAmount.abs())}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: amountColor,
                  ),
                ),
                if (transaction.fee > 0)
                  Text(
                    'Taxa: ${Formatters.currency(transaction.fee)}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textHint,
                    ),
                  ),
              ],
            ),
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
