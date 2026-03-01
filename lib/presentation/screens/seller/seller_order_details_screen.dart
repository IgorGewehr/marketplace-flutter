import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/order_model.dart';
import '../../../core/utils/formatters.dart';
import '../../providers/chat_provider.dart';
import '../../providers/seller_orders_provider.dart';
import '../../widgets/seller/order_actions.dart';
import '../../widgets/shared/app_feedback.dart';

/// Order details screen with status updates and actions
class SellerOrderDetailsScreen extends ConsumerStatefulWidget {
  final String orderId;

  const SellerOrderDetailsScreen({super.key, required this.orderId});

  @override
  ConsumerState<SellerOrderDetailsScreen> createState() => _SellerOrderDetailsScreenState();
}

class _SellerOrderDetailsScreenState extends ConsumerState<SellerOrderDetailsScreen> {
  bool _isLoading = false;

  Future<void> _updateStatus(String newStatus, {String? note}) async {
    setState(() => _isLoading = true);
    try {
      await ref.read(sellerOrdersProvider.notifier).updateOrderStatus(
        widget.orderId,
        newStatus,
        note: note,
      );
      if (mounted) {
        AppFeedback.showSuccess(context, 'Status atualizado!');
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.showError(context, 'Erro ao atualizar status. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(sellerOrdersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Detalhes do Pedido',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ordersAsync.when(
        data: (orders) {
          final order = orders.where((o) => o.id == widget.orderId).firstOrNull;
          if (order == null) {
            return const Center(child: Text('Pedido não encontrado'));
          }
          return _buildContent(order);
        },
        loading: () => _buildShimmer(context),
        error: (_, __) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withAlpha(15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline_rounded, size: 40, color: AppColors.error),
              ),
              const SizedBox(height: 16),
              const Text('Erro ao carregar pedido', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => ref.invalidate(sellerOrdersProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(OrderModel order) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      order.orderNumber,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const Spacer(),
                    _StatusBadge(status: order.status),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Pedido em ${_formatDate(order.createdAt)}',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, curve: Curves.easeOut),
          const SizedBox(height: 16),

          // Items
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Itens do pedido',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                // Gap #9: Show product images instead of generic icon
                ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  item.imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.shopping_bag_outlined,
                                    color: AppColors.textHint,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.shopping_bag_outlined,
                                color: AppColors.textHint,
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              '${item.quantity}x ${_formatPrice(item.unitPrice)}',
                              style: const TextStyle(
                                color: AppColors.textHint,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        _formatPrice(item.total),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                )),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal'),
                    Text(_formatPrice(order.subtotal)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      _formatPrice(order.total),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: AppColors.sellerAccent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(delay: 100.ms, duration: 300.ms).slideY(begin: 0.05, curve: Curves.easeOut),
          const SizedBox(height: 16),

          // Delivery info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      order.deliveryType == 'pickup'
                          ? Icons.store
                          : Icons.local_shipping,
                      color: AppColors.sellerAccent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      order.deliveryType == 'pickup'
                          ? 'Retirada na loja'
                          : 'Entrega',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                if (order.deliveryAddress != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    '${order.deliveryAddress!.street}, ${order.deliveryAddress!.number}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  Text(
                    '${order.deliveryAddress!.neighborhood} - ${order.deliveryAddress!.city}/${order.deliveryAddress!.state}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  Text(
                    'CEP: ${order.deliveryAddress!.zipCode}',
                    style: const TextStyle(color: AppColors.textHint),
                  ),
                ],
                // Simplified delivery info for seller
                const Divider(height: 24),
                _DeliveryInfoRow(
                  label: 'Tipo',
                  value: order.deliveryType == 'pickup' || order.deliveryType == 'pickup_in_person'
                      ? 'Retirada na loja'
                      : order.deliveryType == 'seller_arranges'
                          ? 'Combinar com comprador'
                          : 'Entrega pela plataforma',
                ),
                if (order.deliveryAddress != null)
                  _DeliveryInfoRow(
                    label: 'Destino',
                    value: '${order.deliveryAddress!.city}/${order.deliveryAddress!.state}',
                  ),
                // Delivery status visual
                const SizedBox(height: 12),
                _SellerDeliveryStatus(order: order),
                if (order.sellerReadyAt != null)
                  _DeliveryInfoRow(label: 'Pronto para coleta', value: _formatDateTime(order.sellerReadyAt!)),
                if (order.collectedAt != null)
                  _DeliveryInfoRow(label: 'Coletado', value: _formatDateTime(order.collectedAt!)),
              ],
            ),
          ).animate().fadeIn(delay: 200.ms, duration: 300.ms).slideY(begin: 0.05, curve: Curves.easeOut),
          const SizedBox(height: 16),

          // Status history
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Histórico',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                ...order.statusHistory.reversed.map((history) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.sellerAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getStatusLabel(history.status),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            if (history.note != null)
                              Text(
                                history.note!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textHint,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        _formatDateTime(history.timestamp),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ).animate().fadeIn(delay: 300.ms, duration: 300.ms).slideY(begin: 0.05, curve: Curves.easeOut),
          // Seller amount only
          if (order.paymentSplit != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.payments_outlined, color: AppColors.sellerAccent),
                      const SizedBox(width: 8),
                      const Text('Seu valor', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  Text(
                    _formatPrice(order.paymentSplit!.sellerAmount),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Actions
          OrderActions(
            currentStatus: order.status,
            isLoading: _isLoading,
            onAccept: () => _updateStatus('confirmed'),
            onStartPreparing: () => _updateStatus('preparing'),
            onMarkReady: () => _updateStatus('ready'),
            onChat: () async {
              final chat = await ref.read(chatsProvider.notifier).getOrCreateChat(
                order.tenantId,
                orderId: order.id,
              );
              if (chat != null && mounted) {
                context.push('/chats/${chat.id}');
              }
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  String _formatPrice(double price) {
    return Formatters.currency(price);
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatDateTime(DateTime date) {
    return '${_formatDate(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildShimmer(BuildContext context) {
    final theme = Theme.of(context);
    return Shimmer.fromColors(
      baseColor: theme.colorScheme.surfaceContainerHighest,
      highlightColor: theme.colorScheme.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _shimmerCard(height: 90),
            const SizedBox(height: 16),
            _shimmerCard(height: 200),
            const SizedBox(height: 16),
            _shimmerCard(height: 120),
            const SizedBox(height: 16),
            _shimmerCard(height: 150),
          ],
        ),
      ),
    );
  }

  Widget _shimmerCard({required double height}) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'pending': return 'Pedido recebido';
      case 'confirmed': return 'Confirmado';
      case 'preparing': return 'Em preparo';
      case 'ready': return 'Pronto para envio';
      case 'shipped': return 'Enviado';
      case 'delivered': return 'Entregue';
      case 'cancelled': return 'Cancelado';
      default: return status;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    switch (status) {
      case 'pending':
        color = AppColors.sellerAccent;
        label = 'Novo';
        break;
      case 'confirmed':
        color = AppColors.statusConfirmed;
        label = 'Confirmado';
        break;
      case 'preparing':
        color = AppColors.statusPreparing;
        label = 'Preparando';
        break;
      case 'ready':
        color = AppColors.statusReady;
        label = 'Pronto';
        break;
      case 'shipped':
        color = AppColors.statusShipped;
        label = 'Enviado';
        break;
      case 'delivered':
        color = AppColors.statusDelivered;
        label = 'Entregue';
        break;
      case 'cancelled':
        color = AppColors.statusCancelled;
        label = 'Cancelado';
        break;
      default:
        color = AppColors.textHint;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
    );
  }
}

class _DeliveryInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _DeliveryInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.textHint),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

/// Delivery status visual for seller
class _SellerDeliveryStatus extends StatelessWidget {
  final OrderModel order;

  const _SellerDeliveryStatus({required this.order});

  @override
  Widget build(BuildContext context) {
    final steps = <_DeliveryStep>[
      _DeliveryStep('Aguardando preparo', _isStepDone(0), _isStepActive(0)),
      _DeliveryStep('Pronto', _isStepDone(1), _isStepActive(1)),
      _DeliveryStep('Coletado', _isStepDone(2), _isStepActive(2)),
      _DeliveryStep('Em trânsito', _isStepDone(3), _isStepActive(3)),
      _DeliveryStep('Entregue', _isStepDone(4), _isStepActive(4)),
    ];

    return Row(
      children: steps.asMap().entries.expand((entry) {
        final i = entry.key;
        final step = entry.value;
        final widgets = <Widget>[
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: step.done
                      ? AppColors.primary
                      : step.active
                          ? AppColors.sellerAccent
                          : AppColors.border,
                ),
                child: step.done
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 50,
                child: Text(
                  step.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: step.active ? FontWeight.bold : FontWeight.normal,
                    color: step.done || step.active ? AppColors.textPrimary : AppColors.textHint,
                  ),
                ),
              ),
            ],
          ),
        ];
        if (i < steps.length - 1) {
          widgets.add(Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.only(bottom: 16),
              color: step.done ? AppColors.primary : AppColors.border,
            ),
          ));
        }
        return widgets;
      }).toList(),
    );
  }

  int get _currentStep {
    if (order.status == 'delivered') return 4;
    if (order.deliveryStatus == 'in_transit') return 3;
    if (order.deliveryStatus == 'collected' || order.status == 'shipped') return 2;
    if (order.status == 'ready') return 1;
    if (order.status == 'preparing') return 0;
    return -1;
  }

  bool _isStepDone(int step) => step <= _currentStep;
  bool _isStepActive(int step) => step == _currentStep;
}

class _DeliveryStep {
  final String label;
  final bool done;
  final bool active;

  _DeliveryStep(this.label, this.done, this.active);
}
