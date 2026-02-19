import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../providers/seller_mode_provider.dart';
import '../../providers/auth_providers.dart';

/// Animated toggle switch for buyer ↔ seller mode
/// Shows in app bar when user is a seller
class SellerModeToggle extends ConsumerWidget {
  const SellerModeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final isSellerMode = ref.watch(sellerModeProvider);

    // Only show for sellers
    if (user == null || !user.isSeller) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () {
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSellerMode
              ? AppColors.sellerAccent.withAlpha(25)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSellerMode
                ? AppColors.sellerAccent.withAlpha(50)
                : AppColors.border,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon with animation
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isSellerMode ? Icons.storefront_rounded : Icons.shopping_bag_outlined,
                key: ValueKey(isSellerMode),
                size: 18,
                color: isSellerMode ? AppColors.sellerAccent : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            // Label with animation
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                isSellerMode ? 'Vendedor' : 'Comprador',
                key: ValueKey(isSellerMode),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSellerMode ? AppColors.sellerAccent : AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Toggle indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSellerMode ? AppColors.sellerAccent : AppColors.textHint,
              ),
            ),
          ],
        ),
      ).animate(target: isSellerMode ? 1 : 0).scale(
            begin: const Offset(1, 1),
            end: const Offset(1.02, 1.02),
            duration: 150.ms,
          ),
    );
  }
}
