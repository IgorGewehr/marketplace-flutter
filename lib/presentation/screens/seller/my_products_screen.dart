import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/product_model.dart';
import '../../providers/my_products_provider.dart';
import '../../widgets/seller/my_product_card.dart';
import '../../widgets/shared/app_feedback.dart';

/// Screen showing seller's products with filters
class MyProductsScreen extends ConsumerWidget {
  const MyProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(filteredMyProductsProvider);
    final currentFilter = ref.watch(myProductsFilterProvider);
    final searchQuery = ref.watch(myProductsSearchProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.sellerAccent,
        onRefresh: () => ref.read(myProductsProvider.notifier).refresh(),
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverAppBar(
              floating: true,
              pinned: true,
              backgroundColor: AppColors.background,
              elevation: 0,
              title: Text(
                'Meus Produtos',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.add_rounded, color: AppColors.sellerAccent),
                  onPressed: () => context.push('/seller/products/new'),
                ),
                const SizedBox(width: 8),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(112),
                child: Column(
                  children: [
                    // Search bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        onChanged: (value) {
                          ref.read(myProductsSearchProvider.notifier).state = value;
                        },
                        decoration: InputDecoration(
                          hintText: 'Buscar produtos...',
                          prefixIcon: const Icon(Icons.search, color: AppColors.textHint),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Filter chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          _FilterChip(
                            label: 'Todos',
                            isSelected: currentFilter == MyProductsFilter.all,
                            onTap: () => ref.read(myProductsFilterProvider.notifier).state = MyProductsFilter.all,
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Ativos',
                            isSelected: currentFilter == MyProductsFilter.active,
                            onTap: () => ref.read(myProductsFilterProvider.notifier).state = MyProductsFilter.active,
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Pausados',
                            isSelected: currentFilter == MyProductsFilter.paused,
                            onTap: () => ref.read(myProductsFilterProvider.notifier).state = MyProductsFilter.paused,
                          ),
                          const SizedBox(width: 8),
                          _FilterChip(
                            label: 'Sem estoque',
                            isSelected: currentFilter == MyProductsFilter.outOfStock,
                            onTap: () => ref.read(myProductsFilterProvider.notifier).state = MyProductsFilter.outOfStock,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            
            // Products Grid
            productsAsync.when(
              data: (products) {
                if (products.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(
                      hasSearch: searchQuery.isNotEmpty,
                      onAddProduct: () => context.push('/seller/products/new'),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final product = products[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: MyProductCard(
                            product: product,
                            onTap: () => context.push('/seller/products/${product.id}/edit'),
                            onEdit: () => context.push('/seller/products/${product.id}/edit'),
                            onToggleStatus: () {
                              ref.read(myProductsProvider.notifier).toggleProductStatus(product.id);
                            },
                            onDelete: () => _confirmDelete(context, ref, product),
                          ),
                        );
                      },
                      childCount: products.length,
                    ),
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.sellerAccent),
                ),
              ),
              error: (error, _) => SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                      const SizedBox(height: 16),
                      const Text('Erro ao carregar produtos. Puxe para atualizar.'),
                    ],
                  ),
                ),
              ),
            ),
            
            // Bottom padding
            const SliverPadding(padding: EdgeInsets.only(bottom: 120)),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, ProductModel product) async {
    final confirmed = await AppFeedback.showConfirmation(
      context,
      title: 'Excluir produto',
      message: 'Tem certeza que deseja excluir este produto?',
      isDangerous: true,
    );

    if (confirmed) {
      ref.read(myProductsProvider.notifier).deleteProduct(product.id);
      if (context.mounted) {
        AppFeedback.showSuccess(context, 'Produto excluído');
      }
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.sellerAccent : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.sellerAccent : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasSearch ? Icons.search_off : Icons.inventory_2_outlined,
              size: 72,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 16),
            Text(
              hasSearch
                  ? 'Nenhum produto encontrado'
                  : 'Nenhum produto cadastrado',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasSearch
                  ? 'Tente outro termo de busca'
                  : 'Adicione seu primeiro produto para começar a vender',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textHint,
              ),
            ),
            if (!hasSearch) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onAddProduct,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sellerAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Adicionar Produto'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
