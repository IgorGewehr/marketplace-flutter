import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/product_model.dart';
import '../../providers/my_products_provider.dart';
import '../../widgets/seller/my_product_card.dart';
import '../../widgets/shared/app_feedback.dart';

class MyProductsScreen extends ConsumerWidget {
  const MyProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(filteredMyProductsProvider);
    final allProductsAsync = ref.watch(myProductsProvider);
    final currentFilter = ref.watch(myProductsFilterProvider);
    final searchQuery = ref.watch(myProductsSearchProvider);

    // Counts from unfiltered list for the summary chips
    final allProducts = allProductsAsync.valueOrNull ?? [];
    final activeCount =
        allProducts.where((p) => p.status == 'active').length;
    final pausedCount =
        allProducts.where((p) => p.status == 'draft').length;
    final outOfStockCount = allProducts
        .where((p) =>
            p.trackInventory &&
            (p.hasVariants
                ? p.variants.every((v) => (v.quantity ?? 0) <= 0)
                : (p.quantity ?? 0) <= 0))
        .length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.sellerAccent,
        onRefresh: () => ref.read(myProductsProvider.notifier).refresh(),
        child: CustomScrollView(
          slivers: [
            // ── App Bar ────────────────────────────────────────────
            SliverAppBar(
              floating: true,
              pinned: true,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Meus Produtos',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (allProductsAsync.hasValue && allProducts.isNotEmpty)
                    Text(
                      '${allProducts.length} produto${allProducts.length == 1 ? '' : 's'}'
                      ' · $activeCount ativo${activeCount == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                ],
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: FilledButton.icon(
                    onPressed: () => context.push('/seller/products/new'),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Novo'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 0),
                      visualDensity: VisualDensity.compact,
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(104),
                child: Column(
                  children: [
                    // Search bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _SearchBar(
                        onChanged: (v) => ref
                            .read(myProductsSearchProvider.notifier)
                            .state = v,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Filter chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          _FilterChip(
                            label: 'Todos',
                            count: allProducts.length,
                            isSelected:
                                currentFilter == MyProductsFilter.all,
                            onTap: () => ref
                                .read(myProductsFilterProvider.notifier)
                                .state = MyProductsFilter.all,
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Ativos',
                            count: activeCount,
                            isSelected:
                                currentFilter == MyProductsFilter.active,
                            activeColor: AppColors.secondary,
                            onTap: () => ref
                                .read(myProductsFilterProvider.notifier)
                                .state = MyProductsFilter.active,
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Pausados',
                            count: pausedCount,
                            isSelected:
                                currentFilter == MyProductsFilter.paused,
                            activeColor: AppColors.textSecondary,
                            onTap: () => ref
                                .read(myProductsFilterProvider.notifier)
                                .state = MyProductsFilter.paused,
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Sem estoque',
                            count: outOfStockCount,
                            isSelected:
                                currentFilter == MyProductsFilter.outOfStock,
                            activeColor: AppColors.warning,
                            onTap: () => ref
                                .read(myProductsFilterProvider.notifier)
                                .state = MyProductsFilter.outOfStock,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),

            // ── Product List ───────────────────────────────────────
            productsAsync.when(
              data: (products) {
                if (products.isEmpty) {
                  // SliverFillRemaining(hasScrollBody:false) computes its
                  // height as viewportMainAxisExtent - precedingScrollExtent.
                  // With a pinned SliverAppBar that has scrollExtent=0, this
                  // equals the FULL viewport, starting at y=0 (behind the
                  // AppBar). Using SliverLayoutBuilder gives us the actual
                  // remaining paint extent (below the AppBar), so the content
                  // always renders in the visible area.
                  return SliverLayoutBuilder(
                    builder: (context, constraints) {
                      return SliverToBoxAdapter(
                        child: SizedBox(
                          height: math.max(
                            300.0,
                            constraints.remainingPaintExtent - 120,
                          ),
                          child: _EmptyState(
                            hasSearch: searchQuery.isNotEmpty ||
                                currentFilter != MyProductsFilter.all,
                            onAddProduct: () =>
                                context.push('/seller/products/new'),
                          ),
                        ),
                      );
                    },
                  );
                }

                return SliverPadding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final product = products[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: MyProductCard(
                            product: product,
                            onTap: () => context
                                .push('/seller/products/${product.id}/edit'),
                            onEdit: () => context
                                .push('/seller/products/${product.id}/edit'),
                            onToggleStatus: () => ref
                                .read(myProductsProvider.notifier)
                                .toggleProductStatus(product.id),
                            onDelete: () =>
                                _confirmDelete(context, ref, product),
                            onDuplicate: () =>
                                _duplicateProduct(context, product),
                          ),
                        );
                      },
                      childCount: products.length,
                    ),
                  ),
                );
              },
              loading: () => SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, _) => const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: _SkeletonCard(),
                    ),
                    childCount: 4,
                  ),
                ),
              ),
              error: (error, _) => SliverLayoutBuilder(
                builder: (context, constraints) {
                  return SliverToBoxAdapter(
                    child: SizedBox(
                      height: math.max(
                        300.0,
                        constraints.remainingPaintExtent - 120,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.error.withAlpha(15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.error_outline_rounded,
                                size: 40,
                                color: AppColors.error,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Erro ao carregar produtos',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Puxe para baixo para tentar novamente',
                              style: TextStyle(color: AppColors.textHint),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
          ],
        ),
      ),
    );
  }

  void _duplicateProduct(BuildContext context, ProductModel product) {
    final duplicate = product.copyWith(
      name: 'Cópia de ${product.name}',
      status: 'draft',
    );
    context.push('/seller/products/new', extra: duplicate);
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, ProductModel product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.error.withAlpha(20),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.delete_outline_rounded,
            color: AppColors.error,
            size: 28,
          ),
        ),
        title: const Text('Excluir produto?'),
        content: Text(
          '"${product.name}" será removido permanentemente.\n\nEsta ação não pode ser desfeita.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    ref.read(myProductsProvider.notifier).deleteProduct(product.id);
    AppFeedback.showSuccess(context, 'Produto excluído');
  }
}

