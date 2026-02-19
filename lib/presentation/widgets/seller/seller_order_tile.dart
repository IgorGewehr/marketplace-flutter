import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/order_model.dart';

/// Order tile for seller's orders list
class SellerOrderTile extends StatelessWidget {
  final OrderModel order;
  final VoidCallback? onTap;

  const SellerOrderTile({
    super.key,
    required this.order,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isNew = order.status == 'pending';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isNew ? AppColors.sellerAccent : AppColors.border,
            width: isNew ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isNew
                  ? AppColors.sellerAccent.withAlpha(20)
                  : Colors.black.withAlpha(6),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                // Order number
                Text(
                  order.orderNumber,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                // Status badge
                _OrderStatusBadge(status: order.status),
              ],
            ),
            const SizedBox(height: 10),
            
            // Items preview
            Text(
              _getItemsPreview(),
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            
            // Footer row
            Row(
              children: [
                // Total
                Text(
                  _formatPrice(order.total),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.sellerAccent,
                  ),
                ),
                const Spacer(),
                // Time ago
                Text(
                  _getTimeAgo(),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textHint,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: AppColors.textHint,
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getItemsPreview() {
    if (order.items.isEmpty) return 'Sem itens';
    if (order.items.length == 1) {
      return '${order.items.first.quantity}x ${order.items.first.name}';
    }
    return '${order.items.first.name} + ${order.items.length - 1} item(s)';
  }

  String _formatPrice(double price) {
    return 'R\$ ${price.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  String _getTimeAgo() {
    final now = DateTime.now();
    final diff = now.difference(order.createdAt);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}min atrás';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h atrás';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d atrás';
    } else {
      return '${order.createdAt.day}/${order.createdAt.month}';
    }
  }
}

class _OrderStatusBadge extends StatelessWidget {
  final String status;

  const _OrderStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final config = _getStatusConfig();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: config.color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        config.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: config.color,
        ),
      ),
    );
  }

  _StatusConfig _getStatusConfig() {
    switch (status) {
      case 'pending':
        return _StatusConfig('Novo', AppColors.sellerAccent);
      case 'confirmed':
        return _StatusConfig('Confirmado', AppColors.statusConfirmed);
      case 'preparing':
        return _StatusConfig('Preparando', AppColors.statusPreparing);
      case 'ready':
        return _StatusConfig('Pronto', AppColors.statusReady);
      case 'shipped':
        return _StatusConfig('Enviado', AppColors.statusShipped);
      case 'delivered':
        return _StatusConfig('Entregue', AppColors.statusDelivered);
      case 'cancelled':
        return _StatusConfig('Cancelado', AppColors.statusCancelled);
      default:
        return _StatusConfig(status, AppColors.textSecondary);
    }
  }
}

class _StatusConfig {
  final String label;
  final Color color;

  _StatusConfig(this.label, this.color);
}
