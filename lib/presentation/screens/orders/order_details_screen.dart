import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/order_model.dart';
import '../../providers/orders_provider.dart';
import '../../providers/review_provider.dart';
import '../../widgets/orders/order_timeline.dart';
import '../../widgets/reviews/reviews_bottom_sheet.dart';
import '../../widgets/shared/app_feedback.dart';
import '../../widgets/shared/error_state.dart';
import '../../widgets/shared/shimmer_loading.dart';

/// Order details screen
class OrderDetailsScreen extends ConsumerStatefulWidget {
  final String orderId;

  const OrderDetailsScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends ConsumerState<OrderDetailsScreen> {
  bool _isConfirming = false;
  bool _isCancelling = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final orderAsync = ref.watch(orderDetailProvider(widget.orderId));

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Detalhes do Pedido'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: orderAsync.when(
        loading: () => const _OrderDetailShimmer(),
        error: (error, _) => ErrorState(
          icon: Icons.receipt_long_rounded,
          message: 'Erro ao carregar detalhes do pedido.',
          onRetry: () => ref.invalidate(orderDetailProvider(widget.orderId)),
        ),
        data: (order) {
          if (order == null) {
            return const Center(child: Text('Pedido não encontrado'));
          }

          final statusInfo = getOrderStatusInfo(order.status);

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              ref.invalidate(orderDetailProvider(widget.orderId));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.shopping_bag_outlined,
                          color: theme.colorScheme.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '#${order.id.substring(0, 8).toUpperCase()}',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: order.id));
                                    AppFeedback.showInfo(context, 'ID copiado!');
                                  },
                                  child: Icon(
                                    Icons.copy,
                                    size: 16,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              Formatters.dateTime(order.createdAt),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      OrderStatusChip(
                        statusInfo: statusInfo,
                        status: order.status,
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.05, duration: 400.ms),

                const SizedBox(height: 16),

                // Timeline
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Status do pedido',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: OrderTimeline(order: order),
                    ),
                  ],
                )
                    .animate()
                    .fadeIn(delay: 100.ms, duration: 400.ms)
                    .slideY(begin: 0.05, duration: 400.ms),

                const SizedBox(height: 16),

                // Items
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Itens do pedido',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: order.items.map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: item.imageUrl != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        item.imageUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Icon(
                                          Icons.broken_image_outlined,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    )
                                  : const Icon(Icons.image_outlined),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${item.quantity}x ${Formatters.currency(item.unitPrice)}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              Formatters.currency(item.total),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                      ),
                    ),
                  ],
                )
                    .animate()
                    .fadeIn(delay: 200.ms, duration: 400.ms)
                    .slideY(begin: 0.05, duration: 400.ms),

                const SizedBox(height: 16),

                // Delivery address — only show when address is present
                if (order.deliveryAddress != null) ...[
                  Text(
                    'Endereço informado',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.location_on_outlined,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${order.deliveryAddress!.street}, ${order.deliveryAddress!.number}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${order.deliveryAddress!.neighborhood} - ${order.deliveryAddress!.city}/${order.deliveryAddress!.state}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                'CEP: ${order.deliveryAddress!.zipCode}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Tracking info
                if (order.trackingCode != null && order.trackingCode!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Referência do pedido',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.inventory_2_outlined,
                                color: theme.colorScheme.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (order.shippingCompany != null && order.shippingCompany!.isNotEmpty)
                                    Text(
                                      order.shippingCompany!,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  Text(
                                    order.trackingCode!,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.copy,
                                size: 18,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: order.trackingCode!));
                                AppFeedback.showInfo(context, 'Código copiado!');
                              },
                              tooltip: 'Copiar código',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Payment summary
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Resumo do pagamento',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _SummaryRow(
                        label: 'Subtotal',
                        value: Formatters.currency(order.subtotal),
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            Formatters.currency(order.total),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Pagamento',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            order.paymentMethod,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      if (order.paymentStatus == 'paid' &&
                          order.paymentSplit != null &&
                          (order.paymentSplit!.status == 'held' ||
                              order.paymentSplit!.status == 'released')) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            order.paymentSplit!.status == 'released'
                                ? const Icon(
                                    Icons.check_circle_outline,
                                    size: 16,
                                    color: Colors.green,
                                  )
                                : Icon(
                                    Icons.lock_clock_outlined,
                                    size: 16,
                                    color: Colors.amber[700],
                                  ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                order.paymentSplit!.status == 'released'
                                    ? 'Pagamento liberado ao vendedor'
                                    : 'Aguardando confirmação de entrega',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: order.paymentSplit!.status == 'released'
                                      ? Colors.green
                                      : Colors.amber[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                    ),
                  ),
                  ],
                )
                    .animate()
                    .fadeIn(delay: 300.ms, duration: 400.ms)
                    .slideY(begin: 0.05, duration: 400.ms),

                // Buyer actions: Confirm delivery or Report problem
                if ((order.status == 'shipped' || order.status == 'out_for_delivery') &&
                    !order.isDeliveryConfirmed &&
                    order.paymentStatus == 'paid')
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Column(
                      children: [
                        // A4: Auto-confirmation deadline banner
                        Builder(builder: (context) {
                          final shippedHistory = order.statusHistory
                              .where((h) => h.status == 'shipped')
                              .toList();
                          final shippedAt = shippedHistory.isNotEmpty
                              ? shippedHistory.last.timestamp
                              : null;
                          final int remainingDays;
                          if (shippedAt != null) {
                            final deadline = shippedAt.add(const Duration(days: 7));
                            remainingDays = deadline.difference(DateTime.now()).inDays.clamp(0, 7);
                          } else {
                            remainingDays = 7;
                          }
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.amber[50],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.amber.shade300),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.schedule_outlined, size: 18, color: Colors.amber[800]),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Confirmação automática em $remainingDays ${remainingDays == 1 ? 'dia' : 'dias'}',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.amber[900],
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Se você não confirmar o recebimento, o pagamento será liberado automaticamente.',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: Colors.amber[800],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _isConfirming ? null : () async {
                              HapticFeedback.mediumImpact();
                              final confirmed = await AppFeedback.showConfirmation(
                                context,
                                title: 'Confirmar recebimento',
                                message: 'Confirma que recebeu o pedido em boas condições?',
                                confirmText: 'Confirmar',
                              );
                              if (!confirmed || !context.mounted) return;

                              setState(() => _isConfirming = true);
                              try {
                                final success = await ref.read(ordersProvider.notifier).confirmDelivery(order.id);
                                if (context.mounted) {
                                  if (success) {
                                    // A5: Inform buyer about payment release timeline
                                    AppFeedback.showSuccess(
                                      context,
                                      'Recebimento confirmado! O pagamento será liberado ao vendedor em até 24 horas.',
                                    );
                                    ref.invalidate(orderDetailProvider(widget.orderId));
                                  } else {
                                    AppFeedback.showError(context, 'Erro ao confirmar recebimento');
                                  }
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  AppFeedback.showError(context, 'Erro ao confirmar recebimento');
                                }
                              } finally {
                                if (mounted) setState(() => _isConfirming = false);
                              }
                            },
                            icon: _isConfirming
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.check_circle_outline),
                            label: Text(_isConfirming ? 'Confirmando...' : 'Confirmar recebimento'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: Colors.green,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // M3: Dispute button with deadline subtitle
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _showDisputeDialog(context, ref, order.id),
                            icon: const Icon(Icons.report_problem_outlined),
                            label: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('Reportar problema'),
                                Builder(builder: (context) {
                                  final shippedHistory = order.statusHistory
                                      .where((h) => h.status == 'shipped')
                                      .toList();
                                  final shippedAt = shippedHistory.isNotEmpty
                                      ? shippedHistory.last.timestamp
                                      : null;
                                  if (shippedAt != null) {
                                    final deadline = shippedAt.add(const Duration(days: 7));
                                    final remaining = deadline.difference(DateTime.now()).inDays.clamp(0, 7);
                                    return Text(
                                      'Você tem $remaining ${remaining == 1 ? 'dia' : 'dias'} para reportar um problema',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: remaining <= 1 ? Colors.red : Colors.orange,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    );
                                  }
                                  return Text(
                                    'Disponível por 7 dias após o envio',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  );
                                }),
                              ],
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              foregroundColor: theme.colorScheme.error,
                              side: BorderSide(color: theme.colorScheme.error.withAlpha(128)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // D3: Delivery confirmed card
                if (order.isDeliveryConfirmed)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.withAlpha(60)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Recebimento confirmado',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green.shade800,
                                  ),
                                ),
                                Text(
                                  Formatters.dateTime(order.deliveryConfirmedAt!),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Review prompt — shown for delivered, paid orders
                if (order.isDeliveryConfirmed && order.paymentStatus == 'paid' && order.items.isNotEmpty)
                  _OrderReviewSection(order: order),

                // Cancel order button — only show for pending/pending_payment orders
                if ((order.status == 'pending' || order.status == 'pending_payment') &&
                    order.paymentStatus != 'paid')
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isCancelling
                            ? null
                            : () => _showCancelOrderDialog(
                                  context,
                                  ref,
                                  order.id,
                                  () => setState(() => _isCancelling = true),
                                  () {
                                    if (mounted) setState(() => _isCancelling = false);
                                  },
                                ),
                        icon: _isCancelling
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.cancel_outlined),
                        label: Text(_isCancelling ? 'Cancelando...' : 'Cancelar pedido'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          foregroundColor: theme.colorScheme.error,
                          side: BorderSide(color: theme.colorScheme.error.withAlpha(128)),
                        ),
                      ),
                    ),
                  ),

                // Help button
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () {
                      final uri = Uri.parse(
                        'https://wa.me/${AppConstants.supportWhatsAppPhone}?text='
                        '${Uri.encodeComponent('Olá, preciso de ajuda com o pedido #${order.id.substring(0, 8).toUpperCase()}')}',
                      );
                      launchUrl(uri, mode: LaunchMode.externalApplication);
                    },
                    icon: const Icon(Icons.help_outline),
                    label: const Text('Precisa de ajuda?'),
                  ),
                ),

                // Bottom padding
                const SizedBox(height: 32),
              ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============================================================================
