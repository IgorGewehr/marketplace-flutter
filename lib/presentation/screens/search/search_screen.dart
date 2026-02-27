import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../providers/follows_provider.dart';
import '../../providers/products_provider.dart';
import '../../widgets/home/section_header.dart';
import '../../widgets/products/product_carousel.dart';
import '../../widgets/search/search_filters_sheet.dart';
import '../../widgets/search/search_product_list_card.dart';
import '../../widgets/shared/empty_state.dart';
import '../../widgets/shared/shimmer_loading.dart';

/// Search / Explorar screen with action chips and list layout
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounceTimer; // Gap #11: Debounce search

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // Gap #11: Debounce search queries to avoid per-keystroke Firestore calls
  void _onSearchChanged() {
    setState(() {});

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        final query = _searchController.text;
        ref.read(searchQueryProvider.notifier).state = query;
        final filters = ref.read(productFiltersProvider);
        ref.read(productFiltersProvider.notifier).state = filters.copyWith(
          query: query,
          page: 1,
        );
      }
    });
  }

  void _performSearch(String query) {
    if (query.isEmpty) return;

    ref.read(searchHistoryProvider.notifier).addSearch(query);

    final filters = ref.read(productFiltersProvider);
    ref.read(productFiltersProvider.notifier).state = filters.copyWith(
      query: query,
      page: 1,
    );

    setState(() {});
    _focusNode.unfocus();
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => const SearchFiltersSheet(),
      ),
    );
  }

  void _showSortSheet() {
    final currentSort = ref.read(productFiltersProvider).sortBy;
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withAlpha(50),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Ordenar por',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _SortOption(
              label: 'Mais recentes',
              value: 'recent',
              isSelected: currentSort == 'recent',
              onTap: () => _applySort('recent'),
            ),
            _SortOption(
              label: 'Menor preço',
              value: 'price_asc',
              isSelected: currentSort == 'price_asc',
              onTap: () => _applySort('price_asc'),
            ),
            _SortOption(
              label: 'Maior preço',
              value: 'price_desc',
              isSelected: currentSort == 'price_desc',
              onTap: () => _applySort('price_desc'),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }

  void _applySort(String sortBy) {
    final filters = ref.read(productFiltersProvider);
    ref.read(productFiltersProvider.notifier).state = filters.copyWith(
      sortBy: sortBy,
      page: 1,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final history = ref.watch(searchHistoryProvider);
    final resultsState = ref.watch(filteredProductsProvider);
    final filters = ref.watch(productFiltersProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    final followedIds = ref.watch(followsProvider);

    // Determine if we should show carousels or vertical list
    final hasActiveFilters = (filters.query != null && filters.query!.isNotEmpty) ||
        (filters.category != null && filters.category != 'Todos') ||
        filters.minPrice != null ||
        filters.maxPrice != null ||
        filters.followedOnly;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.go('/'),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Expanded(
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: theme.colorScheme.outline.withAlpha(30),
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _focusNode,
                        textInputAction: TextInputAction.search,
                        onSubmitted: _performSearch,
                        decoration: InputDecoration(
                          hintText: 'Buscar no Compre Aqui',
                          prefixIcon: const Icon(Icons.search, size: 22),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                    ref.read(productFiltersProvider.notifier).state =
                                        const ProductFilters();
                                  },
                                  icon: const Icon(Icons.close, size: 20),
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Action chips
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    // History chip — clears search to reveal history panel
                    _ActionChip(
                      icon: Icons.history,
                      label: 'Histórico',
                      onTap: () {
                        _searchController.clear();
                        ref.read(productFiltersProvider.notifier).state =
                            const ProductFilters();
                        setState(() {});
                      },
                    ),
                    const SizedBox(width: 8),
                    // Filters chip with badge
                    _ActionChip(
                      icon: Icons.tune,
                      label: 'Filtros',
                      badgeCount: filters.activeFilterCount,
                      onTap: _showFilters,
                    ),
                    const SizedBox(width: 8),
                    // Seguindo chip — only shown when following at least one seller
                    if (followedIds.isNotEmpty) ...[
                      _ActionChip(
                        icon: Icons.people_alt_outlined,
                        label: 'Seguindo',
                        isActive: filters.followedOnly,
                        onTap: () {
                          ref.read(productFiltersProvider.notifier).state =
                              ref.read(productFiltersProvider).copyWith(
                                    followedOnly: !filters.followedOnly,
                                    page: 1,
                                  );
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                    // Sort chip
                    _ActionChip(
                      icon: Icons.sort,
                      label: 'Ordenar',
                      onTap: _showSortSheet,
                    ),
                    const SizedBox(width: 8),
                    // Categories chip
                    _ActionChip(
                      icon: Icons.grid_view_rounded,
                      label: 'Categorias',
                      hasChevron: true,
                      onTap: () => context.push(AppRouter.categories),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Content — Gap #4: Show search history when no query/filters active
            Expanded(
              child: hasActiveFilters
                  ? _buildResults(resultsState, filters.query)
                  : _searchController.text.isEmpty && history.isNotEmpty
                      ? _buildSearchHistory(history)
                      : categoriesAsync.when(
                          loading: () => const ShimmerLoading(itemCount: 4),
                          error: (_, __) => const Center(child: Text('Erro ao carregar categorias')),
                          data: (categories) => _buildCategoryCarousels(categories),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCarousels(List<String> categories) {
    // Filter out 'Todos' from carousel display
    final displayCategories = categories.where((c) => c != 'Todos').toList();

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: displayCategories.length,
      itemBuilder: (context, index) {
        final category = displayCategories[index];
        final productsAsync = ref.watch(productsByCategoryProvider(category));

        return productsAsync.when(
          loading: () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 12),
                child: SectionHeader(
                  title: category,
                  actionLabel: 'Ver todos',
                  onActionPressed: () {
                    ref.read(selectedCategoryProvider.notifier).state = category;
                    final nameToId = ref.read(categoryNameToIdProvider).valueOrNull ?? {};
                    final categoryId = nameToId[category] ?? category;
                    ref.read(productFiltersProvider.notifier).state =
                        ref.read(productFiltersProvider).copyWith(
                              category: categoryId,
                              page: 1,
                            );
                  },
                ),
              ),
              const ProductCarousel(isLoading: true),
              const SizedBox(height: 16),
            ],
          ),
          error: (_, __) => const SizedBox.shrink(), // Hide section on error
          data: (products) {
            // Only show section if there are products
            if (products.isEmpty) return const SizedBox.shrink();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 12),
                  child: SectionHeader(
                    title: category,
                    actionLabel: 'Ver todos',
                    onActionPressed: () {
                      ref.read(selectedCategoryProvider.notifier).state = category;
                      final nameToId = ref.read(categoryNameToIdProvider).valueOrNull ?? {};
                      final categoryId = nameToId[category] ?? category;
                      ref.read(productFiltersProvider.notifier).state =
                          ref.read(productFiltersProvider).copyWith(
                                category: categoryId,
                                page: 1,
                              );
                    },
                  ),
                ),
                ProductCarousel(products: products),
                const SizedBox(height: 16),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSearchHistory(List<String> history) {
    final theme = Theme.of(context);

    if (history.isEmpty) {
      return const Center(
        child: Text('Comece a buscar produtos'),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Buscas recentes',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton(
              onPressed: () {
                ref.read(searchHistoryProvider.notifier).clearHistory();
              },
              child: const Text('Limpar'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...history.map(
          (query) => ListTile(
            leading: const Icon(Icons.history),
            title: Text(query),
            trailing: IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () {
                ref.read(searchHistoryProvider.notifier).removeSearch(query);
              },
            ),
            onTap: () {
              _searchController.text = query;
              _performSearch(query);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResults(FilteredProductsState state, String? query) {
    if (state.isLoading) {
      return const ShimmerLoading(itemCount: 6, isGrid: false, height: 120);
    }

    if (state.error != null && state.products.isEmpty) {
      return EmptyState.noProducts(
        onRetry: () => ref.read(filteredProductsProvider.notifier).refresh(),
      );
    }

    if (state.products.isEmpty) {
      final theme = Theme.of(context);
      final filters = ref.read(productFiltersProvider);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                filters.followedOnly
                    ? Icons.people_outline_rounded
                    : Icons.search_off_rounded,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                filters.followedOnly
                    ? 'Nenhum produto dos vendedores seguidos'
                    : 'Nenhum produto encontrado',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              if (filters.followedOnly) ...[
                const SizedBox(height: 8),
                Text(
                  'Siga vendedores na tela de perfil deles para ver os produtos aqui.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ] else if (query != null && query.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'para "$query"',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      );
    }

    final theme = Theme.of(context);

    return RefreshIndicator(
      onRefresh: () => ref.read(filteredProductsProvider.notifier).refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 4, bottom: 24),
        // +1 for result count header, +1 for load-more / loading footer
        itemCount: state.products.length + 2,
        itemBuilder: (context, index) {
          // Result count header
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '${state.products.length} produto(s) encontrado(s)',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
            );
          }

          final productIndex = index - 1;

          if (productIndex < state.products.length) {
            return SearchProductListCard(product: state.products[productIndex])
                .animate(delay: Duration(milliseconds: (productIndex % 6) * 60))
                .fadeIn(duration: 300.ms, curve: Curves.easeOut)
                .slideY(begin: 0.08, end: 0, duration: 300.ms, curve: Curves.easeOut);
          }
          if (state.isLoadingMore) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (state.hasMore) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: TextButton(
                  onPressed: () =>
                      ref.read(filteredProductsProvider.notifier).loadMore(),
                  child: const Text('Carregar mais'),
                ),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badgeCount;
  final bool hasChevron;
  final bool isActive;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badgeCount = 0,
    this.hasChevron = false,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? theme.colorScheme.primaryContainer : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? theme.colorScheme.primary.withAlpha(80)
                : theme.colorScheme.outline.withAlpha(40),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Badge(
              isLabelVisible: badgeCount > 0,
              label: Text(
                badgeCount.toString(),
                style: const TextStyle(fontSize: 9),
              ),
              child: Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface,
              ),
            ),
            if (hasChevron) ...[
              const SizedBox(width: 2),
              Icon(
                Icons.keyboard_arrow_down,
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

class _SortOption extends StatelessWidget {
  final String label;
  final String value;
  final bool isSelected;
  final VoidCallback onTap;

  const _SortOption({
    required this.label,
    required this.value,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? theme.colorScheme.primary : null,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check, color: theme.colorScheme.primary)
          : null,
      onTap: onTap,
    );
  }
}
