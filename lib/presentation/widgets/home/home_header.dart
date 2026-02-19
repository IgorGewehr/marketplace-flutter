import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../providers/auth_providers.dart';
import '../seller/seller_mode_toggle.dart';

/// Minimalist home header with "Compre Aqui" branding, seller toggle and notification bell
class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider).valueOrNull;
    final isSeller = user?.isSeller ?? false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
      child: Row(
        children: [
          // App name
          Text(
            'Compre Aqui',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),

          const Spacer(),

          // Seller mode toggle (only for sellers)
          if (isSeller) const SellerModeToggle(),

          // Notification bell with badge
          IconButton(
            onPressed: () => context.push(AppRouter.notifications),
            icon: Badge(
              smallSize: 8,
              child: Icon(
                Icons.notifications_outlined,
                color: theme.colorScheme.onSurface,
                size: 26,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
