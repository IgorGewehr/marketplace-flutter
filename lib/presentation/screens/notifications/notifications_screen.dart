import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/notification_model.dart';
import '../../providers/notifications_provider.dart';
import '../../widgets/notifications/notification_tile.dart';
import '../../widgets/shared/error_state.dart';
import '../../widgets/shared/illustrated_empty_state.dart';
import '../../widgets/shared/shimmer_loading.dart';

/// Filter types for notifications
enum NotificationFilter {
  all('Todas', null),
  orders('Pedidos', Icons.shopping_bag_outlined),
  messages('Mensagens', Icons.chat_bubble_outline),
  payments('Pagamentos', Icons.payments_outlined);

  final String label;
  final IconData? icon;
  const NotificationFilter(this.label, this.icon);
}

/// Enhanced notifications screen with date grouping and filters
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  NotificationFilter _activeFilter = NotificationFilter.all;

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notificações'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: () {
                ref.read(notificationsProvider.notifier).markAllAsRead();
              },
              child: const Text('Marcar todas'),
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          _buildFilterChips(),
          // Notification list
          Expanded(
            child: notificationsAsync.when(
              loading: () => const ShimmerLoading(itemCount: 5, isGrid: false, height: 80),
              error: (error, stack) => ErrorState(
                message: 'Erro ao carregar notificações',
                onRetry: () => ref.invalidate(notificationsProvider),
              ),
              data: (notifications) {
                final filtered = _filterNotifications(notifications);

                if (filtered.isEmpty) {
                  if (_activeFilter != NotificationFilter.all) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _activeFilter.icon ?? Icons.filter_list,
                            size: 48,
                            color: AppColors.textHint,
                          ),
                          const SizedBox(height: AppSpacing.m),
                          Text(
                            'Nenhuma notificação de ${_activeFilter.label.toLowerCase()}',
                            style: const TextStyle(
                              fontSize: 16,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return const _EnhancedEmptyNotificationsState();
                }

                // Group by date
                final groups = _groupByDate(filtered);

                return RefreshIndicator(
                  onRefresh: () => ref.read(notificationsProvider.notifier).refresh(),
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                    itemCount: _calculateTotalItems(groups),
                    itemBuilder: (context, index) {
                      return _buildGroupedItem(context, ref, groups, index);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Filter chips row
  Widget _buildFilterChips() {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.only(
        left: AppSpacing.m,
        right: AppSpacing.m,
        top: AppSpacing.s,
        bottom: AppSpacing.sm,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: NotificationFilter.values.map((filter) {
            final isSelected = _activeFilter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: AppSpacing.s),
              child: FilterChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (filter.icon != null) ...[
                      Icon(
                        filter.icon,
                        size: 16,
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                    ],
                    Text(filter.label),
                  ],
                ),
                selected: isSelected,
                onSelected: (_) => setState(() => _activeFilter = filter),
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.surfaceVariant,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : AppColors.border,
                    width: 1,
                  ),
                ),
                showCheckmark: false,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Apply filter to notifications
  List<NotificationModel> _filterNotifications(List<NotificationModel> notifications) {
    switch (_activeFilter) {
      case NotificationFilter.all:
        return notifications;
      case NotificationFilter.orders:
        return notifications.where((n) => n.isOrderRelated).toList();
      case NotificationFilter.messages:
        return notifications.where((n) => n.isMessageRelated).toList();
      case NotificationFilter.payments:
        return notifications.where((n) => n.isPaymentRelated).toList();
    }
  }

  /// Group notifications by date period
  Map<String, List<NotificationModel>> _groupByDate(List<NotificationModel> notifications) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));

    final groups = <String, List<NotificationModel>>{};

    for (final notification in notifications) {
      final notifDate = DateTime(
        notification.createdAt.year,
        notification.createdAt.month,
        notification.createdAt.day,
      );

      String group;
      if (notifDate == today) {
        group = 'Hoje';
      } else if (notifDate == yesterday) {
        group = 'Ontem';
      } else if (notifDate.isAfter(weekAgo)) {
        group = 'Esta semana';
      } else {
        group = 'Anteriores';
      }

      groups.putIfAbsent(group, () => []);
      groups[group]!.add(notification);
    }

    // Ensure order: Hoje, Ontem, Esta semana, Anteriores
    final ordered = <String, List<NotificationModel>>{};
    for (final key in ['Hoje', 'Ontem', 'Esta semana', 'Anteriores']) {
      if (groups.containsKey(key)) {
        ordered[key] = groups[key]!;
      }
    }

    return ordered;
  }

  /// Calculate total items (headers + notifications)
  int _calculateTotalItems(Map<String, List<NotificationModel>> groups) {
    int count = 0;
    for (final entry in groups.entries) {
      count += 1; // header
      count += entry.value.length;
    }
    return count;
  }

  /// Build grouped item (header or notification tile)
  Widget _buildGroupedItem(
    BuildContext context,
    WidgetRef ref,
    Map<String, List<NotificationModel>> groups,
    int index,
  ) {
    int currentIndex = 0;

    for (final entry in groups.entries) {
      // Header
      if (index == currentIndex) {
        return _buildSectionHeader(entry.key, entry.value.length);
      }
      currentIndex++;

      // Items
      for (int i = 0; i < entry.value.length; i++) {
        if (index == currentIndex) {
          final notification = entry.value[i];
          return Column(
            children: [
              NotificationTile(
                notification: notification,
                onTap: () => _handleNotificationTap(context, ref, notification),
                onMarkAsRead: () {
                  ref.read(notificationsProvider.notifier).markAsRead(notification.id);
                },
                onDelete: () {
                  ref.read(notificationsProvider.notifier).markAsRead(notification.id);
                },
              ),
              if (i < entry.value.length - 1)
                const Divider(height: 1, indent: 72, endIndent: 16),
            ],
          );
        }
        currentIndex++;
      }
    }

    return const SizedBox.shrink();
  }

  /// Date section header
  Widget _buildSectionHeader(String title, int count) {
    return Container(
      padding: const EdgeInsets.only(
        left: AppSpacing.m,
        right: AppSpacing.m,
        top: AppSpacing.m,
        bottom: AppSpacing.s,
      ),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: AppSpacing.s),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s,
              vertical: AppSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleNotificationTap(BuildContext context, WidgetRef ref, NotificationModel notification) {
    // Mark as read
    if (!notification.isRead) {
      ref.read(notificationsProvider.notifier).markAsRead(notification.id);
    }

    // Navigate based on type
    if (notification.isOrderRelated && notification.orderId != null) {
      context.push(
        AppRouter.orderDetails.replaceFirst(':id', notification.orderId!),
      );
    } else if (notification.isMessageRelated && notification.chatId != null) {
      context.push(
        AppRouter.chatDetails.replaceFirst(':id', notification.chatId!),
      );
    }
  }
}

/// Enhanced empty state with actionable CTA
class _EnhancedEmptyNotificationsState extends StatelessWidget {
  const _EnhancedEmptyNotificationsState();

  @override
  Widget build(BuildContext context) {
    return IllustratedEmptyState(
      icon: Icons.notifications_none_rounded,
      title: 'Nenhuma notificação',
      subtitle:
          'Explore produtos para receber alertas de promoções, atualizações de pedidos e mensagens.',
      actionLabel: 'Explorar produtos',
      onAction: () => context.go('/'),
    );
  }
}
