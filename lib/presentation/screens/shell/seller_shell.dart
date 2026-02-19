import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/mercadopago_provider.dart';
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
    if (location.startsWith('/seller/orders')) return 2;
    if (location.startsWith('/seller/wallet')) return 3;
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
        context.go('/seller/orders');
        break;
      case 3:
        context.go('/seller/wallet');
        break;
    }
  }

  void _onFabPressed() {
    // Check Mercado Pago connection before creating product
    final isMpConnected = ref.read(isMpConnectedProvider);
    if (!isMpConnected) {
      _showMpConnectDialog();
      return;
    }

    // All checks passed — create product
    context.push('/seller/products/new');
  }

  void _showMpConnectDialog() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.sellerAccent.withAlpha(25),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.account_balance_wallet_outlined,
            color: AppColors.sellerAccent,
            size: 32,
          ),
        ),
        title: const Text('Conecte o Mercado Pago'),
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
        ),
        content: const Text(
          'Para publicar produtos e receber pagamentos, você precisa conectar sua conta do Mercado Pago.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              context.push(AppRouter.sellerMpConnect);
            },
            icon: const Icon(Icons.link, size: 18),
            label: const Text('Conectar Mercado Pago'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.sellerAccent,
            ),
          ),
        ],
      ),
    );
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
        body: widget.child,
        extendBody: true,
        bottomNavigationBar: SellerBottomNav(
          currentIndex: currentIndex,
          onTap: _onTabTap,
          onFabPressed: _onFabPressed,
        ),
      ),
    );
  }
}