// ── Search Bar ─────────────────────────────────────────────────────────────

class _SearchBar extends StatefulWidget {
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.onChanged});

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: TextField(
        controller: _controller,
        onChanged: widget.onChanged,
        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Buscar produtos...',
          hintStyle: const TextStyle(
            fontSize: 14,
            color: AppColors.textHint,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.textHint,
            size: 20,
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (_, value, child) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    icon: const Icon(Icons.close_rounded,
                        size: 18, color: AppColors.textHint),
                    onPressed: () {
                      _controller.clear();
                      widget.onChanged('');
                    },
                  ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

// ── Filter Chip ────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.isSelected,
    this.activeColor = AppColors.sellerAccent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : AppColors.border,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withAlpha(40),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withAlpha(50)
                      : activeColor.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : activeColor,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Empty State ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasSearch;
  final VoidCallback onAddProduct;

  const _EmptyState({
    required this.hasSearch,
    required this.onAddProduct,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.sellerAccent.withAlpha(12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasSearch
                    ? Icons.search_off_rounded
                    : Icons.inventory_2_outlined,
                size: 52,
                color: AppColors.sellerAccent.withAlpha(150),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              hasSearch
                  ? 'Nenhum produto encontrado'
                  : 'Ainda sem produtos',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasSearch
                  ? 'Tente outro termo ou remova os filtros'
                  : 'Crie seu primeiro produto\ne comece a vender agora',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textHint,
                height: 1.5,
              ),
            ),
            if (!hasSearch) ...[
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: onAddProduct,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Criar Produto'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.sellerAccent,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 14),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Skeleton Loading Card ──────────────────────────────────────────────────

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            decoration: BoxDecoration(
              color: AppColors.borderLight,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                bottomLeft: Radius.circular(15),
              ),
            ),
          ),
          Container(
            width: 110,
            color: AppColors.surfaceVariant,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _shimmerBox(height: 14, width: double.infinity),
                  const SizedBox(height: 6),
                  _shimmerBox(height: 14, width: 120),
                  const Spacer(),
                  _shimmerBox(height: 18, width: 90),
                  const Spacer(),
                  _shimmerBox(height: 10, width: 140),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shimmerBox({required double height, required double width}) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}
