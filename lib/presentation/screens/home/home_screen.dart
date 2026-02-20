import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../providers/products_provider.dart';
import '../../widgets/home/category_chips.dart';
import '../../widgets/home/home_header.dart';
import '../../widgets/home/promo_banner_carousel.dart';
import '../../widgets/home/quick_access_buttons.dart';
import '../../widgets/home/section_header.dart';
import '../../widgets/products/product_card.dart';
import '../../widgets/products/product_carousel.dart';

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
    ref.invalidate(featuredProductsProvider);
    ref.invalidate(recentProductsProvider);
    ref.read(paginatedRecentProductsProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final featuredAsync = ref.watch(featuredProductsProvider);
    final recentAsync = ref.watch(recentProductsProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _onRefresh,
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

              // "Recentes na sua área" section
              SliverToBoxAdapter(
                child: recentAsync.when(
                  loading: () => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionHeader(
                        title: 'Recentes na sua área',
                        actionLabel: 'Ver todos',
                        onActionPressed: () => context.push(AppRouter.search),
                      ),
                      const SizedBox(height: 16),
                      const ProductCarousel(isLoading: true),
                    ],
                  ),
                  error: (_, __) => _ErrorRetrySection(
                    title: 'Recentes na sua área',
                    onRetry: () => ref.invalidate(recentProductsProvider),
                  ),
                  data: (products) {
                    if (products.isEmpty) return const SizedBox.shrink();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionHeader(
                          title: 'Recentes na sua área',
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

  List<Widget> _buildPaginatedProducts() {
    final paginatedState = ref.watch(paginatedRecentProductsProvider);
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
              return ProductCard(product: paginatedState.products[index]);
            },
            childCount: paginatedState.products.length,
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
}

class _SearchBar extends StatelessWidget {
  final VoidCallback onTap;

  const _SearchBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      label: 'Buscar produtos no Compre Aqui',
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
                'Buscar em Compre Aqui',
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
