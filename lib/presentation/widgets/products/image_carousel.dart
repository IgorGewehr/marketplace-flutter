import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import 'fullscreen_image_viewer.dart';

/// Full-width image carousel with pagination dots and numeric counter
class ImageCarousel extends StatefulWidget {
  final List<String> images;
  final double height;
  final BorderRadius? borderRadius;
  final bool showIndicators;
  final BoxFit fit;
  final String? heroTag;

  const ImageCarousel({
    super.key,
    required this.images,
    this.height = 300,
    this.borderRadius,
    this.showIndicators = true,
    this.fit = BoxFit.cover,
    this.heroTag,
  });

  @override
  State<ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<ImageCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final Map<int, int> _retryKeys = {};

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _openFullscreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FullscreenImageViewer(
          images: widget.images,
          initialIndex: _currentPage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return _buildPlaceholder();
    }

    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          // Image pages
          PageView.builder(
            controller: _pageController,
            onPageChanged: (page) => setState(() => _currentPage = page),
            itemCount: widget.images.length,
            itemBuilder: (context, index) {
              final imageUrl = widget.images[index];
              final imageWidget = ClipRRect(
                borderRadius: widget.borderRadius ?? BorderRadius.zero,
                child: CachedNetworkImage(
                  key: ValueKey('${imageUrl}_${_retryKeys[index] ?? 0}'),
                  imageUrl: imageUrl,
                  fit: widget.fit,
                  width: double.infinity,
                  height: widget.height,
                  memCacheWidth: 800,
                  memCacheHeight: 600,
                  fadeInDuration: const Duration(milliseconds: 300),
                  fadeOutDuration: const Duration(milliseconds: 150),
                  placeholder: (_, __) => _buildShimmerPlaceholder(),
                  errorWidget: (context, url, error) => GestureDetector(
                    onTap: () {
                      CachedNetworkImage.evictFromCache(imageUrl);
                      setState(() {
                        _retryKeys[index] = (_retryKeys[index] ?? 0) + 1;
                      });
                    },
                    child: _buildErrorPlaceholder(),
                  ),
                ),
              );
              return GestureDetector(
                onTap: _openFullscreen,
                child: index == 0 && widget.heroTag != null
                    ? Hero(tag: widget.heroTag!, child: imageWidget)
                    : imageWidget,
              );
            },
          ),

          // Numeric counter (top right) - "1/5"
          if (widget.images.length > 1)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(150),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_currentPage + 1}/${widget.images.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

          // Page indicators (dots at bottom)
          if (widget.showIndicators && widget.images.length > 1)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.images.length,
                  (index) => _PageIndicator(
                    isActive: index == _currentPage,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    final theme = Theme.of(context);
    return Container(
      height: widget.height,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 60,
          color: theme.colorScheme.onSurfaceVariant.withAlpha(100),
        ),
      ),
    );
  }

  Widget _buildShimmerPlaceholder() {
    final theme = Theme.of(context);
    return Shimmer.fromColors(
      baseColor: theme.colorScheme.surfaceContainerHighest,
      highlightColor: theme.colorScheme.surface,
      child: Container(
        height: widget.height,
        color: theme.colorScheme.surfaceContainerHighest,
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    final theme = Theme.of(context);
    return Container(
      height: widget.height,
      color: theme.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_not_supported_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withAlpha(120),
            ),
            const SizedBox(height: 8),
            Text(
              'Toque para tentar novamente',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant.withAlpha(160),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  final bool isActive;

  const _PageIndicator({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.white.withAlpha(100),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(40),
            blurRadius: 4,
          ),
        ],
      ),
    );
  }
}
