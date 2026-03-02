import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/product_model.dart';
import '../../providers/follows_provider.dart';
import '../../providers/jobs_provider.dart';
import '../../providers/products_provider.dart';
import '../../providers/rentals_provider.dart';
import '../../providers/services_provider.dart';
import '../../widgets/home/category_chips.dart';
import '../../widgets/home/home_header.dart';
import '../../widgets/home/promo_banner_carousel.dart';
import '../../widgets/home/quick_access_buttons.dart';
import '../../widgets/home/section_header.dart';
import '../../widgets/jobs/job_card.dart';
import '../../widgets/products/product_card.dart';
import '../../widgets/products/product_carousel.dart';
import '../../widgets/services/service_card.dart';
import '../../widgets/shared/shimmer_loading.dart';

/// Home screen (Início) - main marketplace view
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Refresh product data when the home screen mounts (e.g. after
    // switching from seller mode) so the buyer always sees fresh stock.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _onRefresh();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(paginatedRecentProductsProvider.notifier).loadMore();
    }
  }

  Future<void> _onRefresh() async {
    final selectedCategory = ref.read(selectedCategoryProvider);
    ref.invalidate(featuredProductsProvider);
    ref.invalidate(featuredRentalsProvider);
    ref.invalidate(featuredServicesProvider);
    ref.invalidate(recentJobsProvider);
    ref.invalidate(followedSellersProductsProvider);
    if (selectedCategory != 'Todos') {
      ref.invalidate(productsByCategoryProvider(selectedCategory));
    }
    ref.read(paginatedRecentProductsProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final featuredAsync = ref.watch(featuredProductsProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          color: AppColors.primary,
          edgeOffset: 80,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Header - "Compre Aqui" + notification bell
              const SliverToBoxAdapter(
                child: HomeHeader(),
              ),

              // Category tabs with icons
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: CategoryTabs(),
                ),
              ),

              // Search bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _SearchBar(
                    onTap: () => context.push(AppRouter.search),
                  ),
                ),
              ),

              // Quick access buttons
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: QuickAccessButtons(),
                ),
              ),

              // Promo banners
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: PromoBannerCarousel(),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // Category-filtered carousel (only when a specific category is selected)
              SliverToBoxAdapter(
                child: _buildCategoryCarousel(),
              ),

              // "Em alta no Compre Aqui" section
              SliverToBoxAdapter(
                child: featuredAsync.when(
                  loading: () => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(
                        title: 'Em alta no Compre Aqui',
                        actionLabel: 'Ver todos',
                        onActionPressed: () => context.push(AppRouter.search),
                      ),
                      const SizedBox(height: 16),
                      const ProductCarousel(isLoading: true),
                    ],
                  ),
                  error: (_, __) => _ErrorRetrySection(
                    title: 'Em alta no Compre Aqui',
                    onRetry: () => ref.invalidate(featuredProductsProvider),
                  ),
                  data: (products) {
                    if (products.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionHeader(
                          title: 'Em alta no Compre Aqui',
                          actionLabel: 'Ver todos',
                          onActionPressed: () => context.push(AppRouter.search),
                        ),
                        const SizedBox(height: 16),
                        ProductCarousel(products: products),
                      ],
                    );
                  },
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),

              // "Aluguéis em Destaque" section
              SliverToBoxAdapter(
                child: _buildFeaturedRentalsSection(),
              ),

              // "Serviços em Destaque" section
              SliverToBoxAdapter(
                child: _buildFeaturedServicesSection(),
              ),

              // "Vendedores que Sigo" section — only when following at least one seller
              SliverToBoxAdapter(
                child: _buildFollowedSellersSection(),
              ),

              // "Vagas de Emprego" section
              SliverToBoxAdapter(
                child: _buildJobsSection(),
              ),

              // Paginated "Mais produtos" section (infinite scroll)
              ..._buildPaginatedProducts(),

              // Bottom padding for nav bar
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCarousel() {
    final selectedCategory = ref.watch(selectedCategoryProvider);
    if (selectedCategory == 'Todos') return const SizedBox.shrink();

    final productsAsync = ref.watch(productsByCategoryProvider(selectedCategory));

    void goToSearchFiltered() {
      final nameToId = ref.read(categoryNameToIdProvider).valueOrNull ?? {};
      final categoryId = nameToId[selectedCategory] ?? selectedCategory.toLowerCase();
      ref.read(productFiltersProvider.notifier).state = ProductFilters(
        category: categoryId,
      );
      context.push(AppRouter.search);
    }

    return productsAsync.when(
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: selectedCategory,
            actionLabel: 'Ver todos',
            onActionPressed: goToSearchFiltered,
          ),
          const SizedBox(height: 16),
          const ProductCarousel(isLoading: true),
          const SizedBox(height: 24),
        ],
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (products) {
        if (products.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: selectedCategory,
              actionLabel: 'Ver todos',
              onActionPressed: goToSearchFiltered,
            ),
            const SizedBox(height: 16),
            ProductCarousel(products: products),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _buildFeaturedRentalsSection() {
    final rentalsAsync = ref.watch(featuredRentalsProvider);

    return rentalsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (rentals) {
        if (rentals.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Aluguéis em Destaque',
              actionLabel: 'Ver todos',
              onActionPressed: () => context.push(AppRouter.rentals),
            ),
            const SizedBox(height: 16),
            ProductCarousel(products: rentals),
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }

  Widget _buildFeaturedServicesSection() {
    final servicesAsync = ref.watch(featuredServicesProvider);

    return servicesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (services) {
        if (services.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Serviços em Destaque',
              actionLabel: 'Ver todos',
              onActionPressed: () => context.push(AppRouter.services),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: services.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  return SizedBox(
                    width: 200,
                    child: ServiceCard(service: services[index]),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }

  Widget _buildFollowedSellersSection() {
    final followedIds = ref.watch(followsProvider);
    if (followedIds.isEmpty) return const SizedBox.shrink();

    final productsAsync = ref.watch(followedSellersProductsProvider);

    void goToFollowedInSearch() {
      ref.read(productFiltersProvider.notifier).state =
          const ProductFilters(followedOnly: true);
      context.push(AppRouter.search);
    }

    return productsAsync.when(
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Vendedores que Sigo',
            actionLabel: 'Ver todos',
            onActionPressed: goToFollowedInSearch,
          ),
          const SizedBox(height: 16),
          const ProductCarousel(isLoading: true),
          const SizedBox(height: 32),
        ],
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (products) {
        if (products.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Vendedores que Sigo',
              actionLabel: 'Ver todos',
              onActionPressed: goToFollowedInSearch,
            ),
            const SizedBox(height: 16),
            ProductCarousel(products: products),
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }

  Widget _buildJobsSection() {
    final jobsAsync = ref.watch(recentJobsProvider);

    return jobsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (jobs) {
        if (jobs.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Vagas de Emprego',
              actionLabel: 'Ver todas',
              onActionPressed: () => context.push(AppRouter.jobs),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: jobs.take(3).map((job) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    height: 120,
                    child: _JobListTile(job: job),
                  ),
                )).toList(),
              ),
            ),
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  List<Widget> _buildPaginatedProducts() {
    final paginatedState = ref.watch(paginatedRecentProductsProvider);
    final isInitialLoad = paginatedState.products.isEmpty && paginatedState.isLoading;

    // Error state with retry
    if (paginatedState.error != null && paginatedState.products.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: SectionHeader(
            title: 'Mais produtos',
            actionLabel: 'Ver todos',
            onActionPressed: () => context.push(AppRouter.search),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.cloud_off_outlined,
                    size: 36,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 8),
                  const Text('Erro ao carregar produtos'),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => ref.read(paginatedRecentProductsProvider.notifier).refresh(),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ];
    }

    if (paginatedState.products.isEmpty && !paginatedState.isLoading) {
      return [];
    }

    return [
      SliverToBoxAdapter(
        child: SectionHeader(
          title: 'Mais produtos',
          actionLabel: 'Ver todos',
          onActionPressed: () => context.push(AppRouter.search),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 12)),
      if (isInitialLoad)
        const SliverToBoxAdapter(
          child: ShimmerLoading(itemCount: 6, isGrid: true),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.7,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index >= paginatedState.products.length) return null;
                return ProductCard(product: paginatedState.products[index])
                    .animate(delay: Duration(milliseconds: (index % 6) * 60))
                    .fadeIn(duration: 300.ms, curve: Curves.easeOut)
                    .slideY(begin: 0.08, end: 0, duration: 300.ms, curve: Curves.easeOut);
              },
              childCount: paginatedState.products.length,
            ),
          ),
        ),
      if (!isInitialLoad && paginatedState.isLoading)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                height: 48,
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ),
        )
      else if (paginatedState.hasMore)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextButton(
              onPressed: () =>
                  ref.read(paginatedRecentProductsProvider.notifier).loadMore(),
              child: const Text('Ver mais'),
            ),
          ),
        )
      else if (paginatedState.products.isNotEmpty)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(
                'Sem mais produtos',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
    ];
  }
}

