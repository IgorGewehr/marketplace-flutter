import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

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
        foregroundColor: AppColors.textPrimary,
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
        error: (_, __) => const Center(child: Text('Erro ao carregar perfil')),
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

                // Seller section
                if (isSeller)
                  ProfileMenuSection(
                    title: 'VENDEDOR',
                    items: [
                      ProfileMenuItem(
                        icon: Icons.store_rounded,
                        label: 'Modo Vendedor',
                        subtitle: sellerMode ? 'Ativo' : 'Inativo',
                        trailing: Switch(
                          value: sellerMode,
                          onChanged: (_) {
                            ref.read(sellerModeProvider.notifier).toggle();
                            if (!sellerMode) {
                              context.go(AppRouter.sellerDashboard);
                            }
                          },
                          activeColor: AppColors.sellerAccent,
                        ),
                        showChevron: false,
                      ),
                      ProfileMenuItem(
                        icon: Icons.inventory_2_outlined,
                        label: 'Meus Produtos',
                        onTap: () => context.push(AppRouter.sellerProducts),
                      ),
                      ProfileMenuItem(
                        icon: Icons.receipt_long_outlined,
                        label: 'Vendas',
                        onTap: () => context.push(AppRouter.sellerOrders),
                      ),
                      ProfileMenuItem(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Carteira',
                        onTap: () => context.push(AppRouter.sellerWallet),
                      ),
                    ],
                  )
                else
                  ProfileMenuSection(
                    items: [
                      ProfileMenuItem(
                        icon: Icons.store_outlined,
                        label: 'Quero Vender',
                        subtitle: 'Comece a vender no Compre Aqui',
                        iconColor: AppColors.sellerAccent,
                        onTap: () => context.push(AppRouter.becomeSeller),
                      ),
                    ],
                  ),

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
                      onTap: () => _openUrl('https://reidobrique.com.br/ajuda'),
                    ),
                    ProfileMenuItem(
                      icon: Icons.description_outlined,
                      label: 'Termos de Uso',
                      onTap: () => _openUrl('https://reidobrique.com.br/termos'),
                    ),
                    ProfileMenuItem(
                      icon: Icons.privacy_tip_outlined,
                      label: 'Política de Privacidade',
                      onTap: () => _openUrl('https://reidobrique.com.br/privacidade'),
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
              ref.read(cartProvider.notifier).clearCart();
              ref.invalidate(favoriteProductIdsProvider);
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
