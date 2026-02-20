import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/auth_providers.dart';
import '../../providers/mercadopago_provider.dart';
import '../../providers/seller_mode_provider.dart';
import '../../widgets/shared/app_feedback.dart';
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

    // 3. Check Mercado Pago connection (skip if still loading)
    final mpConnection = ref.read(mpConnectionProvider);
    if (!mpConnection.isLoading &&
        !(mpConnection.valueOrNull?.isConnected ?? false)) {
      _showMpConnectDialog();
      return;
    }

    // 4. All checks passed — go directly to create product
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
    final outerContext = context;

    // Use .then() for navigation after the modal fully closes,
    // preventing the modal barrier from staying on top of the new route.
    showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
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
                _SellerModeMenuCard(
                  onTap: () => Navigator.pop(sheetContext, 'seller_mode'),
                ),
                const SizedBox(height: 12),
              ] else ...[
                _BecomeSellerMenuCard(
                  onTap: () => Navigator.pop(sheetContext, 'become_seller'),
                ),
                const SizedBox(height: 12),
              ],

              _MenuActionButton(
                icon: Icons.person_outline,
                label: 'Perfil',
                onTap: () => Navigator.pop(sheetContext, 'profile'),
              ),
              const SizedBox(height: 8),
              _MenuActionButton(
                icon: Icons.receipt_long_outlined,
                label: 'Meus Pedidos',
                onTap: () => Navigator.pop(sheetContext, 'orders'),
              ),
              const SizedBox(height: 8),
              _MenuActionButton(
                icon: Icons.favorite_outline,
                label: 'Favoritos',
                onTap: () => Navigator.pop(sheetContext, 'favorites'),
              ),
              const SizedBox(height: 8),
              _MenuActionButton(
                icon: Icons.settings_outlined,
                label: 'Configurações',
                onTap: () => Navigator.pop(sheetContext, 'settings'),
              ),
              if (isAuth) ...[
                const SizedBox(height: 8),
                _MenuActionButton(
                  icon: Icons.logout,
                  label: 'Sair',
                  isDestructive: true,
                  onTap: () => Navigator.pop(sheetContext, 'logout'),
                ),
              ],
            ],
          ),
        ),
      ),
    ).then((action) {
      if (action == null || !mounted) return;

      switch (action) {
        case 'seller_mode':
          // Check MP connection before entering seller mode
          // Skip check if still loading to avoid false negatives
          final mpConnection = ref.read(mpConnectionProvider);
          if (!mpConnection.isLoading &&
              !(mpConnection.valueOrNull?.isConnected ?? false)) {
            _showMpConnectDialog();
            return;
          }
          ref.read(sellerModeProvider.notifier).setMode(true);
          outerContext.go('/seller');
        case 'become_seller':
          outerContext.push(AppRouter.becomeSeller);
        case 'profile':
          if (isAuth) {
            outerContext.push(AppRouter.profile);
          } else {
            outerContext.push(AppRouter.login);
          }
        case 'orders':
          if (isAuth) {
            outerContext.push(AppRouter.orders);
          } else {
            outerContext.push(AppRouter.login);
          }
        case 'favorites':
          outerContext.push(AppRouter.favorites);
        case 'settings':
          outerContext.push(AppRouter.settings);
        case 'logout':
          ref.read(authNotifierProvider.notifier).signOut();
      }
    });
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
        if (!context.mounted) return;
        AppFeedback.showInfo(context, 'Pressione novamente para sair');
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

  const _MenuActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isDestructive
        ? theme.colorScheme.error
        : theme.colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: isDestructive
                      ? theme.colorScheme.error
                      : null,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// Prominent seller mode card in the buyer menu
class _SellerModeMenuCard extends StatelessWidget {
  final VoidCallback onTap;

  const _SellerModeMenuCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AppColors.sellerGradient,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(40),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Modo Vendedor',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Gerencie produtos e vendas',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withAlpha(200),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(40),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// CTA card encouraging non-sellers to start selling
class _BecomeSellerMenuCard extends StatelessWidget {
  final VoidCallback onTap;

  const _BecomeSellerMenuCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: theme.colorScheme.surfaceContainerHighest,
            border: Border.all(
              color: AppColors.sellerAccent.withAlpha(40),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.sellerAccent.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: AppColors.sellerAccent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quero Vender',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Comece a vender no Compre Aqui',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.sellerAccent,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
