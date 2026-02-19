import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../providers/seller_orders_provider.dart';
import '../../widgets/seller/seller_order_tile.dart';

/// Screen showing orders received by seller
class SellerOrdersScreen extends ConsumerWidget {
  const SellerOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(filteredSellerOrdersProvider);
    final currentFilter = ref.watch(sellerOrdersFilterProvider);
    final newOrdersCount = ref.watch(newOrdersCountProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.sellerAccent,
        onRefresh: () => ref.read(sellerOrdersProvider.notifier).refresh(),
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverAppBar(
              floating: true,
              pinned: true,
              backgroundColor: AppColors.background,
              elevation: 0,
              title: Row(
                children: [
                  const Text(
                    'Pedidos',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (newOrdersCount > 0) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.sellerAccent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$newOrdersCount novos',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(56),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'Todos',
                        isSelected: currentFilter == SellerOrdersFilter.all,
                        onTap: () => ref.read(sellerOrdersFilterProvider.notifier).state = SellerOrdersFilter.all,
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Novos',
                        isSelected: currentFilter == SellerOrdersFilter.newOrders,
                        onTap: () => ref.read(sellerOrdersFilterProvider.notifier).state = SellerOrdersFilter.newOrders,
                        badge: newOrdersCount > 0 ? newOrdersCount : null,
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Preparando',
                        isSelected: currentFilter == SellerOrdersFilter.preparing,
                        onTap: () => ref.read(sellerOrdersFilterProvider.notifier).state = SellerOrdersFilter.preparing,
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Enviados',
                        isSelected: currentFilter == SellerOrdersFilter.shipped,
                        onTap: () => ref.read(sellerOrdersFilterProvider.notifier).state = SellerOrdersFilter.shipped,
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Entregues',
                        isSelected: currentFilter == SellerOrdersFilter.delivered,
                        onTap: () => ref.read(sellerOrdersFilterProvider.notifier).state = SellerOrdersFilter.delivered,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Orders List
            ordersAsync.when(
              data: (orders) {
                if (orders.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 72,
                            color: AppColors.textHint,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Nenhum pedido encontrado',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            currentFilter != SellerOrdersFilter.all
                                ? 'Tente outro filtro'
                                : 'Seus pedidos aparecerão aqui',
                            style: const TextStyle(
                              color: AppColors.textHint,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final order = orders[index];
                      return SellerOrderTile(
                        order: order,
                        onTap: () => context.push('/seller/orders/${order.id}'),
                      );
                    },
                    childCount: orders.length,
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.sellerAccent),
                ),
              ),
              error: (_, __) => const SliverFillRemaining(
                child: Center(
                  child: Text('Erro ao carregar pedidos'),
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
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int? badge;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.sellerAccent : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.sellerAccent : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : AppColors.sellerAccent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$badge',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? AppColors.sellerAccent : Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
