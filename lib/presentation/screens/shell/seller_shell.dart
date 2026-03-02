import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../providers/seller_mode_provider.dart';
import '../../widgets/seller/seller_bottom_nav.dart';
import '../../widgets/shared/app_feedback.dart';

/// Seller shell with bottom navigation
class SellerShell extends ConsumerStatefulWidget {
  final Widget child;

  const SellerShell({super.key, required this.child});

  @override
  ConsumerState<SellerShell> createState() => _SellerShellState();
}

class _SellerShellState extends ConsumerState<SellerShell> {
  DateTime? _lastBackPress;

  int _getCurrentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/seller/products')) return 1;
    if (location.startsWith('/seller/agenda')) return 2;
    if (location.startsWith('/seller/orders')) return 3;
    if (location.startsWith('/seller/wallet')) return 4;
    return 0; // Dashboard
  }

  void _onTabTap(int index) {
    switch (index) {
      case 0:
        context.go('/seller');
        break;
      case 1:
        context.go('/seller/products');
        break;
      case 2:
        context.go('/seller/agenda');
        break;
      case 3:
        context.go('/seller/orders');
        break;
      case 4:
        context.go('/seller/wallet');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _getCurrentIndex(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // If not on dashboard tab, navigate to dashboard
        if (currentIndex != 0) {
          context.go('/seller');
          return;
        }
        // On dashboard: double-tap goes back to buyer mode
        final now = DateTime.now();
        if (_lastBackPress != null &&
            now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
          ref.read(sellerModeProvider.notifier).setMode(false);
          context.go(AppRouter.home);
          return;
        }
        _lastBackPress = now;
        if (!context.mounted) return;
        AppFeedback.showInfo(context, 'Pressione novamente para voltar ao modo comprador');
      },
      child: Scaffold(
        body: Stack(
          children: [
            widget.child,
            SellerBottomNav(
              currentIndex: currentIndex,
              onTap: _onTabTap,
            ),
          ],
        ),
      ),
    );
  }
}
