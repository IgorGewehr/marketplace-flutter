import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../providers/products_provider.dart';
import '../../widgets/shared/shimmer_loading.dart';

/// Category selection screen
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final categoriesAsync = ref.watch(categoriesProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Categorias'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: false,
      ),
      body: categoriesAsync.when(
        loading: () => const ShimmerLoading(itemCount: 8, isGrid: false, height: 56),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Erro ao carregar categorias',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Tente novamente mais tarde',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => ref.invalidate(categoriesProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
        data: (categories) => ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: categories.length,
          separatorBuilder: (_, __) => Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: theme.colorScheme.outline.withAlpha(30),
          ),
          itemBuilder: (context, index) {
            final category = categories[index];
            final isSelected = category == selectedCategory;
            final isAll = index == 0; // "Todos" is always first

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              title: Text(
                isAll ? 'Todas as categorias' : category,
                style: TextStyle(
                  color: isSelected ? theme.colorScheme.primary : null,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 16,
                ),
              ),
              trailing: isSelected
                  ? Icon(
                      Icons.check_rounded,
                      color: theme.colorScheme.primary,
                    )
                  : Icon(
                      Icons.chevron_right,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
              onTap: () {
                ref.read(selectedCategoryProvider.notifier).state = category;
                // Apply category ID (not name) to search filters
                final nameToId = ref.read(categoryNameToIdProvider).valueOrNull ?? {};
                final categoryId = isAll ? null : (nameToId[category] ?? category);
                ref.read(productFiltersProvider.notifier).state =
                    ref.read(productFiltersProvider).copyWith(
                          category: categoryId,
                          page: 1,
                        );
                context.pop();
              },
            )
                .animate(delay: Duration(milliseconds: (index % 8) * 60))
                .fadeIn(duration: 300.ms, curve: Curves.easeOut)
                .slideY(begin: 0.08, end: 0, duration: 300.ms, curve: Curves.easeOut);
          },
        ),
      ),
    );
  }
}
