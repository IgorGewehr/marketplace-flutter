import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/notification_model.dart';

/// Enhanced notification tile widget with rich content
class NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback? onTap;
  final VoidCallback? onMarkAsRead;
  final VoidCallback? onDelete;

  const NotificationTile({
    super.key,
    required this.notification,
    this.onTap,
    this.onMarkAsRead,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(notification.id),
      // Bidirectional swipe: start = delete/archive (red), end = mark as read (green)
      direction: notification.isRead
          ? DismissDirection.startToEnd
          : DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          // Mark as read
          onMarkAsRead?.call();
          return false; // Don't actually dismiss, just mark as read
        } else {
          // Delete / archive
          return true;
        }
      },
      onDismissed: (_) => onDelete?.call(),
      background: Container(
        color: AppColors.error.withAlpha(20),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: AppSpacing.ml),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline_rounded, color: AppColors.error, size: AppSpacing.iconL),
            const SizedBox(width: AppSpacing.s),
            Text(
              'Excluir',
              style: TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        color: AppColors.secondary.withAlpha(20),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.ml),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Marcar como lida',
              style: TextStyle(
                color: AppColors.secondary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Icon(Icons.done_rounded, color: AppColors.secondary, size: AppSpacing.iconL),
          ],
        ),
      ),
      child: Material(
        color: notification.isRead
            ? Colors.transparent
            : AppColors.primary.withAlpha(12),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.m,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type icon with colored background
                _buildIcon(),
                const SizedBox(width: AppSpacing.sm),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title row with unread dot
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: notification.isRead
                                    ? FontWeight.w500
                                    : FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          if (!notification.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      // Body text
                      Text(
                        notification.body,
                        style: TextStyle(
                          fontSize: 14,
                          color: notification.isRead
                              ? AppColors.textHint
                              : AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // Order status progress bar for order_status_changed
                      if (notification.type == 'order_status_changed')
                        _buildOrderProgressBar(),
                      // Message preview for new_message
                      if (notification.type == 'new_message' && notification.data?['senderName'] != null)
                        _buildMessagePreview(),
                      const SizedBox(height: AppSpacing.xs + 2),
                      // Timestamp
                      Text(
                        _formatTimestamp(notification.createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textHint,
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
    );
  }

  Widget _buildIcon() {
    final color = _getIconColor();
    return Container(
      width: AppSpacing.touchTarget,
      height: AppSpacing.touchTarget,
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        shape: BoxShape.circle,
      ),
      child: Icon(
        _getIcon(),
        color: color,
        size: 22,
      ),
    );
  }

  /// Mini progress bar showing order fulfillment status
  Widget _buildOrderProgressBar() {
    final orderStatus = notification.data?['orderStatus'] as String?;
    final step = _getOrderStep(orderStatus);
    const totalSteps = 6;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusXS),
            child: LinearProgressIndicator(
              value: step / totalSteps,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(_getStatusColor(orderStatus)),
              minHeight: 4,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          // Status label
          Text(
            _getOrderStatusLabel(orderStatus),
            style: TextStyle(
              fontSize: 11,
              color: _getStatusColor(orderStatus),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Message preview with sender avatar
  Widget _buildMessagePreview() {
    final senderName = notification.data?['senderName'] as String? ?? '';
    final messagePreview = notification.data?['messagePreview'] as String?;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.s),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant.withAlpha(120),
          borderRadius: BorderRadius.circular(AppSpacing.radiusS),
        ),
        child: Row(
          children: [
            // Sender avatar
            CircleAvatar(
              radius: 14,
              backgroundColor: _getAvatarColor(senderName),
              child: Text(
                senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    senderName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (messagePreview != null)
                    Text(
                      messagePreview,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon() {
    switch (notification.type) {
      case 'order_created':
        return Icons.shopping_bag_outlined;
      case 'order_status_changed':
        return Icons.local_shipping_outlined;
      case 'new_message':
        return Icons.chat_bubble_outline;
      case 'payment_received':
        return Icons.payments_outlined;
      case 'withdrawal_completed':
        return Icons.account_balance_wallet_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _getIconColor() {
    switch (notification.type) {
      case 'order_created':
        return AppColors.secondary;
      case 'order_status_changed':
        return AppColors.primary;
      case 'new_message':
        return AppColors.info;
      case 'payment_received':
        return AppColors.secondary;
      case 'withdrawal_completed':
        return AppColors.secondary;
      default:
        return AppColors.textSecondary;
    }
  }

  int _getOrderStep(String? status) {
    switch (status) {
      case 'pending':
        return 1;
      case 'confirmed':
        return 2;
      case 'preparing':
        return 3;
      case 'ready':
        return 4;
      case 'shipped':
        return 5;
      case 'delivered':
        return 6;
      default:
        return 1;
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'pending':
        return AppColors.statusPending;
      case 'confirmed':
        return AppColors.statusConfirmed;
      case 'preparing':
        return AppColors.statusPreparing;
      case 'ready':
        return AppColors.statusReady;
      case 'shipped':
        return AppColors.statusShipped;
      case 'delivered':
        return AppColors.statusDelivered;
      case 'cancelled':
        return AppColors.statusCancelled;
      default:
        return AppColors.textHint;
    }
  }

  String _getOrderStatusLabel(String? status) {
    switch (status) {
      case 'pending':
        return 'Pedido pendente';
      case 'confirmed':
        return 'Pedido confirmado';
      case 'preparing':
        return 'Em preparação';
      case 'ready':
        return 'Pronto para envio';
      case 'shipped':
        return 'Enviado';
      case 'delivered':
        return 'Entregue';
      case 'cancelled':
        return 'Cancelado';
      default:
        return 'Processando';
    }
  }

  Color _getAvatarColor(String name) {
    if (name.isEmpty) return AppColors.textHint;
    final hash = name.codeUnits.fold<int>(0, (prev, c) => prev + c);
    final colors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.sellerAccent,
      AppColors.statusConfirmed,
      AppColors.statusPreparing,
      AppColors.statusReady,
      AppColors.statusShipped,
    ];
    return colors[hash % colors.length];
  }

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) {
      return 'agora';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} min';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h atrás';
    } else if (diff.inDays == 1) {
      return 'ontem';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} dias atrás';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
