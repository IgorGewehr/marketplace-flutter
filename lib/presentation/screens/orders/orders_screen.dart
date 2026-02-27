import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../providers/orders_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../widgets/orders/order_tile.dart';
import '../../widgets/shared/loading_overlay.dart';
import '../../widgets/shared/shimmer_loading.dart';

/// Orders list screen
class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ordersState = ref.watch(ordersProvider);
    final currentFilter = ordersState.valueOrNull?.filter ?? OrderFilter.all;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Meus Pedidos'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Filters
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _FilterChip(
                  label: 'Todos',
                  isSelected: currentFilter == OrderFilter.all,
                  onTap: () {
                    ref.read(ordersProvider.notifier).setFilter(OrderFilter.all);
                  },
                ),
                _FilterChip(
                  label: 'Em andamento',
                  isSelected: currentFilter == OrderFilter.pending,
                  onTap: () {
                    ref.read(ordersProvider.notifier).setFilter(OrderFilter.pending);
                  },
                ),
                _FilterChip(
                  label: 'Entregues',
                  isSelected: currentFilter == OrderFilter.delivered,
                  onTap: () {
                    ref.read(ordersProvider.notifier).setFilter(OrderFilter.delivered);
                  },
                ),
                _FilterChip(
                  label: 'Cancelados',
                  isSelected: currentFilter == OrderFilter.cancelled,
                  onTap: () {
                    ref.read(ordersProvider.notifier).setFilter(OrderFilter.cancelled);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Orders list
          Expanded(
            child: ordersState.when(
              loading: () => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const LoadingIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Carregando pedidos...',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              error: (_, __) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Erro ao carregar pedidos'),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () => ref.invalidate(ordersProvider),
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
              data: (data) {
                final displayOrders = data.filteredOrders;
                return RefreshIndicator(
                  color: Theme.of(context).colorScheme.primary,
                  onRefresh: () => ref.read(ordersProvider.notifier).refresh(),
                  child: displayOrders.isEmpty
                      ? SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: SizedBox(
                            height: MediaQuery.of(context).size.height * 0.6,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 32),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.shopping_bag_outlined,
                                      size: 80,
                                      color: AppColors.border,
                                    ).animate().scale(
                                          duration: 600.ms,
                                          curve: Curves.elasticOut,
                                        ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Nenhum pedido ainda',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Seus pedidos aparecerão aqui',
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                      textAlign: TextAlign.center,
                                    ).animate().fadeIn(delay: 500.ms, duration: 400.ms),
                                    const SizedBox(height: 24),
                                    FilledButton.icon(
                                      icon: const Icon(Icons.storefront_rounded),
                                      label: const Text('Explorar produtos'),
                                      onPressed: () => context.go(AppRouter.home),
                                    ).animate()
                                        .fadeIn(delay: 700.ms, duration: 400.ms)
                                        .slideY(begin: 0.3, delay: 700.ms, duration: 400.ms),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: displayOrders.length + (data.hasMore ? 1 : 0),
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            if (index >= displayOrders.length) {
                              ref.read(ordersProvider.notifier).loadMore();
                              return const ShimmerLoading(itemCount: 1, isGrid: false, height: 100);
                            }

                            return OrderTile(order: displayOrders[index]);
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
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        selectedColor: theme.colorScheme.primary,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        checkmarkColor: Colors.white,
        showCheckmark: false,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : theme.colorScheme.onSurface,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          fontSize: 13,
        ),
        side: BorderSide(
          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline,
        ),
      ),
    );
  }
}
