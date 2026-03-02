import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';

/// Cart summary widget with optional delivery fee display and animated total
class CartSummary extends StatelessWidget {
  final double total;
  final int itemCount;
  final double? deliveryFee;
  final String? deliveryTierLabel;
  final String? deliveryTier;

  const CartSummary({
    super.key,
    required this.total,
    required this.itemCount,
    this.deliveryFee,
    this.deliveryTierLabel,
    this.deliveryTier,
  });

  double get _grandTotal => total + (deliveryFee ?? 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withAlpha(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Subtotal row with animated item count
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  'Subtotal (${itemCount == 1 ? '1 item' : '$itemCount itens'})',
                  key: ValueKey(itemCount),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              _AnimatedPrice(
                amount: total,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Delivery fee row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                deliveryTierLabel != null
                    ? 'Frete ($deliveryTierLabel)'
                    : 'Frete',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (deliveryTier == 'seller_arranges')
                Text(
                  'A combinar com vendedor',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.tertiary,
                    fontWeight: FontWeight.w500,
                  ),
                )
              else if (deliveryFee != null && deliveryFee! > 0)
                _AnimatedPrice(
                  amount: deliveryFee!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else if (deliveryFee != null && deliveryFee == 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'GRÁTIS',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              else
                Text(
                  'Calcular no próximo passo',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withAlpha(150),
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(thickness: 0.5),
          const SizedBox(height: 12),

          // Total row with animated counter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              _AnimatedPrice(
                amount: _grandTotal,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Animated price widget that smoothly transitions between values
class _AnimatedPrice extends StatelessWidget {
  final double amount;
  final TextStyle? style;

  const _AnimatedPrice({
    required this.amount,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: amount),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Text(
          Formatters.currency(value),
          style: style,
        );
      },
    );
  }
}
