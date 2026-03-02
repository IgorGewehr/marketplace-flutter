import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../providers/rentals_provider.dart';
import '../../widgets/home/section_header.dart';
import '../../widgets/rentals/rental_card.dart';
import '../../widgets/shared/error_state.dart';
import '../../widgets/shared/shimmer_loading.dart';

/// Rentals screen - browse rental listings — follows Services screen pattern
class RentalsScreen extends ConsumerStatefulWidget {
  const RentalsScreen({super.key});

  @override
  ConsumerState<RentalsScreen> createState() => _RentalsScreenState();
}

class _RentalsScreenState extends ConsumerState<RentalsScreen> {
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
      ref.read(paginatedRentalsProvider.notifier).loadMore();
    }
  }

  Future<void> _onRefresh() async {
    ref.invalidate(featuredRentalsProvider);
    ref.invalidate(recentRentalsProvider);
    ref.read(paginatedRentalsProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final featuredAsync = ref.watch(featuredRentalsProvider);
    final recentAsync = ref.watch(recentRentalsProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Aluguéis'),
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
            onPressed: () => _showFilterBottomSheet(context),
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
                child: _RentalCategoryChips(),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // Featured rentals section
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'Em Destaque',
                  actionLabel: 'Ver todos',
                  onActionPressed: () {
                    ref.read(selectedRentalCategoryProvider.notifier).state = 'Todos';
                    ref.invalidate(featuredRentalsProvider);
                  },
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // Featured rentals grid
              featuredAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: ShimmerLoading(itemCount: 4, isGrid: true),
                ),
                error: (_, __) => SliverToBoxAdapter(
                  child: ErrorState(
                    icon: Icons.cloud_off_rounded,
                    message: 'Erro ao carregar aluguéis em destaque.',
                    onRetry: () => ref.invalidate(featuredRentalsProvider),
                  ),
                ),
                data: (rentals) {
                  if (rentals.isEmpty) {
                    return SliverToBoxAdapter(
                      child: _AnimatedEmptySection(
                        icon: Icons.vpn_key_outlined,
                        title: 'Nenhum aluguel em destaque',
                        subtitle: 'Novos aluguéis aparecerão aqui em breve',
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.68,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => RentalCard(rental: rentals[index])
                            .animate(delay: Duration(milliseconds: (index % 6) * 60))
                            .fadeIn(duration: 300.ms, curve: Curves.easeOut)
                            .slideY(begin: 0.08, end: 0, duration: 300.ms, curve: Curves.easeOut),
                        childCount: rentals.length,
                      ),
                    ),
                  );
                },
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),

              // Recent rentals section
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'Recentes',
                  actionLabel: 'Ver todos',
                  onActionPressed: () {
                    ref.read(selectedRentalCategoryProvider.notifier).state = 'Todos';
                    ref.invalidate(recentRentalsProvider);
                  },
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // Recent rentals grid
              recentAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: ShimmerLoading(itemCount: 4, isGrid: true),
                ),
                error: (_, __) => SliverToBoxAdapter(
                  child: ErrorState(
                    icon: Icons.cloud_off_rounded,
                    message: 'Erro ao carregar aluguéis recentes.',
                    onRetry: () => ref.invalidate(recentRentalsProvider),
                  ),
                ),
                data: (rentals) {
                  if (rentals.isEmpty) {
                    return SliverToBoxAdapter(
                      child: _AnimatedEmptySection(
                        icon: Icons.schedule_rounded,
                        title: 'Nenhum aluguel recente',
                        subtitle: 'Aluguéis adicionados recentemente aparecerão aqui',
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.68,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => RentalCard(rental: rentals[index])
                            .animate(delay: Duration(milliseconds: (index % 6) * 60))
                            .fadeIn(duration: 300.ms, curve: Curves.easeOut)
                            .slideY(begin: 0.08, end: 0, duration: 300.ms, curve: Curves.easeOut),
                        childCount: rentals.length,
                      ),
                    ),
                  );
                },
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),

              // Paginated "Mais Aluguéis" section (infinite scroll)
              ..._buildPaginatedRentals(),

              // Bottom padding for floating nav
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPaginatedRentals() {
    final paginatedState = ref.watch(paginatedRentalsProvider);
    if (paginatedState.rentals.isEmpty && !paginatedState.isLoading) {
      return [];
    }

    return [
      SliverToBoxAdapter(
        child: SectionHeader(
          title: 'Mais Aluguéis',
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
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.68,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index >= paginatedState.rentals.length) return null;
              return RentalCard(rental: paginatedState.rentals[index])
                  .animate(delay: Duration(milliseconds: (index % 6) * 60))
                  .fadeIn(duration: 300.ms, curve: Curves.easeOut)
                  .slideY(begin: 0.08, end: 0, duration: 300.ms, curve: Curves.easeOut);
            },
            childCount: paginatedState.rentals.length,
          ),
        ),
      ),
      if (paginatedState.isLoading)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ShimmerLoading(itemCount: 2, isGrid: true),
          ),
        ),
    ];
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _RentalFilterSheet(),
    );
  }
}

