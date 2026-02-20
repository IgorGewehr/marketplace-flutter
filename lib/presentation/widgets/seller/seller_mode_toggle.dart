import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/mercadopago_provider.dart';
import '../../providers/seller_mode_provider.dart';
import '../../providers/auth_providers.dart';
import '../shared/app_feedback.dart';

/// Animated toggle switch for buyer ↔ seller mode
/// Shows in app bar when user is a seller
class SellerModeToggle extends ConsumerWidget {
  const SellerModeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider).valueOrNull;
    final isSellerMode = ref.watch(sellerModeProvider);

    // Only show for sellers
    if (user == null || !user.isSeller) {
      return const SizedBox.shrink();
    }

    return Semantics(
      label: isSellerMode
          ? 'Modo Vendedor ativo, toque para mudar para Comprador'
          : 'Modo Comprador ativo, toque para mudar para Vendedor',
      button: true,
      child: GestureDetector(
        onTap: () {
          // When switching to seller mode, check MP connection
          if (!isSellerMode) {
            final isMpConnected = ref.read(isMpConnectedProvider);
            if (!isMpConnected) {
              AppFeedback.showWarning(
                context,
                'Conecte seu Mercado Pago para acessar o modo vendedor',
              );
              context.push(AppRouter.sellerMpConnect);
              return;
            }
          }

          ref.read(sellerModeProvider.notifier).toggle();
          // Navigate to the correct shell
          if (isSellerMode) {
            // Was seller → switching to buyer
            context.go('/');
          } else {
            // Was buyer → switching to seller
            context.go('/seller');
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          width: 130,
          height: 40,
          decoration: BoxDecoration(
            color: isSellerMode
                ? AppColors.sellerAccent.withAlpha(30)
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSellerMode
                  ? AppColors.sellerAccent.withAlpha(80)
                  : theme.colorScheme.outline.withAlpha(60),
              width: 1.5,
            ),
          ),
          child: Stack(
            children: [
              // Sliding indicator
              AnimatedAlign(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                alignment: isSellerMode
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  width: 60,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isSellerMode
                        ? AppColors.sellerAccent
                        : theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: (isSellerMode
                                ? AppColors.sellerAccent
                                : theme.colorScheme.primary)
                            .withAlpha(60),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              // Labels
              Row(
                children: [
                  // Buyer side
                  Expanded(
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shopping_bag_outlined,
                            size: 14,
                            color: !isSellerMode
                                ? Colors.white
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Loja',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: !isSellerMode
                                  ? Colors.white
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Seller side
                  Expanded(
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.storefront_rounded,
                            size: 14,
                            color: isSellerMode
                                ? Colors.white
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Vender',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isSellerMode
                                  ? Colors.white
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
