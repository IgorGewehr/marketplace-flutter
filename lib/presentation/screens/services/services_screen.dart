import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../providers/services_provider.dart';
import '../../widgets/home/section_header.dart';
import '../../widgets/services/service_card.dart';
import '../../widgets/services/service_grid.dart';

/// Services screen - browse services marketplace
class ServicesScreen extends ConsumerStatefulWidget {
  const ServicesScreen({super.key});

  @override
  ConsumerState<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends ConsumerState<ServicesScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(paginatedRecentServicesProvider.notifier).loadMore();
    }
  }

  Future<void> _onRefresh() async {
    ref.invalidate(featuredServicesProvider);
    ref.invalidate(recentServicesProvider);
    ref.read(paginatedRecentServicesProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final featuredAsync = ref.watch(featuredServicesProvider);
    final recentAsync = ref.watch(recentServicesProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Serviços'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              _showFilterBottomSheet(context);
            },
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Category chips
              SliverToBoxAdapter(
                child: _ServiceCategoryChips(),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // Featured services section
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'Serviços em Destaque',
                  actionLabel: 'Ver todos',
                  onActionPressed: () {
                    ref.read(selectedServiceCategoryProvider.notifier).state = 'Todos';
                    ref.invalidate(filteredServicesProvider);
                  },
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // Featured services grid
              featuredAsync.when(
                loading: () => const SliverServiceGrid(isLoading: true),
                error: (_, __) => SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Erro ao carregar serviços',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => ref.invalidate(featuredServicesProvider),
                            child: const Text('Tentar novamente'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                data: (services) => SliverServiceGrid(services: services),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),

              // Recent services section
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'Serviços Recentes',
                  actionLabel: 'Ver todos',
                  onActionPressed: () {
                    ref.read(selectedServiceCategoryProvider.notifier).state = 'Todos';
                    ref.invalidate(recentServicesProvider);
                  },
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // Recent services grid
              recentAsync.when(
                loading: () => const SliverServiceGrid(isLoading: true),
                error: (_, __) => SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Erro ao carregar serviços',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => ref.invalidate(recentServicesProvider),
                            child: const Text('Tentar novamente'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                data: (services) => SliverServiceGrid(services: services),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),

              // Paginated "Mais serviços" section (infinite scroll)
              ..._buildPaginatedServices(),

              // Bottom padding for floating nav
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPaginatedServices() {
    final paginatedState = ref.watch(paginatedRecentServicesProvider);
    if (paginatedState.services.isEmpty && !paginatedState.isLoading) {
      return [];
    }

    return [
      SliverToBoxAdapter(
        child: SectionHeader(
          title: 'Mais serviços',
          actionLabel: '',
          onActionPressed: () {},
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 12)),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.60,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index >= paginatedState.services.length) return null;
              return ServiceCard(service: paginatedState.services[index])
                  .animate(delay: Duration(milliseconds: (index % 6) * 60))
                  .fadeIn(duration: 300.ms, curve: Curves.easeOut)
                  .slideY(begin: 0.08, end: 0, duration: 300.ms, curve: Curves.easeOut);
            },
            childCount: paginatedState.services.length,
          ),
        ),
      ),
      if (paginatedState.isLoading)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
    ];
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _ServiceFilterSheet(),
    );
  }
}

class _ServiceCategoryChips extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final categoriesAsync = ref.watch(serviceCategoriesProvider);
    final selectedCategory = ref.watch(selectedServiceCategoryProvider);

    return categoriesAsync.when(
      loading: () => const SizedBox(height: 40),
      error: (_, __) => const SizedBox.shrink(),
      data: (categories) {
        return SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final isSelected = category == selectedCategory;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(category),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      ref.read(selectedServiceCategoryProvider.notifier).state = category;
                      ref.invalidate(featuredServicesProvider);
                      ref.invalidate(recentServicesProvider);
                    }
                  },
                  backgroundColor: theme.colorScheme.surface,
                  selectedColor: theme.colorScheme.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline.withAlpha(50),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _ServiceFilterSheet extends ConsumerStatefulWidget {
  const _ServiceFilterSheet();

  @override
  ConsumerState<_ServiceFilterSheet> createState() => _ServiceFilterSheetState();
}

class _ServiceFilterSheetState extends ConsumerState<_ServiceFilterSheet> {
  RangeValues _priceRange = const RangeValues(0, 5000);
  String _pricingType = 'Todos';
  bool _remoteOnly = false;
  String _sortBy = 'recent';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filtros',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _priceRange = const RangeValues(0, 5000);
                        _pricingType = 'Todos';
                        _remoteOnly = false;
                        _sortBy = 'recent';
                      });
                    },
                    child: const Text('Limpar'),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Price range
                  Text(
                    'Faixa de Preço',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  RangeSlider(
                    values: _priceRange,
                    min: 0,
                    max: 5000,
                    divisions: 50,
                    labels: RangeLabels(
                      'R\$ ${_priceRange.start.round()}',
                      'R\$ ${_priceRange.end.round()}',
                    ),
                    onChanged: (values) {
                      setState(() => _priceRange = values);
                    },
                  ),

                  const SizedBox(height: 24),

                  // Pricing type
                  Text(
                    'Tipo de Precificação',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: pricingTypeOptions.map((type) {
                      final isSelected = type == _pricingType;
                      return ChoiceChip(
                        label: Text(type),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _pricingType = type);
                          }
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // Remote only
                  CheckboxListTile(
                    value: _remoteOnly,
                    onChanged: (value) {
                      setState(() => _remoteOnly = value ?? false);
                    },
                    title: const Text('Apenas serviços remotos'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  ),

                  const SizedBox(height: 24),

                  // Sort by
                  Text(
                    'Ordenar por',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Mais recentes'),
                        selected: _sortBy == 'recent',
                        onSelected: (selected) {
                          if (selected) setState(() => _sortBy = 'recent');
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Melhor avaliados'),
                        selected: _sortBy == 'rating',
                        onSelected: (selected) {
                          if (selected) setState(() => _sortBy = 'rating');
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Mais populares'),
                        selected: _sortBy == 'popular',
                        onSelected: (selected) {
                          if (selected) setState(() => _sortBy = 'popular');
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Menor preço'),
                        selected: _sortBy == 'price_asc',
                        onSelected: (selected) {
                          if (selected) setState(() => _sortBy = 'price_asc');
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Apply button
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    // Apply filters
                    final filters = ref.read(serviceFiltersProvider.notifier);
                    filters.state = filters.state.copyWith(
                      minPrice: _priceRange.start,
                      maxPrice: _priceRange.end,
                      pricingType: _pricingType != 'Todos' ? pricingTypeToApi(_pricingType) : null,
                      isRemote: _remoteOnly ? true : null,
                      sortBy: _sortBy,
                    );
                    ref.invalidate(filteredServicesProvider);
                    Navigator.pop(context);
                  },
                  child: const Text('Aplicar filtros'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
