import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/product_model.dart';
import '../../providers/products_provider.dart';

/// Enhanced product card widget - OLX style layout
/// Shows: image with photo count + favorite + badges, price, name, location, relative time
class ProductCard extends ConsumerWidget {
  final ProductModel product;
  final bool showBadge;

  const ProductCard({
    super.key,
    required this.product,
    this.showBadge = true,
  });

  /// Check if product was created less than 24 hours ago
  bool get _isNew {
    final diff = DateTime.now().difference(product.createdAt);
    return diff.inHours < 24;
  }

  /// Check if product has a discount (negotiable or compare-at price)
  bool get _hasDiscount => product.hasDiscount;

  /// Get discount percentage
  int get _discountPercent => product.discountPercentage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isFavorite = ref.watch(isProductFavoriteProvider(product.id));
    final photoCount = product.images.length;

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppSpacing.radiusM),
      elevation: 0,
      child: InkWell(
        onTap: () => context.push('/product/${product.id}'),
        borderRadius: BorderRadius.circular(AppSpacing.radiusM),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusM),
            border: Border.all(color: AppColors.border.withAlpha(40)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product image with overlays
              Expanded(
                flex: 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Image
                    product.images.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: product.images.first.url,
                            fit: BoxFit.cover,
                            memCacheWidth: 400,
                            placeholder: (_, __) => Container(
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: const Icon(
                                Icons.image_outlined,
                                size: 40,
                                color: Colors.grey,
                              ),
                            ),
                            errorWidget: (_, __, ___) => Container(
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: const Icon(
                                Icons.broken_image_outlined,
                                size: 40,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: const Icon(
                              Icons.inventory_2_outlined,
                              size: 40,
                              color: Colors.grey,
                            ),
                          ),

                    // Top-left badges column (Novo, Desconto)
                    Positioned(
                      top: AppSpacing.s,
                      left: AppSpacing.s,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_isNew && showBadge)
                            _ProductBadge(
                              label: 'NOVO',
                              color: AppColors.secondary,
                            ),
                          if (_hasDiscount && showBadge) ...[
                            if (_isNew) const SizedBox(height: AppSpacing.xs),
                            _ProductBadge(
                              label: '-$_discountPercent%',
                              color: AppColors.error,
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Favorite button (top right) - 44px touch target
                    Positioned(
                      top: AppSpacing.xs,
                      right: AppSpacing.xs,
                      child: Semantics(
                        label: isFavorite ? 'Remover dos favoritos' : 'Adicionar aos favoritos',
                        button: true,
                        child: SizedBox(
                          width: AppSpacing.touchTarget,
                          height: AppSpacing.touchTarget,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                ref
                                    .read(favoriteProductIdsProvider.notifier)
                                    .toggleFavorite(product.id);
                              },
                              customBorder: const CircleBorder(),
                            child: Center(
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(230),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(15),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  isFavorite ? Icons.favorite : Icons.favorite_border,
                                  color: isFavorite
                                      ? Colors.red
                                      : theme.colorScheme.onSurfaceVariant,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      ),
                    ),

                    // Photo count badge (bottom right)
                    if (photoCount > 1)
                      Positioned(
                        bottom: AppSpacing.s,
                        right: AppSpacing.s,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(150),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusXS),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.camera_alt_outlined,
                                color: Colors.white,
                                size: 12,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '1/$photoCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Product info
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Price with discount
                    if (product.hasDiscount) ...[
                      Text(
                        Formatters.currency(product.compareAtPrice!),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          decoration: TextDecoration.lineThrough,
                          fontSize: 11,
                        ),
                      ),
                    ],
                    Text(
                      Formatters.currency(product.price),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),

                    // Product name
                    Text(
                      product.name,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),

                    // Location
                    if (product.location?.city != null) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              _formatLocation(product.location!),
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                    ],

                    // Relative time with rating
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            Formatters.relativeTime(product.createdAt),
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant.withAlpha(180),
                            ),
                          ),
                        ),
                        if (product.rating > 0) ...[
                          Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            product.rating.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
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

  String _formatLocation(ProductLocation location) {
    final parts = <String>[];
    if (location.city != null) parts.add(location.city!);
    if (location.state != null) parts.add(location.state!);
    return parts.join(' - ');
  }
}

/// Product badge widget (NOVO, -X%, etc.)
class _ProductBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _ProductBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXS),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(60),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
