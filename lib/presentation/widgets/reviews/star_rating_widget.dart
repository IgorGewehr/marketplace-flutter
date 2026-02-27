import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';

/// Interactive star rating widget (tap to select 1–5).
class StarRatingWidget extends StatelessWidget {
  final double rating;
  final ValueChanged<double>? onChanged; // null → read-only
  final double size;
  final Color? activeColor;
  final MainAxisAlignment alignment;

  const StarRatingWidget({
    super.key,
    required this.rating,
    this.onChanged,
    this.size = 32,
    this.activeColor,
    this.alignment = MainAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final color = activeColor ?? AppColors.rating;
    return Row(
      mainAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final starValue = i + 1.0;
        final isActive = rating >= starValue;
        final isHalf = !isActive && rating >= starValue - 0.5;

        final icon = isActive
            ? Icons.star_rounded
            : isHalf
                ? Icons.star_half_rounded
                : Icons.star_outline_rounded;

        if (onChanged == null) {
          return Icon(icon, size: size, color: isActive || isHalf ? color : AppColors.ratingInactive);
        }

        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged!(starValue);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Icon(icon, size: size, color: isActive || isHalf ? color : AppColors.ratingInactive),
          ),
        );
      }),
    );
  }
}

/// Small read-only stars for cards/lists.
class StarRatingCompact extends StatelessWidget {
  final double rating;
  final double size;

  const StarRatingCompact({super.key, required this.rating, this.size = 14});

  @override
  Widget build(BuildContext context) {
    return StarRatingWidget(rating: rating, size: size);
  }
}
