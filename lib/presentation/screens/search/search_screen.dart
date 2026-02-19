import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
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
  bool _showResults = false;
  Timer? _debounceTimer;

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

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    setState(() {
      _showResults = _searchController.text.isNotEmpty;
    });
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        ref.read(searchQueryProvider.notifier).state = _searchController.text;
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

    setState(() => _showResults = true);
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
            _SortOption(
              label: 'Relevância',
              value: 'relevance',
              isSelected: currentSort == 'relevance',
              onTap: () => _applySort('relevance'),
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
    final resultsAsync = ref.watch(filteredProductsProvider);
    final filters = ref.watch(productFiltersProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    // Determine if we should show carousels or vertical list
    final hasActiveFilters = (filters.query != null && filters.query!.isNotEmpty) ||
        (filters.category != null && filters.category != 'Todos') ||
        filters.minPrice != null ||
        filters.maxPrice != null;

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
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Expanded(
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
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
                                    setState(() => _showResults = false);
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
                    // Save search chip
                    _ActionChip(
                      icon: Icons.bookmark_outline,
                      label: 'Salvar busca',
                      onTap: () {
                        if (_searchController.text.isNotEmpty) {
                          ref
                              .read(searchHistoryProvider.notifier)
                              .addSearch(_searchController.text);
                          ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
                            const SnackBar(
                              content: Text('Busca salva'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        }
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

            // Content
            Expanded(
              child: hasActiveFilters
                  ? _buildResults(resultsAsync)
                  : (!_showResults && history.isNotEmpty)
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
                    ref.read(productFiltersProvider.notifier).state =
                        ref.read(productFiltersProvider).copyWith(
                              category: category,
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
                      ref.read(productFiltersProvider.notifier).state =
                          ref.read(productFiltersProvider).copyWith(
                                category: category,
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

  Widget _buildResults(AsyncValue results) {
    return results.when(
      loading: () => const ShimmerLoading(itemCount: 6, isGrid: false, height: 120),
      error: (error, _) => EmptyState.noProducts(
        onRetry: () => ref.invalidate(filteredProductsProvider),
      ),
      data: (products) {
        if (products.isEmpty) {
          return EmptyState.searchEmpty();
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(filteredProductsProvider);
          },
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 4, bottom: 24),
            itemCount: products.length,
            itemBuilder: (context, index) {
              return SearchProductListCard(product: products[index]);
            },
          ),
        );
      },
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badgeCount;
  final bool hasChevron;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badgeCount = 0,
    this.hasChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: theme.colorScheme.outline.withAlpha(40),
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
