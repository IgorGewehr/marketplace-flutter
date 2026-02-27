import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Empty state placeholder for lists
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  /// No products found
  factory EmptyState.noProducts({VoidCallback? onRetry}) {
    return EmptyState(
      icon: Icons.inventory_2_outlined,
      title: 'Nenhum produto encontrado',
      subtitle: 'Tente buscar por outros termos',
      actionLabel: onRetry != null ? 'Tentar novamente' : null,
      onAction: onRetry,
    );
  }

  /// Empty cart
  factory EmptyState.emptyCart({VoidCallback? onBrowse}) {
    return EmptyState(
      icon: Icons.shopping_cart_outlined,
      title: 'Carrinho vazio',
      subtitle: 'Adicione produtos para continuar',
      actionLabel: 'Explorar produtos',
      onAction: onBrowse,
    );
  }

  /// No orders
  factory EmptyState.noOrders() {
    return const EmptyState(
      icon: Icons.receipt_long_outlined,
      title: 'Nenhum pedido ainda',
      subtitle: 'Seus pedidos aparecerão aqui',
    );
  }

  /// No chats
  factory EmptyState.noChats() {
    return const EmptyState(
      icon: Icons.chat_bubble_outline,
      title: 'Nenhuma conversa',
      subtitle: 'Comece a conversar com vendedores',
    );
  }

  /// Search empty
  factory EmptyState.searchEmpty() {
    return const EmptyState(
      icon: Icons.search_off_rounded,
      title: 'Sem resultados',
      subtitle: 'Tente outros termos ou filtros',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withAlpha(50),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: theme.colorScheme.primary.withAlpha(180),
              ),
            )
                .animate(onPlay: (c) => c.repeat(count: 3, reverse: true))
                .scaleXY(
                  begin: 1.0,
                  end: 1.06,
                  duration: 1800.ms,
                  curve: Curves.easeInOut,
                )
                .then()
                .shimmer(
                  duration: 1200.ms,
                  color: theme.colorScheme.primary.withAlpha(40),
                ),
            const SizedBox(height: 24),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            )
                .animate()
                .fadeIn(delay: 200.ms, duration: 400.ms)
                .slideY(begin: 0.1, end: 0, delay: 200.ms, duration: 400.ms),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              )
                  .animate()
                  .fadeIn(delay: 350.ms, duration: 400.ms)
                  .slideY(begin: 0.1, end: 0, delay: 350.ms, duration: 400.ms),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              )
                  .animate()
                  .fadeIn(delay: 500.ms, duration: 400.ms)
                  .scaleXY(begin: 0.9, end: 1.0, delay: 500.ms, duration: 400.ms),
            ],
          ],
        ),
      ),
    );
  }
}
