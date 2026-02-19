import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/order_model.dart';
import '../../providers/chat_provider.dart';
import '../../providers/seller_orders_provider.dart';
import '../../widgets/seller/order_actions.dart';

/// Order details screen with status updates and actions
class SellerOrderDetailsScreen extends ConsumerStatefulWidget {
  final String orderId;

  const SellerOrderDetailsScreen({super.key, required this.orderId});

  @override
  ConsumerState<SellerOrderDetailsScreen> createState() => _SellerOrderDetailsScreenState();
}

class _SellerOrderDetailsScreenState extends ConsumerState<SellerOrderDetailsScreen> {
  bool _isLoading = false;
  final _trackingController = TextEditingController();

  @override
  void dispose() {
    _trackingController.dispose();
    super.dispose();
  }

  Future<void> _updateStatus(String newStatus, {String? note}) async {
    setState(() => _isLoading = true);
    try {
      await ref.read(sellerOrdersProvider.notifier).updateOrderStatus(
        widget.orderId,
        newStatus,
        note: note,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Status atualizado!'),
            backgroundColor: AppColors.secondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showTrackingDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Código de rastreio'),
        content: TextField(
          controller: _trackingController,
          decoration: const InputDecoration(
            hintText: 'Ex: BR123456789XX',
            labelText: 'Código de rastreio',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              if (_trackingController.text.isNotEmpty) {
                await ref.read(sellerOrdersProvider.notifier).addTrackingCode(
                  widget.orderId,
                  _trackingController.text,
                );
                await _updateStatus('shipped', note: 'Rastreio: ${_trackingController.text}');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.sellerAccent,
            ),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(sellerOrdersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Detalhes do Pedido',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
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
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.sellerAccent),
        ),
        error: (_, __) => const Center(child: Text('Erro ao carregar')),
      ),
    );
  }

  Widget _buildContent(OrderModel order) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
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
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    _StatusBadge(status: order.status),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Pedido em ${_formatDate(order.createdAt)}',
                  style: const TextStyle(color: AppColors.textHint),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Items
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Itens do pedido',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
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
                        child: const Icon(
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
          ),
          const SizedBox(height: 16),

          // Delivery info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
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
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
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
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Status history
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Histórico',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
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
          ),
          const SizedBox(height: 24),

          // Actions
          OrderActions(
            currentStatus: order.status,
            isLoading: _isLoading,
            onAccept: () => _updateStatus('confirmed'),
            onStartPreparing: () => _updateStatus('preparing'),
            onMarkReady: () => _updateStatus('ready'),
            onShip: _showTrackingDialog,
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
    return 'R\$ ${price.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatDateTime(DateTime date) {
    return '${_formatDate(date)} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
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