// Order Review Section
// ============================================================================

class _OrderReviewSection extends ConsumerWidget {
  final OrderModel order;

  const _OrderReviewSection({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final reviewedAsync = ref.watch(reviewedProductIdsProvider(order.id));

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.rate_review_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'Avaliar compra',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outlineVariant.withAlpha(80)),
            ),
            child: Column(
              children: List.generate(order.items.length, (i) {
                final item = order.items[i];
                final reviewedIds = reviewedAsync.valueOrNull ?? {};
                final alreadyReviewed = reviewedIds.contains(item.productId);

                return Column(
                  children: [
                    if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          // Product image
                          if (item.imageUrl != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                item.imageUrl!,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.image_outlined, size: 20),
                                ),
                              ),
                            )
                          else
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.image_outlined, size: 20),
                            ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              item.name,
                              style: theme.textTheme.bodyMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Review button or checkmark
                          if (alreadyReviewed)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.green.withAlpha(20),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.green.withAlpha(60)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle_outline, size: 14, color: Colors.green),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Avaliado',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            TextButton(
                              onPressed: () {
                                ref.read(reviewSubmitProvider.notifier).reset();
                                showSubmitReviewSheet(
                                  context,
                                  productId: item.productId,
                                  tenantId: order.tenantId,
                                  orderId: order.id,
                                  productName: item.name,
                                  productImageUrl: item.imageUrl,
                                  onSuccess: () {
                                    AppFeedback.showSuccess(
                                      context,
                                      'Avaliação enviada! Obrigado pelo feedback.',
                                    );
                                    ref.invalidate(reviewedProductIdsProvider(order.id));
                                  },
                                );
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star_outline_rounded, size: 16),
                                  SizedBox(width: 4),
                                  Text('Avaliar', style: TextStyle(fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

void _showCancelOrderDialog(
  BuildContext context,
  WidgetRef ref,
  String orderId,
  VoidCallback onCancelling,
  VoidCallback onDone,
) {
  final controller = TextEditingController();

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Cancelar pedido'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tem certeza que deseja cancelar este pedido? O pedido ainda não foi processado pelo vendedor.',
            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
              color: Theme.of(ctx).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            maxLines: 2,
            maxLength: 200,
            decoration: const InputDecoration(
              hintText: 'Motivo do cancelamento (opcional)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Voltar'),
        ),
        FilledButton(
          onPressed: () async {
            HapticFeedback.heavyImpact();
            Navigator.of(ctx).pop();
            onCancelling();
            final success = await ref.read(ordersProvider.notifier).cancelOrder(
              orderId,
              reason: controller.text.trim().isEmpty ? null : controller.text.trim(),
            );
            onDone();
            if (context.mounted) {
              if (success) {
                AppFeedback.showSuccess(context, 'Pedido cancelado com sucesso');
                ref.invalidate(orderDetailProvider(orderId));
              } else {
                AppFeedback.showError(context, 'Erro ao cancelar pedido. Tente novamente.');
              }
            }
          },
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
          ),
          child: const Text('Confirmar cancelamento'),
        ),
      ],
    ),
  ).whenComplete(() => controller.dispose());
}

