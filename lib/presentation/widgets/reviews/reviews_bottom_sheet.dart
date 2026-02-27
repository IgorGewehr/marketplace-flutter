import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/review_model.dart';
import '../../providers/review_provider.dart';
import 'review_tile.dart';
import 'star_rating_widget.dart';

// ============================================================================
// Summary button — shows avg rating; opens modal on tap when reviews exist.
// ============================================================================

class ReviewsSummaryButton extends ConsumerWidget {
  final double averageRating;
  final int totalReviews;
  final VoidCallback? onTap; // null when no reviews

  const ReviewsSummaryButton({
    super.key,
    required this.averageRating,
    required this.totalReviews,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hasReviews = totalReviews > 0;

    return GestureDetector(
      onTap: hasReviews ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: hasReviews
              ? AppColors.rating.withAlpha(25)
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: hasReviews
                ? AppColors.rating.withAlpha(80)
                : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.star_rounded,
              color: hasReviews ? AppColors.rating : AppColors.ratingInactive,
              size: 18,
            ),
            const SizedBox(width: 5),
            Text(
              hasReviews
                  ? '${averageRating.toStringAsFixed(1)}  ·  $totalReviews ${totalReviews == 1 ? 'avaliação' : 'avaliações'}'
                  : 'Sem avaliações',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: hasReviews ? FontWeight.w600 : FontWeight.w400,
                color: hasReviews
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (hasReviews) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_right_rounded,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Reviews bottom sheet
// ============================================================================

/// Opens a modal bottom sheet with rating summary + review list.
void showReviewsBottomSheet(
  BuildContext context, {
  required String targetLabel, // e.g. product name or seller name
  required List<ReviewModel> reviews,
  required double averageRating,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ReviewsBottomSheet(
      targetLabel: targetLabel,
      reviews: reviews,
      averageRating: averageRating,
    ),
  );
}

class _ReviewsBottomSheet extends StatefulWidget {
  final String targetLabel;
  final List<ReviewModel> reviews;
  final double averageRating;

  const _ReviewsBottomSheet({
    required this.targetLabel,
    required this.reviews,
    required this.averageRating,
  });

  @override
  State<_ReviewsBottomSheet> createState() => _ReviewsBottomSheetState();
}

class _ReviewsBottomSheetState extends State<_ReviewsBottomSheet> {
  int? _filterStars; // null = all

  List<ReviewModel> get _filtered {
    if (_filterStars == null) return widget.reviews;
    return widget.reviews.where((r) => r.rating.round() == _filterStars).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reviews = widget.reviews;
    final avg = widget.averageRating;

    // Compute distribution
    final Map<int, int> dist = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (final r in reviews) {
      final star = r.rating.round().clamp(1, 5);
      dist[star] = (dist[star] ?? 0) + 1;
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Avaliações',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (widget.targetLabel.isNotEmpty)
                            Text(
                              widget.targetLabel,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Scrollable content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Rating summary row
                    _RatingSummary(
                      average: avg,
                      total: reviews.length,
                      distribution: dist,
                    ),

                    const SizedBox(height: 16),

                    // Filter chips
                    _FilterChips(
                      selected: _filterStars,
                      distribution: dist,
                      onSelect: (star) {
                        setState(() => _filterStars = star);
                      },
                    ),

                    const SizedBox(height: 16),

                    // Review list
                    if (_filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.star_outline_rounded,
                              size: 48,
                              color: theme.colorScheme.outlineVariant,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Nenhuma avaliação com $_filterStars estrela${_filterStars == 1 ? '' : 's'}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...List.generate(
                        _filtered.length,
                        (i) => ReviewTile(review: _filtered[i], index: i),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================================
// Rating summary widget
// ============================================================================

class _RatingSummary extends StatelessWidget {
  final double average;
  final int total;
  final Map<int, int> distribution;

  const _RatingSummary({
    required this.average,
    required this.total,
    required this.distribution,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.rating.withAlpha(15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.rating.withAlpha(50)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Big average number
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                average.toStringAsFixed(1),
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.ratingDark,
                ),
              ),
              StarRatingWidget(
                rating: average,
                size: 16,
                activeColor: AppColors.rating,
                alignment: MainAxisAlignment.center,
              ),
              const SizedBox(height: 2),
              Text(
                '$total ${total == 1 ? 'avaliação' : 'avaliações'}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),

          const SizedBox(width: 20),

          // Distribution bars
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (i) {
                final star = 5 - i;
                final count = distribution[star] ?? 0;
                final fraction = total > 0 ? count / total : 0.0;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Text(
                        '$star',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.ratingDark,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: fraction,
                            minHeight: 6,
                            backgroundColor: AppColors.ratingInactive,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.rating,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 20,
                        child: Text(
                          '$count',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0);
  }
}

// ============================================================================
// Filter chips
// ============================================================================

class _FilterChips extends StatelessWidget {
  final int? selected;
  final Map<int, int> distribution;
  final ValueChanged<int?> onSelect;

  const _FilterChips({
    required this.selected,
    required this.distribution,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // "All" chip
          _Chip(
            label: 'Todas',
            isSelected: selected == null,
            onTap: () => onSelect(null),
            theme: theme,
          ),
          const SizedBox(width: 8),
          ...List.generate(5, (i) {
            final star = 5 - i;
            final count = distribution[star] ?? 0;
            if (count == 0) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _Chip(
                label: '$star ★  $count',
                isSelected: selected == star,
                onTap: () => onSelect(star),
                theme: theme,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final ThemeData theme;

  const _Chip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: isSelected ? Colors.white : theme.colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Submit review bottom sheet
// ============================================================================

/// Opens the review submission form for a single product.
void showSubmitReviewSheet(
  BuildContext context, {
  required String productId,
  required String tenantId,
  required String orderId,
  required String productName,
  String? productImageUrl,
  required VoidCallback onSuccess,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: _SubmitReviewSheet(
        productId: productId,
        tenantId: tenantId,
        orderId: orderId,
        productName: productName,
        productImageUrl: productImageUrl,
        onSuccess: onSuccess,
      ),
    ),
  );
}

class _SubmitReviewSheet extends ConsumerStatefulWidget {
  final String productId;
  final String tenantId;
  final String orderId;
  final String productName;
  final String? productImageUrl;
  final VoidCallback onSuccess;

  const _SubmitReviewSheet({
    required this.productId,
    required this.tenantId,
    required this.orderId,
    required this.productName,
    this.productImageUrl,
    required this.onSuccess,
  });

  @override
  ConsumerState<_SubmitReviewSheet> createState() => _SubmitReviewSheetState();
}

class _SubmitReviewSheetState extends ConsumerState<_SubmitReviewSheet> {
  double _rating = 0;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final submitState = ref.watch(reviewSubmitProvider);

    final labels = ['', 'Terrível', 'Ruim', 'Ok', 'Bom', 'Excelente'];

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            'Avaliar produto',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Product info
          Row(
            children: [
              if (widget.productImageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    widget.productImageUrl!,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(width: 52, height: 52),
                  ),
                ),
              if (widget.productImageUrl != null) const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.productName,
                  style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Stars
          Center(
            child: Column(
              children: [
                StarRatingWidget(
                  rating: _rating,
                  size: 44,
                  alignment: MainAxisAlignment.center,
                  onChanged: (v) => setState(() => _rating = v),
                ),
                const SizedBox(height: 6),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: Text(
                    _rating > 0 ? labels[_rating.round()] : 'Toque para avaliar',
                    key: ValueKey(_rating),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _rating > 0
                          ? AppColors.ratingDark
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: _rating > 0 ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Comment
          TextField(
            controller: _commentController,
            maxLines: 3,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: 'Deixe um comentário (opcional)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),

          const SizedBox(height: 16),

          // Error
          if (submitState.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                submitState.error!,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
              ),
            ),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: submitState.isLoading || _rating == 0
                  ? null
                  : () async {
                      final success = await ref.read(reviewSubmitProvider.notifier).submit(
                            productId: widget.productId,
                            tenantId: widget.tenantId,
                            orderId: widget.orderId,
                            rating: _rating,
                            comment: _commentController.text.trim().isEmpty
                                ? null
                                : _commentController.text.trim(),
                          );
                      if (success && context.mounted) {
                        Navigator.of(context).pop();
                        widget.onSuccess();
                      }
                    },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: AppColors.primary,
              ),
              child: submitState.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      _rating == 0 ? 'Selecione uma nota' : 'Enviar avaliação',
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
