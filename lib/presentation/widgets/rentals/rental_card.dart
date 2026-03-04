import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/product_model.dart';

/// Card widget for rental listings — differentiated from ProductCard
class RentalCard extends StatefulWidget {
  final ProductModel rental;

  const RentalCard({super.key, required this.rental});

  @override
  State<RentalCard> createState() => _RentalCardState();
}

class _RentalCardState extends State<RentalCard> {
  bool _isPressed = false;

  String _rentalTypeBadge(ProductModel rental) {
    final ri = rental.rentalInfo;
    if (ri != null) return ri.rentalTypeDisplay;
    return 'Aluguel';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rental = widget.rental;

    return AnimatedScale(
      scale: _isPressed ? 0.96 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeInOut,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          HapticFeedback.selectionClick();
          context.push('/rental/${rental.id}');
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border.withAlpha(40)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top section: image/placeholder with badge
              Expanded(
                flex: 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Image or placeholder
                    rental.images.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: rental.images.first.url,
                            fit: BoxFit.cover,
                            memCacheWidth: 400,
                            fadeInDuration: const Duration(milliseconds: 300),
                            errorWidget: (_, __, ___) => const _RentalPlaceholder(),
                          )
                        : const _RentalPlaceholder(),

                    // Rental type badge (top-left)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withAlpha(80),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          _rentalTypeBadge(rental),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.2, curve: Curves.easeOut),
                    ),
                  ],
                ),
              ),

              // Info section
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Text(
                      rental.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Price
                    Text(
                      rental.rentalPriceDisplay ??
                          'R\$ ${rental.price.toStringAsFixed(rental.price.truncateToDouble() == rental.price ? 0 : 2)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Location
                    if (rental.location?.city != null) ...[
                      const SizedBox(height: 2),
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
                              _formatLocation(rental.location!),
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
                    ],

                    // Relative time
                    const SizedBox(height: 2),
                    Text(
                      Formatters.relativeTime(rental.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant.withAlpha(180),
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

  String _formatLocation(ProductLocation location) {
    final parts = <String>[];
    if (location.city != null) parts.add(location.city!);
    if (location.state != null) parts.add(location.state!);
    return parts.join(' - ');
  }
}

class _RentalPlaceholder extends StatelessWidget {
  const _RentalPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary.withAlpha(25),
      child: Center(
        child: Icon(
          Icons.vpn_key_rounded,
          size: 40,
          color: AppColors.primary.withAlpha(120),
        ),
      ),
    );
  }
}
