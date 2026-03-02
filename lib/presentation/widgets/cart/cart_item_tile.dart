import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/utils/formatters.dart';
import '../../providers/cart_provider.dart';

/// Cart item tile with swipe to delete and long-press repeat for quantity
class CartItemTile extends StatefulWidget {
  final LocalCartItem item;
  final VoidCallback onRemove;
  final ValueChanged<int> onQuantityChanged;

  const CartItemTile({
    super.key,
    required this.item,
    required this.onRemove,
    required this.onQuantityChanged,
  });

  @override
  State<CartItemTile> createState() => _CartItemTileState();
}

class _CartItemTileState extends State<CartItemTile>
    with SingleTickerProviderStateMixin {
  Timer? _repeatTimer;
  late AnimationController _quantityBounceController;
  late Animation<double> _quantityBounceAnimation;

  @override
  void initState() {
    super.initState();
    _quantityBounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _quantityBounceAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 0.95), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(
      parent: _quantityBounceController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void didUpdateWidget(CartItemTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.quantity != widget.item.quantity) {
      _quantityBounceController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _repeatTimer?.cancel();
    _quantityBounceController.dispose();
    super.dispose();
  }

  void _increment() {
    HapticFeedback.selectionClick();
    widget.onQuantityChanged(widget.item.quantity + 1);
  }

  void _decrement() {
    HapticFeedback.selectionClick();
    if (widget.item.quantity > 1) {
      widget.onQuantityChanged(widget.item.quantity - 1);
    } else {
      widget.onRemove();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dismissible(
      key: Key('${widget.item.productId}_${widget.item.variant}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        HapticFeedback.mediumImpact();
        return true;
      },
      onDismissed: (_) => widget.onRemove(),
      background: _DismissBackground(),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outline.withAlpha(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Product image with shimmer placeholder
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: widget.item.productImage != null
                  ? CachedNetworkImage(
                      imageUrl: widget.item.productImage!,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      memCacheWidth: 160,
                      fadeInDuration: const Duration(milliseconds: 250),
                      placeholder: (_, __) => _shimmerPlaceholder(theme),
                      errorWidget: (_, __, ___) => _imagePlaceholder(theme),
                    )
                  : _imagePlaceholder(theme),
            ),
            const SizedBox(width: 12),

            // Product info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.productName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.item.variant != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.item.variant!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  // Animated price display
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.3),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: Text(
                      Formatters.currency(widget.item.price * widget.item.quantity),
                      key: ValueKey(widget.item.price * widget.item.quantity),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  if (widget.item.quantity > 1)
                    AnimatedOpacity(
                      opacity: 1.0,
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        '${Formatters.currency(widget.item.price)} /un',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withAlpha(160),
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Quantity selector with bounce animation
            Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Tooltip(
                        message: 'Aumentar quantidade',
                        child: GestureDetector(
                          onTap: _increment,
                          onLongPressStart: (_) {
                            _repeatTimer = Timer.periodic(
                              const Duration(milliseconds: 150),
                              (_) => _increment(),
                            );
                          },
                          onLongPressEnd: (_) {
                            _repeatTimer?.cancel();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(15),
                            decoration: const BoxDecoration(
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(10),
                              ),
                            ),
                            child: Icon(
                              Icons.add,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: ScaleTransition(
                          scale: _quantityBounceAnimation,
                          child: Text(
                            '${widget.item.quantity}',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      Tooltip(
                        message: widget.item.quantity > 1
                            ? 'Diminuir quantidade'
                            : 'Remover item',
                        child: GestureDetector(
                          onTap: _decrement,
                          onLongPressStart: widget.item.quantity > 1
                              ? (_) {
                                  _repeatTimer = Timer.periodic(
                                    const Duration(milliseconds: 150),
                                    (_) => _decrement(),
                                  );
                                }
                              : null,
                          onLongPressEnd: widget.item.quantity > 1
                              ? (_) {
                                  _repeatTimer?.cancel();
                                }
                              : null,
                          child: Container(
                            padding: const EdgeInsets.all(15),
                            decoration: const BoxDecoration(
                              borderRadius: BorderRadius.vertical(
                                bottom: Radius.circular(10),
                              ),
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              transitionBuilder: (child, animation) =>
                                  ScaleTransition(scale: animation, child: child),
                              child: Icon(
                                widget.item.quantity > 1
                                    ? Icons.remove
                                    : Icons.delete_outline,
                                key: ValueKey(widget.item.quantity > 1),
                                size: 18,
                                color: widget.item.quantity > 1
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.error,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _shimmerPlaceholder(ThemeData theme) {
    return Shimmer.fromColors(
      baseColor: theme.colorScheme.surfaceContainerHighest,
      highlightColor: theme.colorScheme.surface,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _imagePlaceholder(ThemeData theme) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        Icons.image_outlined,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// Enhanced dismiss background with icon animation
class _DismissBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.error.withAlpha(20),
            theme.colorScheme.error.withAlpha(200),
            theme.colorScheme.error,
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.delete_outline_rounded,
            color: Colors.white,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            'Remover',
            style: TextStyle(
              color: Colors.white.withAlpha(230),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
