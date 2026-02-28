import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/auth_providers.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/cart/cart_item_tile.dart';
import '../../widgets/cart/cart_summary.dart';
import '../../widgets/shared/app_feedback.dart';
import '../../widgets/shared/empty_state.dart';
import '../../widgets/shared/shimmer_loading.dart';

/// Cart screen
class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cartState = ref.watch(cartProvider);

    // A21: Show warning once when sync error changes from null to a message
    ref.listen<CartState>(cartProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Tentar novamente',
              onPressed: () {
                ref.read(cartProvider.notifier).pullRemoteCart();
              },
            ),
          ),
        );
        // Clear the error so it doesn't re-show on rebuilds
        ref.read(cartProvider.notifier).clearSyncError();
      }
    });

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Carrinho'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (cartState.items.isNotEmpty)
            TextButton(
              onPressed: () {
                _showClearCartDialog(context, ref);
              },
              child: const Text('Limpar'),
            ),
        ],
      ),
      body: cartState.isLoading
          ? const ShimmerLoading(itemCount: 3, isGrid: false, height: 90)
          : cartState.isEmpty
              ? EmptyState.emptyCart(
                  onBrowse: () => context.go(AppRouter.home),
                )
              : Column(
                  children: [
                    // A1: Multi-seller warning banner
                    if (cartState.warning != null)
                      _MultiSellerWarningBanner(
                        message: _buildMultiSellerMessage(cartState.items),
                        onDismiss: () => ref.read(cartProvider.notifier).dismissWarning(),
                      ),

                    // Cart items list
                    Expanded(
                      child: RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: () => ref.read(cartProvider.notifier).pullRemoteCart(),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: cartState.items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = cartState.items[index];
                            return CartItemTile(
                              item: item,
                              onRemove: () {
                                ref.read(cartProvider.notifier).removeFromCart(
                                      item.productId,
                                      variant: item.variant,
                                    );
                              },
                              onQuantityChanged: (quantity) {
                                ref.read(cartProvider.notifier).updateQuantity(
                                      item.productId,
                                      quantity,
                                      variant: item.variant,
                                    );
                              },
                            )
                                .animate(delay: Duration(milliseconds: (index % 6) * 60))
                                .fadeIn(duration: 300.ms, curve: Curves.easeOut)
                                .slideY(begin: 0.08, end: 0, duration: 300.ms, curve: Curves.easeOut);
                          },
                        ),
                      ),
                    ),

                    // Summary and checkout button
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            CartSummary(
                              total: cartState.subtotal,
                              itemCount: cartState.itemCount,
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: Tooltip(
                                message: cartState.hasMultipleSellers
                                    ? 'Remova itens de outros vendedores para finalizar'
                                    : '',
                                child: FilledButton(
                                  onPressed: cartState.hasMultipleSellers
                                      ? null
                                      : () => _proceedToCheckout(context, ref),
                                  child: const Text('Finalizar Compra'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 200.ms, duration: 350.ms)
                        .slideY(begin: 0.1, curve: Curves.easeOut),
                  ],
                ),
    );
  }

  String _buildMultiSellerMessage(List<LocalCartItem> items) {
    final sellerItems = <String, List<String>>{};
    for (final item in items) {
      final tenantId = item.tenantId.isNotEmpty ? item.tenantId : 'desconhecido';
      sellerItems.putIfAbsent(tenantId, () => []).add(item.productName);
    }
    final sellerDescriptions = sellerItems.entries.map((entry) {
      final names = entry.value.length > 2
          ? '${entry.value.take(2).join(", ")} e mais ${entry.value.length - 2}'
          : entry.value.join(", ");
      return names;
    }).toList();
    if (sellerItems.length > 1) {
      return 'Seu carrinho tem itens de ${sellerDescriptions.length} vendedores diferentes '
          '(${sellerDescriptions.join(" | ")}). '
          'Remova itens de um vendedor para continuar.';
    }
    return 'Seu carrinho tem produtos de vendedores diferentes. Só é possível finalizar pedidos de um vendedor por vez.';
  }

  void _proceedToCheckout(BuildContext context, WidgetRef ref) {
    final isAuth = ref.read(isAuthenticatedProvider);

    if (!isAuth) {
      context.push('${AppRouter.login}?redirect=${AppRouter.checkout}');
    } else {
      context.push(AppRouter.checkout);
    }
  }

  void _showClearCartDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await AppFeedback.showConfirmation(
      context,
      title: 'Limpar carrinho',
      message: 'Deseja remover todos os itens do carrinho?',
    );

    if (confirmed) {
      ref.read(cartProvider.notifier).clearCart();
    }
  }
}

/// Dismissible amber warning banner for multi-seller carts
class _MultiSellerWarningBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _MultiSellerWarningBanner({
    required this.message,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFFFFF3CD),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.warning_amber_outlined,
              color: Color(0xFF856404),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF856404),
                fontSize: 13,
              ),
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(
                Icons.close,
                color: Color(0xFF856404),
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
