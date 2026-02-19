import 'package:flutter/material.dart';

import '../../../data/models/product_model.dart';
import '../shared/shimmer_loading.dart';
import 'product_card.dart';

/// Product grid widget with optional shimmer loading
class ProductGrid extends StatelessWidget {
  final List<ProductModel>? products;
  final bool isLoading;
  final int shimmerCount;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final EdgeInsetsGeometry? padding;

  const ProductGrid({
    super.key,
    this.products,
    this.isLoading = false,
    this.shimmerCount = 4,
    this.physics,
    this.shrinkWrap = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading || products == null) {
      return ShimmerLoading(itemCount: shimmerCount, isGrid: true);
    }

    if (products!.isEmpty) {
      return const SizedBox.shrink();
    }

    return GridView.builder(
      shrinkWrap: shrinkWrap,
      physics: physics ?? const NeverScrollableScrollPhysics(),
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.65,
      ),
      itemCount: products!.length,
      itemBuilder: (context, index) {
        return ProductCard(product: products![index]);
      },
    );
  }
}

/// Product grid sliver for use in CustomScrollView
class SliverProductGrid extends StatelessWidget {
  final List<ProductModel>? products;
  final bool isLoading;
  final int shimmerCount;

  const SliverProductGrid({
    super.key,
    this.products,
    this.isLoading = false,
    this.shimmerCount = 4,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading || products == null) {
      return SliverToBoxAdapter(
        child: ShimmerLoading(itemCount: shimmerCount, isGrid: true),
      );
    }

    if (products!.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.65,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => ProductCard(product: products![index]),
          childCount: products!.length,
        ),
      ),
    );
  }
}
