import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/orders_provider.dart';
import '../../widgets/orders/order_tile.dart';
import '../../widgets/shared/empty_state.dart';
import '../../widgets/shared/loading_overlay.dart';

/// Orders list screen
class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ordersState = ref.watch(ordersProvider);
    final selectedFilter = ref.watch(ordersFilterProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Meus Pedidos'),
        backgroundColor: theme.colorScheme.surface,
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
                  isSelected: selectedFilter == null,
                  onTap: () {
                    ref.read(ordersFilterProvider.notifier).state = null;
                  },
                ),
                _FilterChip(
                  label: 'Em andamento',
                  isSelected: selectedFilter == OrdersFilter.active,
                  onTap: () {
                    ref.read(ordersFilterProvider.notifier).state = OrdersFilter.active;
                  },
                ),
                _FilterChip(
                  label: 'Entregues',
                  isSelected: selectedFilter == OrdersFilter.delivered,
                  onTap: () {
                    ref.read(ordersFilterProvider.notifier).state = OrdersFilter.delivered;
                  },
                ),
                _FilterChip(
                  label: 'Cancelados',
                  isSelected: selectedFilter == OrdersFilter.cancelled,
                  onTap: () {
                    ref.read(ordersFilterProvider.notifier).state = OrdersFilter.cancelled;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Orders list
          Expanded(
            child: ordersState.when(
              loading: () => const Center(child: LoadingIndicator()),
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
              data: (data) => data.orders.isEmpty
                  ? EmptyState.noOrders()
                  : RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(ordersProvider);
                      },
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: data.orders.length + (data.hasMore ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          if (index >= data.orders.length) {
                            // Load more
                            ref.read(ordersProvider.notifier).loadMore();
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }

                          return OrderTile(order: data.orders[index]);
                        },
                      ),
                    ),
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
