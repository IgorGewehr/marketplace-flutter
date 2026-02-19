import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/auth_providers.dart';
import '../../providers/cart_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/products_provider.dart';
import '../../providers/seller_mode_provider.dart';
import '../../widgets/profile/profile_header.dart';
import '../../widgets/profile/profile_menu_item.dart';

/// Profile screen
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final sellerMode = ref.watch(sellerModeProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Meu Perfil'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(AppRouter.settings),
          ),
        ],
      ),
      body: userAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              const Text('Erro ao carregar perfil'),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => ref.invalidate(currentUserProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Usuário não encontrado'));
          }

          final isSeller = user.type == 'seller' || user.type == 'full';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Profile header
                ProfileHeader(
                  name: user.displayName,
                  email: user.email,
                  avatarUrl: user.photoURL,
                  isSeller: isSeller,
                  onEditAvatar: () {
                    context.push(AppRouter.editProfile);
                  },
                ),
                const SizedBox(height: 24),

                // Account section
                ProfileMenuSection(
                  title: 'CONTA',
                  items: [
                    ProfileMenuItem(
                      icon: Icons.person_outline_rounded,
                      label: 'Editar Perfil',
                      onTap: () => context.push(AppRouter.editProfile),
                    ),
                    ProfileMenuItem(
                      icon: Icons.location_on_outlined,
                      label: 'Meus Endereços',
                      onTap: () => context.push(AppRouter.addresses),
                    ),
                    ProfileMenuItem(
                      icon: Icons.shopping_bag_outlined,
                      label: 'Meus Pedidos',
                      onTap: () => context.push(AppRouter.orders),
                    ),
                  ],
                ),

                // Seller mode banner — prominent switch
                if (isSeller) ...[
                  _SellerModeBanner(
                    isSellerMode: sellerMode,
                    onToggle: () {
                      ref.read(sellerModeProvider.notifier).toggle();
                      if (!sellerMode) {
                        context.go(AppRouter.sellerDashboard);
                      } else {
                        context.go(AppRouter.home);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  ProfileMenuSection(
                    title: 'VENDEDOR',
                    items: [
                      ProfileMenuItem(
                        icon: Icons.inventory_2_outlined,
                        label: 'Meus Produtos',
                        iconColor: AppColors.sellerAccent,
                        onTap: () => context.push(AppRouter.sellerProducts),
                      ),
                      ProfileMenuItem(
                        icon: Icons.receipt_long_outlined,
                        label: 'Vendas',
                        iconColor: AppColors.sellerAccent,
                        onTap: () => context.push(AppRouter.sellerOrders),
                      ),
                      ProfileMenuItem(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Carteira',
                        iconColor: AppColors.sellerAccent,
                        onTap: () => context.push(AppRouter.sellerWallet),
                      ),
                    ],
                  ),
                ] else ...[
                  _BecomeSellerBanner(
                    onTap: () => context.push(AppRouter.becomeSeller),
                  ),
                ],

                // App section
                ProfileMenuSection(
                  title: 'APLICATIVO',
                  items: [
                    ProfileMenuItem(
                      icon: Icons.notifications_outlined,
                      label: 'Notificações',
                      onTap: () => context.push(AppRouter.notificationSettings),
                    ),
                    ProfileMenuItem(
                      icon: Icons.help_outline_rounded,
                      label: 'Ajuda e Suporte',
                      onTap: () => _openUrl(AppConstants.helpUrl),
                    ),
                    ProfileMenuItem(
                      icon: Icons.description_outlined,
                      label: 'Termos de Uso',
                      onTap: () => _openUrl(AppConstants.termsUrl),
                    ),
                    ProfileMenuItem(
                      icon: Icons.privacy_tip_outlined,
                      label: 'Política de Privacidade',
                      onTap: () => _openUrl(AppConstants.privacyUrl),
                    ),
                  ],
                ),

                // Logout section
                ProfileMenuSection(
                  items: [
                    ProfileMenuItem(
                      icon: Icons.logout_rounded,
                      label: 'Sair',
                      isDestructive: true,
                      showChevron: false,
                      onTap: () => _showLogoutConfirmation(context, ref),
                    ),
                  ],
                ),

                // Version
                const SizedBox(height: 8),
                Text(
                  'Compre Aqui v1.0.0',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textHint,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openUrl(String url) {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  void _showLogoutConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair da conta'),
        content: const Text('Tem certeza que deseja sair?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              // Gap #2: Clear user-scoped state on logout
              ref.read(cartProvider.notifier).clearCart();
              ref.read(favoriteProductIdsProvider.notifier).clearFavorites();
              ref.invalidate(chatsProvider);
              ref.invalidate(searchHistoryProvider);
              ref.read(authNotifierProvider.notifier).signOut();
              context.go(AppRouter.login);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
  }
}

/// Prominent banner for toggling seller mode on/off
class _SellerModeBanner extends StatelessWidget {
  final bool isSellerMode;
  final VoidCallback onToggle;

  const _SellerModeBanner({
    required this.isSellerMode,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onToggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: isSellerMode
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.sellerAccent,
                      AppColors.sellerAccentDark,
                    ],
                  )
                : null,
            color: isSellerMode ? null : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: isSellerMode
                ? null
                : Border.all(
                    color: AppColors.sellerAccent.withAlpha(60),
                    width: 1.5,
                  ),
            boxShadow: [
              BoxShadow(
                color: isSellerMode
                    ? AppColors.sellerAccent.withAlpha(40)
                    : Colors.black.withAlpha(8),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSellerMode
                      ? Colors.white.withAlpha(40)
                      : AppColors.sellerAccent.withAlpha(20),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isSellerMode
                      ? Icons.storefront_rounded
                      : Icons.store_outlined,
                  color: isSellerMode ? Colors.white : AppColors.sellerAccent,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSellerMode ? 'Modo Vendedor' : 'Acessar Modo Vendedor',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSellerMode
                            ? Colors.white
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isSellerMode
                          ? 'Toque para voltar às compras'
                          : 'Gerencie seus produtos e vendas',
                      style: TextStyle(
                        fontSize: 13,
                        color: isSellerMode
                            ? Colors.white.withAlpha(200)
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Arrow/indicator
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isSellerMode
                      ? Colors.white.withAlpha(40)
                      : AppColors.sellerAccent.withAlpha(15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSellerMode
                      ? Icons.shopping_bag_outlined
                      : Icons.arrow_forward_rounded,
                  color: isSellerMode ? Colors.white : AppColors.sellerAccent,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Prominent banner encouraging users to become a seller
class _BecomeSellerBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _BecomeSellerBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.sellerAccent.withAlpha(40),
              width: 1.5,
            ),
            color: theme.colorScheme.surface,
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: AppColors.sellerGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
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
              const SizedBox(width: 8),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.sellerAccent.withAlpha(15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: AppColors.sellerAccent,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
