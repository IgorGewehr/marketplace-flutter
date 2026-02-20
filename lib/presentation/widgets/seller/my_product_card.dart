import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/product_model.dart';

/// Horizontal product card for seller's product list with visible actions
class MyProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback? onTap;
  final VoidCallback? onToggleStatus;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const MyProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.onToggleStatus,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = product.status == 'active';
    final isPaused = product.status == 'draft';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPaused ? AppColors.textHint.withAlpha(50) : AppColors.border,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Opacity(
          opacity: isPaused ? 0.7 : 1.0,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image with status badge
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                      child: product.mainImageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: product.mainImageUrl!,
                              fit: BoxFit.cover,
                              memCacheWidth: 200,
                              placeholder: (context, url) => Container(
                                color: AppColors.surfaceVariant,
                                child: const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: AppColors.surfaceVariant,
                                child: const Icon(Icons.image_not_supported),
                              ),
                            )
                          : Container(
                              color: AppColors.surfaceVariant,
                              child: const Icon(Icons.image, size: 32),
                            ),
                    ),
                    Positioned(
                      top: 6,
                      left: 6,
                      child: _StatusBadge(
                        status: product.status,
                        isActive: isActive,
                      ),
                    ),
                  ],
                ),
              ),

              // Info + actions
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name
                      Text(
                        product.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      // Price
                      Text(
                        Formatters.currency(product.price),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.sellerAccent,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Stats row
                      Row(
                        children: [
                          if (product.marketplaceStats != null) ...[
                            const Icon(Icons.visibility_outlined, size: 13, color: AppColors.textHint),
                            const SizedBox(width: 3),
                            Text(
                              '${product.marketplaceStats!.views}',
                              style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                            ),
                            const SizedBox(width: 10),
                            const Icon(Icons.shopping_bag_outlined, size: 13, color: AppColors.textHint),
                            const SizedBox(width: 3),
                            Text(
                              '${product.marketplaceStats!.sales}',
                              style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                            ),
                            const SizedBox(width: 10),
                          ],
                          if (product.quantity != null) ...[
                            const Icon(Icons.inventory_2_outlined, size: 13, color: AppColors.textHint),
                            const SizedBox(width: 3),
                            Text(
                              '${product.quantity}',
                              style: TextStyle(
                                fontSize: 11,
                                color: product.quantity! <= 3 ? AppColors.error : AppColors.textHint,
                                fontWeight: product.quantity! <= 3 ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Action buttons column
              Padding(
                padding: const EdgeInsets.only(right: 4, top: 6, bottom: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ActionIconButton(
                      icon: Icons.edit_outlined,
                      color: AppColors.sellerAccent,
                      onTap: onEdit,
                      tooltip: 'Editar',
                    ),
                    _ActionIconButton(
                      icon: isActive ? Icons.pause_circle_outline : Icons.play_circle_outline,
                      color: isActive ? AppColors.textHint : AppColors.secondary,
                      onTap: onToggleStatus,
                      tooltip: isActive ? 'Pausar' : 'Ativar',
                    ),
                    _ActionIconButton(
                      icon: Icons.delete_outline,
                      color: AppColors.error,
                      onTap: onDelete,
                      tooltip: 'Excluir',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final String tooltip;

  const _ActionIconButton({
    required this.icon,
    required this.color,
    this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: color),
        padding: EdgeInsets.zero,
        tooltip: tooltip,
        splashRadius: 18,
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final bool isActive;

  const _StatusBadge({
    required this.status,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;
    String label;
    IconData icon;

    switch (status) {
      case 'active':
        bgColor = AppColors.secondary.withAlpha(200);
        textColor = Colors.white;
        label = 'Ativo';
        icon = Icons.check_circle;
        break;
      case 'draft':
        bgColor = AppColors.textHint.withAlpha(200);
        textColor = Colors.white;
        label = 'Pausado';
        icon = Icons.pause_circle;
        break;
      default:
        bgColor = AppColors.warning.withAlpha(200);
        textColor = Colors.white;
        label = 'Sem estoque';
        icon = Icons.warning;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textColor, size: 10),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
