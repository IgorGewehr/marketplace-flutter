import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/auth_providers.dart';
import '../../providers/mercadopago_provider.dart';
import '../../providers/seller_mode_provider.dart';
import '../../widgets/shared/custom_bottom_nav.dart';

/// Buyer shell with bottom navigation (5 tabs)
class BuyerShell extends ConsumerStatefulWidget {
  final Widget child;

  const BuyerShell({super.key, required this.child});

  @override
  ConsumerState<BuyerShell> createState() => _BuyerShellState();
}

class _BuyerShellState extends ConsumerState<BuyerShell> {
  DateTime? _lastBackPress;

  int _getCurrentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/search')) return 1;
    if (location.startsWith('/chat')) return 2;
    return 0;
  }

  void _onTabTap(int index) {
    switch (index) {
      case 0:
        context.go(AppRouter.home);
        break;
      case 1:
        context.go(AppRouter.search);
        break;
      case 2:
        // Chat list - requires auth
        final isAuth = ref.read(isAuthenticatedProvider);
        if (isAuth) {
          context.go(AppRouter.chats);
        } else {
          context.push('${AppRouter.login}?redirect=/chats');
        }
        break;
      case 3:
        // Menu - open bottom sheet
        _showMenuSheet();
        break;
    }
  }

  void _onFabPressed() {
    // 1. Check if logged in
    final isAuth = ref.read(isAuthenticatedProvider);
    if (!isAuth) {
      context.push('${AppRouter.login}?redirect=/seller/products/new');
      return;
    }

    // 2. Check if user is a seller
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null || !user.isSeller) {
      context.push(AppRouter.becomeSeller);
      return;
    }

    // TODO: Re-enable Mercado Pago check after testing phase
    // final isMpConnected = ref.read(isMpConnectedProvider);
    // if (!isMpConnected) {
    //   _showMpConnectDialog();
    //   return;
    // }

    // 3. All checks passed — go directly to create product
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

  void _showMenuSheet() {
    final isAuth = ref.read(isAuthenticatedProvider);
    final user = ref.read(currentUserProvider).valueOrNull;
    final isSeller = user?.isSeller ?? false;
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withAlpha(50),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Menu',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Seller mode entry — prominent for sellers
              if (isSeller) ...[
                _MenuActionButton(
                  icon: Icons.storefront_rounded,
                  label: 'Minhas Vendas',
                  isSeller: true,
                  onTap: () {
                    Navigator.pop(context);
                    ref.read(sellerModeProvider.notifier).setMode(true);
                    this.context.go('/seller');
                  },
                ),
                const SizedBox(height: 8),
              ],

              _MenuActionButton(
                icon: Icons.person_outline,
                label: 'Perfil',
                onTap: () {
                  Navigator.pop(context);
                  if (isAuth) {
                    this.context.push(AppRouter.profile);
                  } else {
                    this.context.push(AppRouter.login);
                  }
                },
              ),
              const SizedBox(height: 8),
              _MenuActionButton(
                icon: Icons.receipt_long_outlined,
                label: 'Meus Pedidos',
                onTap: () {
                  Navigator.pop(context);
                  if (isAuth) {
                    this.context.push(AppRouter.orders);
                  } else {
                    this.context.push(AppRouter.login);
                  }
                },
              ),
              const SizedBox(height: 8),
              _MenuActionButton(
                icon: Icons.favorite_outline,
                label: 'Favoritos',
                onTap: () {
                  Navigator.pop(context);
                  this.context.push(AppRouter.favorites);
                },
              ),
              const SizedBox(height: 8),
              _MenuActionButton(
                icon: Icons.settings_outlined,
                label: 'Configurações',
                onTap: () {
                  Navigator.pop(context);
                  this.context.push(AppRouter.settings);
                },
              ),
              if (isAuth) ...[
                const SizedBox(height: 8),
                _MenuActionButton(
                  icon: Icons.logout,
                  label: 'Sair',
                  isDestructive: true,
                  onTap: () {
                    Navigator.pop(context);
                    ref.read(authNotifierProvider.notifier).signOut();
                  },
                ),
              ],
            ],
          ),
        ),
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
        // If not on home tab, navigate to home
        if (currentIndex != 0) {
          context.go(AppRouter.home);
          return;
        }
        // On home tab: double-tap to exit
        final now = DateTime.now();
        if (_lastBackPress != null &&
            now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
          SystemNavigator.pop();
          return;
        }
        _lastBackPress = now;
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            const SnackBar(
              content: Text('Pressione novamente para sair'),
              duration: Duration(seconds: 2),
            ),
          );
      },
      child: Scaffold(
        body: widget.child,
        extendBody: false,
        bottomNavigationBar: CustomBottomNav(
          currentIndex: currentIndex,
          onTap: _onTabTap,
          onFabPressed: _onFabPressed,
        ),
      ),
    );
  }
}

class _MenuActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;
  final bool isSeller;

  const _MenuActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
    this.isSeller = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isDestructive
        ? theme.colorScheme.error
        : isSeller
            ? AppColors.sellerAccent
            : theme.colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSeller
              ? AppColors.sellerAccent.withAlpha(15)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: isSeller
              ? Border.all(color: AppColors.sellerAccent.withAlpha(40))
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: isSeller ? FontWeight.w600 : FontWeight.w500,
                  color: isDestructive
                      ? theme.colorScheme.error
                      : isSeller
                          ? AppColors.sellerAccent
                          : null,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isSeller
                  ? AppColors.sellerAccent
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