void _showDisputeDialog(BuildContext context, WidgetRef ref, String orderId) {
  final controller = TextEditingController();

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Reportar problema'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Descreva o problema encontrado. Se confirmado, o pagamento será estornado.',
            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
              color: Theme.of(ctx).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller,
            maxLines: 3,
            maxLength: 500,
            decoration: const InputDecoration(
              hintText: 'Ex: Produto não recebido, item danificado...',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () async {
            final reason = controller.text.trim();
            if (reason.isEmpty) return;
            Navigator.of(ctx).pop();

            final success = await ref.read(ordersProvider.notifier).disputeOrder(
              orderId,
              reason: reason,
            );

            if (context.mounted) {
              if (success) {
                AppFeedback.showSuccess(context, 'Disputa aberta. O pagamento será estornado.');
                ref.invalidate(orderDetailProvider(orderId));
              } else {
                AppFeedback.showError(context, 'Erro ao abrir disputa');
              }
            }
          },
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
          ),
          child: const Text('Enviar disputa'),
        ),
      ],
    ),
  ).whenComplete(() => controller.dispose());
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

/// Animated status chip for orders.
///
/// Active statuses (pending, confirmed, preparing, processing, shipped,
/// out_for_delivery) pulse gently to draw attention.
/// Terminal statuses (delivered, cancelled, refunded) are rendered statically.
class OrderStatusChip extends StatelessWidget {
  final OrderStatusInfo statusInfo;
  final String status;