class _RentalCategoryChips extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectedCategory = ref.watch(selectedRentalCategoryProvider);

    // Hide if only "Todos" would show
    if (rentalCategories.length <= 1) return const SizedBox.shrink();

    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 16, right: 16, top: 8),
        itemCount: rentalCategories.length,
        itemBuilder: (context, index) {
          final category = rentalCategories[index];
          final isSelected = category == selectedCategory;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(category),
              selected: isSelected,
              showCheckmark: false,
              onSelected: (selected) {
                if (selected) {
                  HapticFeedback.selectionClick();
                  ref.read(selectedRentalCategoryProvider.notifier).state = category;
                  ref.invalidate(featuredRentalsProvider);
                  ref.invalidate(recentRentalsProvider);
                }
              },
              backgroundColor: theme.colorScheme.surface,
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected
                    ? AppColors.primary
                    : theme.colorScheme.outline.withAlpha(50),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Animated empty section for when a rental category returns no data
class _AnimatedEmptySection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _AnimatedEmptySection({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
        child: Column(
          children: [
            Icon(
              icon,
              size: 80,
              color: AppColors.border,
            ).animate().scale(
                  duration: 600.ms,
                  curve: Curves.elasticOut,
                ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 500.ms, duration: 400.ms),
          ],
        ),
      ),
    );
  }
}

class _RentalFilterSheet extends ConsumerStatefulWidget {
  const _RentalFilterSheet();

  @override
  ConsumerState<_RentalFilterSheet> createState() => _RentalFilterSheetState();
}

class _RentalFilterSheetState extends ConsumerState<_RentalFilterSheet> {
  RangeValues _priceRange = const RangeValues(0, 10000);
  String _rentalType = 'Todos';
  String _sortBy = 'recent';

  @override
  void initState() {
    super.initState();
    final filters = ref.read(rentalFiltersProvider);
    if (filters.minPrice != null || filters.maxPrice != null) {
      _priceRange = RangeValues(
        filters.minPrice ?? 0,
        filters.maxPrice ?? 10000,
      );
    }
    if (filters.rentalType != null) {
      for (final cat in rentalCategories) {
        if (rentalCategoryToType(cat) == filters.rentalType) {
          _rentalType = cat;
          break;
        }
      }
    }
    _sortBy = filters.sortBy;
  }

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
                        _priceRange = const RangeValues(0, 10000);
                        _rentalType = 'Todos';
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
                    max: 10000,
                    divisions: 100,
                    labels: RangeLabels(
                      'R\$ ${_priceRange.start.round()}',
                      'R\$ ${_priceRange.end.round()}',
                    ),
                    onChanged: (values) {
                      setState(() => _priceRange = values);
                    },
                  ),

                  const SizedBox(height: 24),

                  // Rental type
                  Text(
                    'Tipo de Aluguel',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: rentalCategories.map((type) {
                      final isSelected = type == _rentalType;
                      return ChoiceChip(
                        label: Text(type),
                        selected: isSelected,
                        showCheckmark: false,
                        onSelected: (selected) {
                          if (selected) setState(() => _rentalType = type);
                        },
                        backgroundColor: theme.colorScheme.surface,
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.primary
                              : theme.colorScheme.outline.withAlpha(50),
                        ),
                      );
                    }).toList(),
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
                    children: {
                      'recent': 'Mais recentes',
                      'price_asc': 'Menor preço',
                      'popular': 'Mais populares',
                    }.entries.map((e) {
                      final isSelected = _sortBy == e.key;
                      return ChoiceChip(
                        label: Text(e.value),
                        selected: isSelected,
                        showCheckmark: false,
                        onSelected: (selected) {
                          if (selected) setState(() => _sortBy = e.key);
                        },
                        backgroundColor: theme.colorScheme.surface,
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.primary
                              : theme.colorScheme.outline.withAlpha(50),
                        ),
                      );
                    }).toList(),
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
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  onPressed: () {
                    final rentalTypeValue = _rentalType != 'Todos' ? rentalCategoryToType(_rentalType) : null;
                    final hasCustomPrice = _priceRange.start > 0 || _priceRange.end < 10000;

                    ref.read(rentalFiltersProvider.notifier).state = RentalFilters(
                      rentalType: rentalTypeValue,
                      minPrice: hasCustomPrice ? _priceRange.start : null,
                      maxPrice: hasCustomPrice ? _priceRange.end : null,
                      sortBy: _sortBy,
                    );

                    ref.invalidate(featuredRentalsProvider);
                    ref.invalidate(recentRentalsProvider);
                    ref.read(paginatedRentalsProvider.notifier).refresh();
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