class _SearchBar extends StatelessWidget {
  final VoidCallback onTap;

  const _SearchBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: 'Buscar produtos',
      button: true,
      child: GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.colorScheme.outline.withAlpha(30),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(5),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              Icons.search,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Buscar produtos...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}

/// Horizontal list tile for job listings on home screen
class _JobListTile extends StatelessWidget {
  final ProductModel job;

  const _JobListTile({required this.job});

  Color _jobTypeColor(String? type) {
    switch (type) {
      case 'clt': return AppColors.jobClt;
      case 'pj': return AppColors.jobPj;
      case 'freelance': return AppColors.jobFreelance;
      case 'estagio': return AppColors.jobEstagio;
      case 'temporario': return AppColors.jobTemporario;
      default: return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeColor = _jobTypeColor(job.jobType);

    return GestureDetector(
      onTap: () => context.push('/job/${job.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border.withAlpha(40)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(6),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            // Left: icon/image
            Container(
              width: 80,
              color: typeColor.withAlpha(20),
              child: Center(
                child: job.images.isNotEmpty
                    ? ClipRRect(
                        child: Image.network(
                          job.images.first.url,
                          width: 80,
                          height: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Icon(Icons.work_rounded, size: 32, color: typeColor.withAlpha(150)),
              ),
            ),
            // Right: info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (job.companyName != null && job.companyName!.isNotEmpty)
                      Text(
                        job.companyName!,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(
                      job.name,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      job.salaryDisplay,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: [
                        if (job.jobType != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: typeColor.withAlpha(20),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              job.jobTypeLabel,
                              style: TextStyle(fontSize: 10, color: typeColor, fontWeight: FontWeight.w600),
                            ),
                          ),
                        if (job.workMode != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              job.workModeLabel,
                              style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ),
                        if (job.location?.city != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              job.location!.city!,
                              style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorRetrySection extends StatelessWidget {
  final String title;
  final VoidCallback onRetry;

  const _ErrorRetrySection({required this.title, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withAlpha(50),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  size: 36,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 8),
                Text(
                  'Erro ao carregar',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
