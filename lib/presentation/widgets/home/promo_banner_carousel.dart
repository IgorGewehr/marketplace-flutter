import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/promo_banner_model.dart';
import '../../providers/products_provider.dart';

/// Promotional banner carousel with auto-scroll and page indicators
class PromoBannerCarousel extends ConsumerStatefulWidget {
  const PromoBannerCarousel({super.key});

  @override
  ConsumerState<PromoBannerCarousel> createState() =>
      _PromoBannerCarouselState();
}

class _PromoBannerCarouselState extends ConsumerState<PromoBannerCarousel> {
  final PageController _pageController = PageController(viewportFraction: 0.92);
  int _currentPage = 0;
  Timer? _autoScrollTimer;

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoScroll(List<PromoBanner> banners) {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (banners.isEmpty || !_pageController.hasClients) return;

      final nextPage = (_currentPage + 1) % banners.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final bannersAsync = ref.watch(promoBannersProvider);

    return bannersAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (banners) {
        if (banners.isEmpty) return const SizedBox.shrink();

        // Start auto-scroll when data arrives
        if (_autoScrollTimer == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _startAutoScroll(banners);
          });
        }

        return Column(
          children: [
            SizedBox(
              height: 140,
              child: PageView.builder(
                controller: _pageController,
                itemCount: banners.length,
                onPageChanged: (page) => setState(() => _currentPage = page),
                itemBuilder: (context, index) {
                  final banner = banners[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _BannerCard(banner: banner),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            // Page indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                banners.length,
                (index) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _currentPage == index ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.outline.withAlpha(60),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BannerCard extends StatelessWidget {
  final PromoBanner banner;

  const _BannerCard({required this.banner});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            banner.color,
            banner.color.withAlpha(180),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  banner.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  banner.subtitle,
                  style: TextStyle(
                    color: Colors.white.withAlpha(210),
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (banner.imageUrl != null) ...[
            const SizedBox(width: 12),
            Icon(
              Icons.local_offer_rounded,
              color: Colors.white.withAlpha(150),
              size: 48,
            ),
          ],
        ],
      ),
    );
  }
}
