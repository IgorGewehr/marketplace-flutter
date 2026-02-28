import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

class _CartItemTileState extends State<CartItemTile> {
  Timer? _repeatTimer;

  @override
  void dispose() {
    _repeatTimer?.cancel();
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
      onDismissed: (_) => widget.onRemove(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: theme.colorScheme.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.delete_outline,
          color: Colors.white,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
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
            // Product image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: widget.item.productImage != null
                  ? CachedNetworkImage(
                      imageUrl: widget.item.productImage!,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      memCacheWidth: 160,
                      placeholder: (_, __) => _imagePlaceholder(theme),
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
                  Text(
                    Formatters.currency(widget.item.price),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),

            // Quantity selector
            Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
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
                                top: Radius.circular(8),
                              ),
                            ),
                            child: const Icon(
                              Icons.add,
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: Text(
                          '${widget.item.quantity}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
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
                                bottom: Radius.circular(8),
                              ),
                            ),
                            child: Icon(
                              widget.item.quantity > 1
                                  ? Icons.remove
                                  : Icons.delete_outline,
                              size: 18,
                              color: widget.item.quantity > 1
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.error,
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

  Widget _imagePlaceholder(ThemeData theme) {
    return Container(
      width: 80,
      height: 80,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.image_outlined,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