  const OrderStatusChip({
    super.key,
    required this.statusInfo,
    required this.status,
  });

  static const _activeStatuses = {
    'pending',
    'pending_payment',
    'confirmed',
    'preparing',
    'processing',
    'ready',
    'shipped',
    'out_for_delivery',
  };

  bool get _isActive => _activeStatuses.contains(status);

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusInfo.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: statusInfo.textColor.withAlpha(60),
          width: 1,
        ),
      ),
      child: Text(
        statusInfo.label,
        style: TextStyle(
          color: statusInfo.textColor,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );

    if (!_isActive) return chip;

    // Pulse glow + subtle shimmer for active statuses
    return chip
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .custom(
          duration: 900.ms,
          curve: Curves.easeInOut,
          builder: (_, value, child) => Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: statusInfo.textColor.withAlpha(
                    (40 * value).round(),
                  ),
                  blurRadius: 8 * value,
                  spreadRadius: 1 * value,
                ),
              ],
            ),
            child: child,
          ),
        )
        .shimmer(
          duration: 2000.ms,
          color: statusInfo.textColor.withAlpha(30),
        );
  }
}

/// Shimmer skeleton for order details loading state
class _OrderDetailShimmer extends StatelessWidget {
  const _OrderDetailShimmer();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order status timeline placeholder
          const ShimmerBox(width: double.infinity, height: 100, borderRadius: BorderRadius.all(Radius.circular(12))),
          const SizedBox(height: 20),
          // Address card placeholder
          const ShimmerBox(width: 140, height: 18),
          const SizedBox(height: 12),
          const ShimmerBox(width: double.infinity, height: 80, borderRadius: BorderRadius.all(Radius.circular(12))),
          const SizedBox(height: 24),
          // Items section placeholder
          const ShimmerBox(width: 100, height: 18),
          const SizedBox(height: 12),
          const ShimmerBox(width: double.infinity, height: 90, borderRadius: BorderRadius.all(Radius.circular(12))),
          const SizedBox(height: 10),
          const ShimmerBox(width: double.infinity, height: 90, borderRadius: BorderRadius.all(Radius.circular(12))),
          const SizedBox(height: 24),
          // Payment info placeholder
          const ShimmerBox(width: 160, height: 18),
          const SizedBox(height: 12),
          const ShimmerBox(width: double.infinity, height: 60, borderRadius: BorderRadius.all(Radius.circular(12))),
          const SizedBox(height: 24),
          // Action buttons placeholder
          const ShimmerBox(width: double.infinity, height: 48, borderRadius: BorderRadius.all(Radius.circular(12))),
        ],
      ),
    );
  }
}
