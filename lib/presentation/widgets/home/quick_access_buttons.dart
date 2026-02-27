import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';

/// Grid of quick access buttons (Favoritos, Promoções, Serviços, Categorias)
class QuickAccessButtons extends StatelessWidget {
  const QuickAccessButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _QuickButton(
            icon: Icons.favorite_rounded,
            color: AppColors.quickFavorites,
            label: 'Favoritos',
            onTap: () => context.push(AppRouter.favorites),
          ),
          _QuickButton(
            icon: Icons.percent_rounded,
            color: AppColors.quickPromo,
            label: 'Promoções',
            onTap: () => context.push(AppRouter.search),
          ),
          _QuickButton(
            icon: Icons.build_rounded,
            color: AppColors.quickServices,
            label: 'Serviços',
            onTap: () => context.push(AppRouter.services),
          ),
          _QuickButton(
            icon: Icons.grid_view_rounded,
            color: AppColors.quickCategories,
            label: 'Categorias',
            onTap: () => context.push(AppRouter.categories),
          ),
        ],
      ),
    );
  }
}

class _QuickButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _QuickButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 76,
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
