import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/products_provider.dart';

/// Icon mapping for categories by name/slug
const Map<String, IconData> _categoryIconMap = {
  'todos': Icons.apps_rounded,
  'veículos': Icons.directions_car_rounded,
  'veiculos': Icons.directions_car_rounded,
  'imóveis': Icons.home_work_rounded,
  'imoveis': Icons.home_work_rounded,
  'eletrônicos': Icons.devices_rounded,
  'eletronicos': Icons.devices_rounded,
  'moda': Icons.checkroom_rounded,
  'roupas': Icons.checkroom_rounded,
  'casa': Icons.weekend_rounded,
  'móveis': Icons.chair_rounded,
  'moveis': Icons.chair_rounded,
  'esportes': Icons.sports_soccer_rounded,
  'ferramentas': Icons.build_rounded,
  'brinquedos': Icons.toys_rounded,
  'livros': Icons.menu_book_rounded,
  'alimentos': Icons.restaurant_rounded,
  'saúde': Icons.health_and_safety_rounded,
  'saude': Icons.health_and_safety_rounded,
  'beleza': Icons.spa_rounded,
  'pets': Icons.pets_rounded,
  'jardim': Icons.yard_rounded,
  'bebês': Icons.child_care_rounded,
  'bebes': Icons.child_care_rounded,
  'música': Icons.music_note_rounded,
  'musica': Icons.music_note_rounded,
  'games': Icons.sports_esports_rounded,
  'jogos': Icons.sports_esports_rounded,
  'materiais': Icons.construction_rounded,
  'construção': Icons.construction_rounded,
  'construcao': Icons.construction_rounded,
  'serviços': Icons.handyman_rounded,
  'servicos': Icons.handyman_rounded,
  'produtos': Icons.inventory_2_rounded,
};

IconData _getIconForCategory(String categoryName) {
  final key = categoryName.toLowerCase().trim();
  return _categoryIconMap[key] ?? Icons.category_rounded;
}

/// Horizontal scrollable category tabs with icons (OLX-style)
class CategoryTabs extends ConsumerWidget {
  const CategoryTabs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);

    return categoriesAsync.when(
      loading: () => const _CategoryTabsLoading(),
      error: (_, __) => const SizedBox.shrink(),
      data: (categories) => SizedBox(
        height: 80,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(left: 16, right: 24),
          itemCount: categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 16),
          itemBuilder: (context, index) {
            final category = categories[index];
            final isSelected = category == selectedCategory;
            return _CategoryTab(
              label: category,
              icon: _getIconForCategory(category),
              isSelected: isSelected,
              onTap: () {
                ref.read(selectedCategoryProvider.notifier).state = category;
              },
            );
          },
        ),
      ),
    );
  }
}

class _CategoryTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryTab({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary.withAlpha(20)
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            if (isSelected)
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 20,
                height: 2,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTabsLoading extends StatelessWidget {
  const _CategoryTabsLoading();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (_, __) => SizedBox(
          width: 72,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 40,
                height: 10,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
