import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../providers/auth_providers.dart';
import '../../providers/seller_mode_provider.dart';
import '../../providers/seller_orders_provider.dart';
import '../../providers/tenant_provider.dart';
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
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              title: Row(
                children: [
                  const Icon(
                    Icons.storefront_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Builder(
                    builder: (context) {
                      final user = ref.watch(currentUserProvider).valueOrNull;
                      final tenantId = user?.tenantId;
                      final tenantAsync = tenantId != null
                          ? ref.watch(tenantByIdProvider(tenantId))
                          : null;
                      final tenant = tenantAsync?.valueOrNull;
                      final storeName =
                          tenant?.displayName ?? user?.displayName ?? 'Minha Loja';
                      return Text(
                        storeName,
                        style: AppTextStyles.titleMedium.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                ],
              ),
              actions: [
                IconButton(
                  onPressed: () => context.push('/seller/edit-profile'),
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: Colors.white,
                  ),
                  tooltip: 'Editar perfil da loja',
                ),
                const SellerModeToggle(),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () {
                    ref.read(sellerModeProvider.notifier).setMode(false);
                    context.go('/');
                  },
                  icon: const Icon(
                    Icons.shopping_bag_outlined,
                    color: Colors.white,
                  ),
                  tooltip: 'Voltar para compras',
                ),
                const SizedBox(width: 4),
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
                      label: 'Total ganho',
                      value: _formatPrice(
                          (wallet?.balance.available ?? 0) +
                              (wallet?.balance.pending ?? 0)),
                      icon: Icons.account_balance_wallet_rounded,
                      accentColor: AppColors.secondary,
                      actionLabel: 'Ver carteira',
                      onTap: () => context.push('/seller/wallet'),
                    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08, curve: Curves.easeOut),
                    loading: () => const _DashboardBalanceShimmer(),
                    error: (_, __) => BalanceStatCard(
                      label: 'Total ganho',
                      value: 'Erro',
                      icon: Icons.account_balance_wallet_rounded,
                      onTap: () => ref.invalidate(walletProvider),
                      actionLabel: 'Tentar novamente',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Stats Row
                  Row(
                    children: [
                      Expanded(
                        child: walletAsync.when(
                          data: (wallet) => StatCard(
                            icon: Icons.schedule_rounded,
                            label: 'Aguardando entrega',
                            value: _formatPrice(wallet?.balance.pending ?? 0),
                            accentColor: AppColors.warning,
                            onTap: () => context.push('/seller/wallet'),
                          ).animate().fadeIn(delay: 100.ms, duration: 400.ms).slideY(begin: 0.08, curve: Curves.easeOut),
                          loading: () => const _DashboardStatShimmer(),
                          error: (_, __) => const StatCard(
                            icon: Icons.schedule_rounded,
                            label: 'Aguardando entrega',
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
                        ).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideY(begin: 0.08, curve: Curves.easeOut),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Back to shopping shortcut
                  Material(
                    borderRadius: BorderRadius.circular(12),
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        ref.read(sellerModeProvider.notifier).setMode(false);
                        context.go('/');
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.shopping_bag_outlined,
                              size: 20,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Voltar para compras',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
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
              error: (error, _) => SliverPadding(
                padding: const EdgeInsets.all(32),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: Column(
                      children: [
                        const Text(
                          'Erro ao carregar pedidos',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () => ref.invalidate(sellerOrdersProvider),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Tentar novamente'),
                        ),
                      ],
                    ),
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

/// Shimmer placeholder for the large balance card on the dashboard
class _DashboardBalanceShimmer extends StatelessWidget {
  const _DashboardBalanceShimmer();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Shimmer.fromColors(
      baseColor: theme.colorScheme.surfaceContainerHighest,
      highlightColor: theme.colorScheme.surface,
      child: Container(
        width: double.infinity,
        height: 120,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: 100,
              height: 12,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 160,
              height: 24,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shimmer placeholder for the small stat cards on the dashboard
class _DashboardStatShimmer extends StatelessWidget {
  const _DashboardStatShimmer();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Shimmer.fromColors(
      baseColor: theme.colorScheme.surfaceContainerHighest,
      highlightColor: theme.colorScheme.surface,
      child: Container(
        width: double.infinity,
        height: 90,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: 80,
              height: 10,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: 60,
              height: 16,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
