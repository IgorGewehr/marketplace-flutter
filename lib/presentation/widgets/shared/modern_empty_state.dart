/// Modern empty states with illustrations
library;

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Modern empty state widget
class ModernEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;

  const ModernEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
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
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: (iconColor ?? Theme.of(context).primaryColor)
                    .withAlpha((255 * 0.1).round()),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 64,
                color: iconColor ?? Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Empty products state
class EmptyProductsState extends StatelessWidget {
  final VoidCallback? onBrowse;

  const EmptyProductsState({
    super.key,
    this.onBrowse,
  });

  @override
  Widget build(BuildContext context) {
    return ModernEmptyState(
      icon: LucideIcons.package,
      title: 'Nenhum produto encontrado',
      message: 'Não encontramos produtos com esses filtros.\nTente ajustar sua busca.',
      actionLabel: onBrowse != null ? 'Ver todos os produtos' : null,
      onAction: onBrowse,
    );
  }
}

/// Empty orders state
class EmptyOrdersState extends StatelessWidget {
  final VoidCallback? onShop;

  const EmptyOrdersState({
    super.key,
    this.onShop,
  });

  @override
  Widget build(BuildContext context) {
    return ModernEmptyState(
      icon: LucideIcons.shoppingBag,
      title: 'Nenhum pedido ainda',
      message: 'Você ainda não fez nenhum pedido.\nComece a explorar nossos produtos!',
      actionLabel: onShop != null ? 'Começar a comprar' : null,
      onAction: onShop,
      iconColor: const Color(0xFF3B82F6),
    );
  }
}

/// Empty cart state
class EmptyCartState extends StatelessWidget {
  final VoidCallback? onShop;

  const EmptyCartState({
    super.key,
    this.onShop,
  });

  @override
  Widget build(BuildContext context) {
    return ModernEmptyState(
      icon: LucideIcons.shoppingCart,
      title: 'Carrinho vazio',
      message: 'Seu carrinho está vazio.\nAdicione produtos para começar!',
      actionLabel: onShop != null ? 'Explorar produtos' : null,
      onAction: onShop,
      iconColor: const Color(0xFF8B5CF6),
    );
  }
}

/// Empty wishlist state
class EmptyWishlistState extends StatelessWidget {
  final VoidCallback? onBrowse;

  const EmptyWishlistState({
    super.key,
    this.onBrowse,
  });

  @override
  Widget build(BuildContext context) {
    return ModernEmptyState(
      icon: LucideIcons.heart,
      title: 'Nenhum favorito',
      message: 'Você ainda não favoritou nenhum produto.\nSalve seus produtos favoritos aqui!',
      actionLabel: onBrowse != null ? 'Explorar produtos' : null,
      onAction: onBrowse,
      iconColor: const Color(0xFFEF4444),
    );
  }
}

/// Empty chats state
class EmptyChatsState extends StatelessWidget {
  const EmptyChatsState({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModernEmptyState(
      icon: LucideIcons.messageCircle,
      title: 'Nenhuma conversa',
      message: 'Você ainda não iniciou nenhuma conversa.\nEntre em contato com vendedores para tirar dúvidas!',
      iconColor: Color(0xFF10B981),
    );
  }
}

/// Empty notifications state
class EmptyNotificationsState extends StatelessWidget {
  const EmptyNotificationsState({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModernEmptyState(
      icon: LucideIcons.bell,
      title: 'Nenhuma notificação',
      message: 'Você está em dia!\nQuando houver novidades, avisaremos aqui.',
      iconColor: Color(0xFF6366F1),
    );
  }
}

/// Empty search results state
class EmptySearchState extends StatelessWidget {
  final String searchTerm;
  final VoidCallback? onClearSearch;

  const EmptySearchState({
    super.key,
    required this.searchTerm,
    this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    return ModernEmptyState(
      icon: LucideIcons.search,
      title: 'Nenhum resultado',
      message: 'Não encontramos nada para "$searchTerm".\nTente buscar por outro termo.',
      actionLabel: onClearSearch != null ? 'Limpar busca' : null,
      onAction: onClearSearch,
      iconColor: const Color(0xFF64748B),
    );
  }
}

/// Empty reviews state
class EmptyReviewsState extends StatelessWidget {
  final VoidCallback? onWriteReview;

  const EmptyReviewsState({
    super.key,
    this.onWriteReview,
  });

  @override
  Widget build(BuildContext context) {
    return ModernEmptyState(
      icon: LucideIcons.star,
      title: 'Nenhuma avaliação',
      message: 'Este produto ainda não foi avaliado.\nSeja o primeiro a avaliar!',
      actionLabel: onWriteReview != null ? 'Escrever avaliação' : null,
      onAction: onWriteReview,
      iconColor: const Color(0xFFFBBF24),
    );
  }
}

/// Empty seller products state
class EmptySellerProductsState extends StatelessWidget {
  final VoidCallback? onAddProduct;

  const EmptySellerProductsState({
    super.key,
    this.onAddProduct,
  });

  @override
  Widget build(BuildContext context) {
    return ModernEmptyState(
      icon: LucideIcons.packagePlus,
      title: 'Nenhum produto cadastrado',
      message: 'Você ainda não cadastrou produtos.\nComece adicionando seu primeiro produto!',
      actionLabel: onAddProduct != null ? 'Adicionar produto' : null,
      onAction: onAddProduct,
      iconColor: const Color(0xFF10B981),
    );
  }
}

/// No internet connection state
class NoInternetState extends StatelessWidget {
  final VoidCallback? onRetry;

  const NoInternetState({
    super.key,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ModernEmptyState(
      icon: LucideIcons.wifiOff,
      title: 'Sem conexão',
      message: 'Não foi possível conectar à internet.\nVerifique sua conexão e tente novamente.',
      actionLabel: onRetry != null ? 'Tentar novamente' : null,
      onAction: onRetry,
      iconColor: const Color(0xFFEF4444),
    );
  }
}

/// Generic error state
class ErrorState extends StatelessWidget {
  final String? title;
  final String? message;
  final VoidCallback? onRetry;

  const ErrorState({
    super.key,
    this.title,
    this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ModernEmptyState(
      icon: LucideIcons.alertCircle,
      title: title ?? 'Algo deu errado',
      message: message ?? 'Ocorreu um erro inesperado.\nTente novamente mais tarde.',
      actionLabel: onRetry != null ? 'Tentar novamente' : null,
      onAction: onRetry,
      iconColor: const Color(0xFFEF4444),
    );
  }
}

/// Coming soon state
class ComingSoonState extends StatelessWidget {
  final String feature;

  const ComingSoonState({
    super.key,
    required this.feature,
  });

  @override
  Widget build(BuildContext context) {
    return ModernEmptyState(
      icon: LucideIcons.rocket,
      title: 'Em breve!',
      message: '$feature está em desenvolvimento.\nEm breve estará disponível!',
      iconColor: const Color(0xFF8B5CF6),
    );
  }
}
