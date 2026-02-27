import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/product_model.dart';

/// Modern, compact product card for seller's product list.
/// Primary tap → edit. Bottom action row for quick status toggle.
/// ⋮ popup for duplicate / delete.
class MyProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback? onTap;
  final VoidCallback? onToggleStatus;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onDuplicate;

  const MyProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.onToggleStatus,
    this.onEdit,
    this.onDelete,
    this.onDuplicate,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = product.status == 'active';
    final isPaused = product.status == 'draft';

    final Color statusColor;
    final String statusLabel;
    if (isActive) {
      statusColor = AppColors.secondary;
      statusLabel = 'Ativo';
    } else if (isPaused) {
      statusColor = AppColors.textHint;
      statusLabel = 'Pausado';
    } else {
      statusColor = AppColors.warning;
      statusLabel = 'Sem estoque';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Main content row ──────────────────────────────────
              // IntrinsicHeight is required because this Row uses
              // CrossAxisAlignment.stretch (for the status accent bar)
              // inside a SliverList child whose maxHeight is unbounded.
              // Without it, stretch forces infinite height on children,
              // which silently breaks layout in release mode.
              IntrinsicHeight(
                child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Status accent bar
                  Container(
                    width: 4,
                    constraints: const BoxConstraints(minHeight: 110),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(15),
                      ),
                    ),
                  ),

                  // Product image
                  SizedBox(
                    width: 110,
                    height: 110,
                    child: _ProductImage(url: product.mainImageUrl),
                  ),

                  // Info
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Name + more menu
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  product.name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                    height: 1.35,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              _MoreMenu(
                                onDuplicate: onDuplicate,
                                onDelete: onDelete,
                              ),
                            ],
                          ),

                          // Price
                          Text(
                            Formatters.currency(product.price),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.sellerAccent,
                            ),
                          ),

                          // Status + stats
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                statusLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                ),
                              ),
                              if (product.marketplaceStats != null) ...[
                                const SizedBox(width: 10),
                                const Icon(
                                  Icons.visibility_outlined,
                                  size: 12,
                                  color: AppColors.textHint,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${product.marketplaceStats!.views}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textHint,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.shopping_bag_outlined,
                                  size: 12,
                                  color: AppColors.textHint,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${product.marketplaceStats!.sales}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textHint,
                                  ),
                                ),
                              ],
                              if (product.quantity != null) ...[
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 12,
                                  color: product.quantity! <= 3
                                      ? AppColors.error
                                      : AppColors.textHint,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '${product.quantity}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: product.quantity! <= 3
                                        ? AppColors.error
                                        : AppColors.textHint,
                                    fontWeight: product.quantity! <= 3
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              ),

              // ── Divider ─────────────────────────────────────────
              const Divider(height: 1, thickness: 1, color: AppColors.borderLight),

              // ── Action row ───────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.edit_rounded,
                        label: 'Editar',
                        color: AppColors.sellerAccent,
                        onTap: onEdit,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionButton(
                        icon: isActive
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        label: isActive ? 'Pausar' : 'Ativar',
                        color: isActive
                            ? AppColors.textSecondary
                            : AppColors.secondary,
                        outlined: true,
                        onTap: onToggleStatus,
                      ),
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

// ────────────────────────────────────────────────────────────

class _ProductImage extends StatelessWidget {
  final String? url;
  const _ProductImage({this.url});

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url!,
        fit: BoxFit.cover,
        memCacheWidth: 220,
        placeholder: (context, url) => Container(color: AppColors.surfaceVariant),
        errorWidget: (context, url, error) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() => Container(
        color: AppColors.surfaceVariant,
        child: const Center(
          child: Icon(Icons.image_outlined, size: 32, color: AppColors.textHint),
        ),
      );
}

// ────────────────────────────────────────────────────────────

class _MoreMenu extends StatelessWidget {
  final VoidCallback? onDuplicate;
  final VoidCallback? onDelete;

  const _MoreMenu({this.onDuplicate, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 30,
      child: PopupMenuButton<String>(
        padding: EdgeInsets.zero,
        iconSize: 20,
        icon: const Icon(Icons.more_vert_rounded, color: AppColors.textHint),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
        onSelected: (value) {
          if (value == 'duplicate') onDuplicate?.call();
          if (value == 'delete') onDelete?.call();
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            value: 'duplicate',
            child: Row(
              children: const [
                Icon(Icons.copy_outlined, size: 18, color: AppColors.textSecondary),
                SizedBox(width: 10),
                Text('Duplicar'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: const [
                Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                SizedBox(width: 10),
                Text('Excluir', style: TextStyle(color: AppColors.error)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool outlined;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.outlined = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final style = outlined
        ? OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color.withAlpha(100)),
            padding: const EdgeInsets.symmetric(vertical: 9),
            minimumSize: const Size(0, 0),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          )
        : FilledButton.styleFrom(
            backgroundColor: color.withAlpha(20),
            foregroundColor: color,
            padding: const EdgeInsets.symmetric(vertical: 9),
            minimumSize: const Size(0, 0),
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          );

    if (outlined) {
      return OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: style,
      );
    }
    return FilledButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: style,
    );
  }
}
