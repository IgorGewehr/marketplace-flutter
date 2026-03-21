import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../providers/auth_providers.dart';
import '../../providers/cart_provider.dart';
import '../../providers/notifications_provider.dart';
import '../seller/seller_mode_toggle.dart';

/// Clean home header — seller toggle centered, action icons on the right
class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider).valueOrNull;
    final isSeller = user?.isSeller ?? false;
    final unreadCount = ref.watch(unreadNotificationsCountProvider);
    final cartCount = ref.watch(cartItemCountProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Row(
        children: [
          // Seller mode toggle (only for sellers)
          if (isSeller)
            const Expanded(child: SellerModeToggle())
          else
            const Spacer(),

          const SizedBox(width: 8),

          // Cart button
          _HeaderIconButton(
            onPressed: () => context.push(AppRouter.cart),
            icon: Icons.shopping_cart_outlined,
            badgeCount: cartCount,
            theme: theme,
          ),

          const SizedBox(width: 2),

          // Notification bell
          _HeaderIconButton(
            onPressed: () => context.push(AppRouter.notifications),
            icon: Icons.notifications_outlined,
            badgeCount: unreadCount,
            theme: theme,
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final int badgeCount;
  final ThemeData theme;

  const _HeaderIconButton({
    required this.onPressed,
    required this.icon,
    required this.badgeCount,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(),
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Badge(
        isLabelVisible: badgeCount > 0,
        label: badgeCount > 9 ? const Text('9+') : Text('$badgeCount'),
        child: Icon(
          icon,
          color: theme.colorScheme.onSurface,
          size: 24,
        ),
      ),
    );
  }
}
