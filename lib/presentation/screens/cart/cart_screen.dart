import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../providers/auth_providers.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/cart/cart_item_tile.dart';
import '../../widgets/cart/cart_summary.dart';
import '../../widgets/shared/empty_state.dart';
import '../../widgets/shared/loading_overlay.dart';

/// Cart screen
class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cartState = ref.watch(cartProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Carrinho'),
        backgroundColor: theme.colorScheme.surface,
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
          ? const Center(child: LoadingIndicator())
          : cartState.isEmpty
              ? EmptyState.emptyCart(
                  onBrowse: () => context.go(AppRouter.home),
                )
              : Column(
                  children: [
                    // Cart items list
                    Expanded(
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
                          );
                        },
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
                              child: FilledButton(
                                onPressed: () => _proceedToCheckout(context, ref),
                                child: const Text('Finalizar Compra'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  void _proceedToCheckout(BuildContext context, WidgetRef ref) {
    final isAuth = ref.read(isAuthenticatedProvider);

    if (!isAuth) {
      context.push('${AppRouter.login}?redirect=${AppRouter.checkout}');
    } else {
      context.push(AppRouter.checkout);
    }
  }

  void _showClearCartDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpar carrinho'),
        content: const Text('Tem certeza que deseja remover todos os itens?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(cartProvider.notifier).clearCart();
              Navigator.pop(context);
            },
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
  }
}
