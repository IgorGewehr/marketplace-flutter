import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';

/// Empty state with illustration, title, subtitle, and optional CTA
class IllustratedEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;

  const IllustratedEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: (iconColor ?? AppColors.primary).withAlpha(15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 56,
                color: iconColor ?? AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: iconColor ?? AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: Text(
                  actionLabel!,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Empty state for chats
class EmptyChatsState extends StatelessWidget {
  const EmptyChatsState({super.key});

  @override
  Widget build(BuildContext context) {
    return IllustratedEmptyState(
      icon: Icons.chat_bubble_outline_rounded,
      title: 'Nenhuma conversa',
      subtitle: 'Encontre um produto e converse com o vendedor para tirar dúvidas.',
      actionLabel: 'Explorar produtos',
      onAction: () => context.go('/search'),
    );
  }
}

/// Empty state for notifications
class EmptyNotificationsState extends StatelessWidget {
  const EmptyNotificationsState({super.key});

  @override
  Widget build(BuildContext context) {
    return IllustratedEmptyState(
      icon: Icons.notifications_none_rounded,
      title: 'Nenhuma notificação',
      subtitle: 'Explore produtos para receber alertas de promoções, atualizações de pedidos e mensagens.',
      actionLabel: 'Explorar',
      onAction: () => context.go('/search'),
    );
  }
}

/// Empty state for orders
class EmptyOrdersState extends StatelessWidget {
  final VoidCallback? onShop;

  const EmptyOrdersState({super.key, this.onShop});

  @override
  Widget build(BuildContext context) {
    return IllustratedEmptyState(
      icon: Icons.shopping_bag_outlined,
      title: 'Nenhum pedido',
      subtitle: 'Seus pedidos aparecerão aqui após realizar uma compra.',
      actionLabel: onShop != null ? 'Ver produtos' : null,
      onAction: onShop,
      iconColor: AppColors.secondary,
    );
  }
}

/// Empty state for search results
class EmptySearchState extends StatelessWidget {
  final String? query;

  const EmptySearchState({super.key, this.query});

  @override
  Widget build(BuildContext context) {
    return IllustratedEmptyState(
      icon: Icons.search_off_rounded,
      title: query != null ? 'Nenhum resultado para "$query"' : 'Nenhum resultado',
      subtitle: 'Tente outros termos ou navegue pelas categorias.',
    );
  }
}

/// Empty state for addresses
class EmptyAddressesState extends StatelessWidget {
  final VoidCallback? onAdd;

  const EmptyAddressesState({super.key, this.onAdd});

  @override
  Widget build(BuildContext context) {
    return IllustratedEmptyState(
      icon: Icons.location_off_outlined,
      title: 'Nenhum endereço',
      subtitle: 'Adicione um endereço para receber suas compras.',
      actionLabel: onAdd != null ? 'Adicionar endereço' : null,
      onAction: onAdd,
    );
  }
}
