import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../data/models/service_model.dart';
import '../shared/shimmer_loading.dart';
import 'service_card.dart';

/// Service grid widget with optional shimmer loading
class ServiceGrid extends StatelessWidget {
  final List<MarketplaceServiceModel>? services;
  final bool isLoading;
  final int shimmerCount;
  final ScrollPhysics? physics;
  final bool shrinkWrap;
  final EdgeInsetsGeometry? padding;

  const ServiceGrid({
    super.key,
    this.services,
    this.isLoading = false,
    this.shimmerCount = 4,
    this.physics,
    this.shrinkWrap = false,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading || services == null) {
      return ShimmerLoading(itemCount: shimmerCount, isGrid: true);
    }

    if (services!.isEmpty) {
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
        childAspectRatio: 0.60, // Slightly taller for service cards
      ),
      itemCount: services!.length,
      itemBuilder: (context, index) {
        return ServiceCard(service: services![index])
            .animate(delay: Duration(milliseconds: (index % 6) * 60))
            .fadeIn(duration: 300.ms, curve: Curves.easeOut)
            .slideY(begin: 0.08, end: 0, duration: 300.ms, curve: Curves.easeOut);
      },
    );
  }
}

/// Service grid sliver for use in CustomScrollView
class SliverServiceGrid extends StatelessWidget {
  final List<MarketplaceServiceModel>? services;
  final bool isLoading;
  final int shimmerCount;

  const SliverServiceGrid({
    super.key,
    this.services,
    this.isLoading = false,
    this.shimmerCount = 4,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading || services == null) {
      return SliverToBoxAdapter(
        child: ShimmerLoading(itemCount: shimmerCount, isGrid: true),
      );
    }

    if (services!.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.60, // Slightly taller for service cards
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => ServiceCard(service: services![index])
              .animate(delay: Duration(milliseconds: (index % 6) * 60))
              .fadeIn(duration: 300.ms, curve: Curves.easeOut)
              .slideY(begin: 0.08, end: 0, duration: 300.ms, curve: Curves.easeOut),
          childCount: services!.length,
        ),
      ),
    );
  }
}
