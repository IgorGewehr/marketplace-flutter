import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/service_model.dart';
import '../../providers/follows_provider.dart';
import '../../providers/jobs_provider.dart';
import '../../providers/products_provider.dart';
import '../../providers/rentals_provider.dart';
import '../../providers/services_provider.dart';
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
        initialChildSize: 0.75,
        maxChildSize: 0.92,
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

  // ─── Remove filter helpers ─────────────────────────────────────────────────
  void _removeCategoryFilter() {
    final f = ref.read(productFiltersProvider);
    ref.read(productFiltersProvider.notifier).state = ProductFilters(
      query: f.query,
      minPrice: f.minPrice,
      maxPrice: f.maxPrice,
      sortBy: f.sortBy,
      page: 1,
      limit: f.limit,
      tags: f.tags,
      followedOnly: f.followedOnly,
    );
  }

  void _removePriceFilter() {
    final f = ref.read(productFiltersProvider);
    ref.read(productFiltersProvider.notifier).state = ProductFilters(
      query: f.query,
      category: f.category,
      sortBy: f.sortBy,
      page: 1,
      limit: f.limit,
      tags: f.tags,
      followedOnly: f.followedOnly,
    );
  }

  void _removeSortFilter() {
    final f = ref.read(productFiltersProvider);
    ref.read(productFiltersProvider.notifier).state = ProductFilters(
      query: f.query,
      category: f.category,
      minPrice: f.minPrice,
      maxPrice: f.maxPrice,
      page: 1,
      limit: f.limit,
      tags: f.tags,
      followedOnly: f.followedOnly,
    );
  }

  void _removeFollowedFilter() {
    final f = ref.read(productFiltersProvider);
    ref.read(productFiltersProvider.notifier).state = ProductFilters(
      query: f.query,
      category: f.category,
      minPrice: f.minPrice,
      maxPrice: f.maxPrice,
      sortBy: f.sortBy,
      page: 1,
      limit: f.limit,
      tags: f.tags,
    );
  }

  void _removeTagFilter(String tag) {
    final f = ref.read(productFiltersProvider);
    final newTags = List<String>.from(f.tags ?? [])..remove(tag);
    ref.read(productFiltersProvider.notifier).state = ProductFilters(
      query: f.query,
      category: f.category,
      minPrice: f.minPrice,
      maxPrice: f.maxPrice,
      sortBy: f.sortBy,
      page: 1,
      limit: f.limit,
      tags: newTags.isEmpty ? null : newTags,
      followedOnly: f.followedOnly,
    );
  }

  // ─── Price label helper ────────────────────────────────────────────────────
  String _formatPrice(double value) {
    if (value >= 1000000) {
      final m = value / 1000000;
      return 'R\$ ${m == m.truncateToDouble() ? m.toInt() : m.toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      final k = value / 1000;
      return 'R\$ ${k == k.truncateToDouble() ? k.toInt() : k.toStringAsFixed(1)}k';
    }
    return 'R\$ ${value.toInt()}';
  }

  // ─── Active filter chips ───────────────────────────────────────────────────
  Widget _buildActiveFilterChips(ProductFilters filters) {
    final idToName = ref.watch(categoryIdToNameProvider).valueOrNull ?? {};

    final chips = <(String, VoidCallback)>[];

    if (filters.category != null) {
      final name = idToName[filters.category] ?? filters.category!;
      chips.add((name, _removeCategoryFilter));
    }

    if (filters.minPrice != null || filters.maxPrice != null) {
      final min = filters.minPrice != null ? _formatPrice(filters.minPrice!) : 'R\$ 0';
      final max = filters.maxPrice != null ? _formatPrice(filters.maxPrice!) : 'Sem limite';
      chips.add(('$min – $max', _removePriceFilter));
    }

    if (filters.sortBy != 'recent') {
      final label = filters.sortBy == 'price_asc' ? 'Menor preço' : 'Maior preço';
      chips.add((label, _removeSortFilter));
    }

    if (filters.followedOnly) {
      chips.add(('Seguindo', _removeFollowedFilter));
    }

    for (final tag in (filters.tags ?? [])) {
      final t = tag;
      chips.add(('#$t', () => _removeTagFilter(t)));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        height: 34,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: chips.length,
          separatorBuilder: (context, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final (label, onRemove) = chips[i];
            return _ActiveFilterChip(label: label, onRemove: onRemove)
                .animate(delay: Duration(milliseconds: i * 40))
                .fadeIn(duration: 200.ms)
                .slideX(begin: 0.3, duration: 200.ms, curve: Curves.easeOut);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final history = ref.watch(searchHistoryProvider);
    final resultsState = ref.watch(filteredProductsProvider);
    final filters = ref.watch(productFiltersProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    final followedIds = ref.watch(followsProvider);

    final hasActiveFilters =
        (filters.query != null && filters.query!.isNotEmpty) ||
            (filters.category != null && filters.category != 'Todos') ||
            filters.minPrice != null ||
            filters.maxPrice != null ||
            filters.followedOnly;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // ─── Search bar ────────────────────────────────────────────────
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
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(8),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
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

            // ─── Action chips ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
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
                    _ActionChip(
                      icon: Icons.tune,
                      label: 'Filtros',
                      badgeCount: filters.activeFilterCount,
                      onTap: _showFilters,
                    ),
                    const SizedBox(width: 8),
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
                    _ActionChip(
                      icon: Icons.sort,
                      label: 'Ordenar',
                      onTap: _showSortSheet,
                    ),
                    const SizedBox(width: 8),
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

            // ─── Active filter chips ────────────────────────────────────────
            _buildActiveFilterChips(filters),

            const SizedBox(height: 4),

            // ─── Content ────────────────────────────────────────────────────
            Expanded(
              child: hasActiveFilters
                  ? _buildResults(resultsState, filters.query)
                  : _searchController.text.isEmpty && history.isNotEmpty
                      ? _buildSearchHistory(history)
                      : categoriesAsync.when(
                          loading: () => const ShimmerLoading(itemCount: 4),
                          error: (e, _) =>
                              const Center(child: Text('Erro ao carregar categorias')),
                          data: (categories) => _buildCategoryCarousels(categories),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  static const _specialCategories = {
    'empregos', 'vagas', 'emprego',
    'aluguéis', 'alugueis', 'aluguel',
    'serviços', 'servicos',
  };

  static bool _isSpecialCategory(String name) =>
      _specialCategories.contains(name.toLowerCase().trim());

  Widget _buildCategoryCarousels(List<String> categories) {
    final regularCategories =
        categories.where((c) => c != 'Todos' && !_isSpecialCategory(c)).toList();

    return ListView(
      padding: const EdgeInsets.only(top: 0, bottom: 24),
      children: [
        // ─── Special type cards: always shown ──────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text(
            'Explorar por tipo',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: _SpecialCategoryCard(
                  label: 'Serviços',
                  icon: Icons.build_rounded,
                  route: AppRouter.services,
                  gradient: const [Color(0xFF4CAF50), Color(0xFF2E7D32)],
                ).animate(delay: 50.ms).fadeIn(duration: 300.ms).slideY(begin: 0.15),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SpecialCategoryCard(
                  label: 'Aluguéis',
                  icon: Icons.vpn_key_rounded,
                  route: AppRouter.rentals,
                  gradient: const [Color(0xFF00B4D8), Color(0xFF0077B6)],
                ).animate(delay: 100.ms).fadeIn(duration: 300.ms).slideY(begin: 0.15),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SpecialCategoryCard(
                  label: 'Empregos',
                  icon: Icons.work_rounded,
                  route: AppRouter.jobs,
                  gradient: const [Color(0xFF7B4FCF), Color(0xFF4A2C8F)],
                ).animate(delay: 150.ms).fadeIn(duration: 300.ms).slideY(begin: 0.15),
              ),
            ],
          ),
        ),

        // ─── Product carousels per category ────────────────────────────────
        if (regularCategories.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Text(
                  'Por categoria',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
          ...regularCategories.asMap().entries.map((entry) {
            final index = entry.key;
            final category = entry.value;
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
                      onActionPressed: () => _applyCategory(category),
                    ),
                  ),
                  const ProductCarousel(isLoading: true),
                  const SizedBox(height: 16),
                ],
              ),
              error: (e, _) => const SizedBox.shrink(),
              data: (products) {
                if (products.isEmpty) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 12),
                      child: SectionHeader(
                        title: category,
                        actionLabel: 'Ver todos',
                        onActionPressed: () => _applyCategory(category),
                      ),
                    ),
                    ProductCarousel(products: products),
                    const SizedBox(height: 16),
                  ],
                )
                    .animate(delay: Duration(milliseconds: 200 + index * 80))
                    .fadeIn(duration: 300.ms, curve: Curves.easeOut)
                    .slideY(begin: 0.1, duration: 300.ms, curve: Curves.easeOut);
              },
            );
          }),
        ],
      ],
    );
  }

  void _applyCategory(String category) {
    ref.read(selectedCategoryProvider.notifier).state = category;
    final nameToId = ref.read(categoryNameToIdProvider).valueOrNull ?? {};
    final categoryId = nameToId[category] ?? category;
    ref.read(productFiltersProvider.notifier).state =
        ref.read(productFiltersProvider).copyWith(
              category: categoryId,
              page: 1,
            );
  }

  Widget _buildSearchHistory(List<String> history) {
    final theme = Theme.of(context);

    if (history.isEmpty) {
      return const Center(child: Text('Comece a buscar produtos'));
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Buscas recentes',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            TextButton(
              onPressed: () =>
                  ref.read(searchHistoryProvider.notifier).clearHistory(),
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
              onPressed: () =>
                  ref.read(searchHistoryProvider.notifier).removeSearch(query),
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
      final hasQuery = query != null && query.isNotEmpty;

      return SingleChildScrollView(
        child: Column(
          children: [
            // Cross-type results when there are no products but a query exists
            if (hasQuery && !filters.followedOnly)
              _CrossTypeSearchSection(query: query!),

            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      filters.followedOnly
                          ? Icons.people_outline_rounded
                          : Icons.search_off_rounded,
                      size: 80,
                      color: AppColors.border,
                    ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
                    const SizedBox(height: 16),
                    Text(
                      filters.followedOnly
                          ? 'Nenhum produto dos vendedores seguidos'
                          : 'Nenhum produto encontrado',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
                    if (filters.followedOnly) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Siga vendedores na tela de perfil deles para ver os produtos aqui.',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ).animate().fadeIn(delay: 500.ms, duration: 400.ms),
                    ] else if (hasQuery) ...[
                      const SizedBox(height: 8),
                      Text(
                        'para "$query"',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ).animate().fadeIn(delay: 500.ms, duration: 400.ms),
                    ],
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      icon: const Icon(Icons.tune_rounded),
                      label: const Text('Ajustar filtros'),
                      onPressed: _showFilters,
                    )
                        .animate()
                        .fadeIn(delay: 700.ms, duration: 400.ms)
                        .slideY(begin: 0.3, delay: 700.ms, duration: 400.ms),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final theme = Theme.of(context);
    final hasQuery = query != null && query.isNotEmpty;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => ref.read(filteredProductsProvider.notifier).refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 4, bottom: 24),
        itemCount: state.products.length + 2 + (hasQuery ? 1 : 0),
        itemBuilder: (context, index) {
          // Cross-type search results section (when query is present)
          if (hasQuery && index == 0) {
            return _CrossTypeSearchSection(query: query!);
          }

          final adjustedIndex = hasQuery ? index - 1 : index;

          if (adjustedIndex == 0) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '${state.products.length} produto(s) encontrado(s)',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
            );
          }

          final productIndex = adjustedIndex - 1;

          if (productIndex < state.products.length) {
            return SearchProductListCard(product: state.products[productIndex])
                .animate(delay: Duration(milliseconds: (productIndex % 6) * 60))
                .fadeIn(duration: 300.ms, curve: Curves.easeOut)
                .slideY(begin: 0.08, end: 0, duration: 300.ms, curve: Curves.easeOut);
          }
          if (state.isLoadingMore) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ShimmerLoading(itemCount: 2, isGrid: false, height: 120),
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

// ─── Cross-type search section ────────────────────────────────────────────────

class _CrossTypeSearchSection extends ConsumerWidget {
  final String query;

  const _CrossTypeSearchSection({required this.query});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rentalsAsync = ref.watch(rentalSearchProvider(query));
    final servicesAsync = ref.watch(serviceSearchProvider(query));
    final jobsAsync = ref.watch(jobSearchProvider(query));

    final rentals = rentalsAsync.valueOrNull ?? [];
    final services = servicesAsync.valueOrNull ?? [];
    final jobs = jobsAsync.valueOrNull ?? [];

    if (rentals.isEmpty && services.isEmpty && jobs.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (rentals.isNotEmpty) ...[
          _CrossTypeSectionHeader(
            icon: Icons.vpn_key_rounded,
            label: 'Aluguéis',
            color: const Color(0xFF0077B6),
            onSeeAll: () => context.push(AppRouter.rentals),
          ),
          ...rentals.map((r) => ListTile(
                dense: true,
                leading: const Icon(Icons.home_outlined, color: Color(0xFF0077B6)),
                title: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  r.rentalPriceDisplay ?? 'R\$ ${r.price.toStringAsFixed(2)}',
                  style: TextStyle(color: theme.colorScheme.primary, fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => context.push('/rental/${r.id}'),
              )),
          const Divider(height: 8),
        ],
        if (services.isNotEmpty) ...[
          _CrossTypeSectionHeader(
            icon: Icons.build_rounded,
            label: 'Serviços',
            color: const Color(0xFF2E7D32),
            onSeeAll: () => context.push(AppRouter.services),
          ),
          ...services.map((s) => ListTile(
                dense: true,
                leading: const Icon(Icons.handyman_outlined, color: Color(0xFF2E7D32)),
                title: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  _servicePrice(s),
                  style: const TextStyle(color: Color(0xFF2E7D32), fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => context.push('/service/${s.id}'),
              )),
          const Divider(height: 8),
        ],
        if (jobs.isNotEmpty) ...[
          _CrossTypeSectionHeader(
            icon: Icons.work_rounded,
            label: 'Vagas',
            color: const Color(0xFF4A2C8F),
            onSeeAll: () => context.push(AppRouter.jobs),
          ),
          ...jobs.map((j) => ListTile(
                dense: true,
                leading: const Icon(Icons.work_outline, color: Color(0xFF4A2C8F)),
                title: Text(j.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  j.companyName ?? 'Empresa não informada',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => context.push('/job/${j.id}'),
              )),
          const Divider(height: 8),
        ],
      ],
    );
  }

  String _servicePrice(MarketplaceServiceModel s) {
    final price = s.minPrice ?? s.basePrice;
    return 'A partir de R\$ ${price.toStringAsFixed(price.truncateToDouble() == price ? 0 : 2)}';
  }
}

class _CrossTypeSectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onSeeAll;

  const _CrossTypeSectionHeader({
    required this.icon,
    required this.label,
    required this.color,
    required this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: color,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: onSeeAll,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Ver todos', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ─── _SpecialCategoryCard ────────────────────────────────────────────────────

class _SpecialCategoryCard extends StatefulWidget {
  final String label;
  final IconData icon;
  final String route;
  final List<Color> gradient;

  const _SpecialCategoryCard({
    required this.label,
    required this.icon,
    required this.route,
    required this.gradient,
  });

  @override
  State<_SpecialCategoryCard> createState() => _SpecialCategoryCardState();
}

class _SpecialCategoryCardState extends State<_SpecialCategoryCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.selectionClick();
        context.push(widget.route);
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          height: 88,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: widget.gradient.first.withAlpha(80),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(40),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.icon, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 6),
              Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── _ActiveFilterChip ───────────────────────────────────────────────────────

class _ActiveFilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _ActiveFilterChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 12, right: 8, top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(17),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(50),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              onRemove();
            },
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(50),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── _ActionChip ─────────────────────────────────────────────────────────────

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
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(6),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Badge(
              isLabelVisible: badgeCount > 0,
              label: Text(badgeCount.toString(), style: const TextStyle(fontSize: 9)),
              child: Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
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

// ─── _SortOption ─────────────────────────────────────────────────────────────

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
      trailing: isSelected ? Icon(Icons.check, color: theme.colorScheme.primary) : null,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
    );
  }
}
