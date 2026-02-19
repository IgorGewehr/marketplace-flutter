import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../providers/auth_providers.dart';
import '../../providers/seller_orders_provider.dart';
import '../../providers/wallet_provider.dart';
import '../../widgets/shared/shimmer_loading.dart';
import '../../widgets/seller/stat_card.dart';
import '../../widgets/seller/seller_order_tile.dart';
import '../../widgets/seller/seller_mode_toggle.dart';

/// Seller dashboard with key metrics and recent orders
class SellerDashboardScreen extends ConsumerWidget {
  const SellerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walletAsync = ref.watch(walletProvider);
    final ordersAsync = ref.watch(sellerOrdersProvider);
    final newOrdersCount = ref.watch(newOrdersCountProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.sellerAccent,
        onRefresh: () async {
          await ref.read(walletProvider.notifier).refresh();
          await ref.read(sellerOrdersProvider.notifier).refresh();
        },
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverAppBar(
              floating: true,
              backgroundColor: AppColors.background,
              elevation: 0,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.sellerAccent.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: AppColors.sellerAccent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Builder(
                    builder: (context) {
                      final user = ref.watch(currentUserProvider).valueOrNull;
                      final storeName = user?.displayName ?? 'Minha Loja';
                      return Text(
                        storeName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      );
                    },
                  ),
                ],
              ),
              actions: const [
                SellerModeToggle(),
                SizedBox(width: 16),
              ],
            ),
            
            // Content
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Balance Card
                  walletAsync.when(
                    data: (wallet) => BalanceStatCard(
                      label: 'Saldo disponível',
                      value: _formatPrice(wallet?.balance.available ?? 0),
                      icon: Icons.account_balance_wallet_rounded,
                      accentColor: AppColors.secondary,
                      actionLabel: 'Sacar',
                      onTap: () => context.push('/seller/wallet'),
                    ),
                    loading: () => const BalanceStatCard(
                      label: 'Saldo disponível',
                      value: 'R\$ 0,00',
                      icon: Icons.account_balance_wallet_rounded,
                      isLoading: true,
                    ),
                    error: (_, __) => const BalanceStatCard(
                      label: 'Saldo disponível',
                      value: 'Erro',
                      icon: Icons.account_balance_wallet_rounded,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Stats Row
                  Row(
                    children: [
                      Expanded(
                        child: walletAsync.when(
                          data: (wallet) => StatCard(
                            icon: Icons.trending_up_rounded,
                            label: 'Vendas do mês',
                            value: _formatPrice(wallet?.balance.total ?? 0),
                            accentColor: AppColors.sellerAccent,
                            onTap: () => context.push('/seller/wallet'),
                          ),
                          loading: () => const StatCard(
                            icon: Icons.trending_up_rounded,
                            label: 'Vendas do mês',
                            value: 'R\$ 0,00',
                            isLoading: true,
                          ),
                          error: (_, __) => const StatCard(
                            icon: Icons.trending_up_rounded,
                            label: 'Vendas do mês',
                            value: '-',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          icon: Icons.pending_actions_rounded,
                          label: 'Pedidos novos',
                          value: '$newOrdersCount',
                          accentColor: newOrdersCount > 0
                              ? AppColors.warning
                              : AppColors.textHint,
                          onTap: () => context.push('/seller/orders'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Recent Orders Header
                  Row(
                    children: [
                      const Text(
                        'Últimos pedidos',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => context.push('/seller/orders'),
                        child: const Text(
                          'Ver todos',
                          style: TextStyle(
                            color: AppColors.sellerAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ]),
              ),
            ),
            
            // Recent Orders List
            ordersAsync.when(
              data: (orders) {
                if (orders.isEmpty) {
                  return SliverPadding(
                    padding: const EdgeInsets.all(32),
                    sliver: SliverToBoxAdapter(
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 64,
                              color: AppColors.textHint,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Nenhum pedido ainda',
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

                final recentOrders = orders.take(5).toList();
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final order = recentOrders[index];
                      return SellerOrderTile(
                        order: order,
                        onTap: () => context.push('/seller/orders/${order.id}'),
                      );
                    },
                    childCount: recentOrders.length,
                  ),
                );
              },
              loading: () => SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ShimmerBox(
                        width: double.infinity,
                        height: 80,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    childCount: 3,
                  ),
                ),
              ),
              error: (_, __) => const SliverPadding(
                padding: EdgeInsets.all(32),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: Text('Erro ao carregar pedidos'),
                  ),
                ),
              ),
            ),
            
            // Bottom padding for nav bar
            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          ],
        ),
      ),
    );
  }

  String _formatPrice(double price) {
    return Formatters.currency(price);
  }
}
