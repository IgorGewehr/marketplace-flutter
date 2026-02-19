/// Modern loading indicators and screens
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Modern circular loading indicator
class ModernLoading extends StatelessWidget {
  final double size;
  final Color? color;

  const ModernLoading({
    super.key,
    this.size = 40,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: 3,
        valueColor: AlwaysStoppedAnimation(
          color ?? Theme.of(context).primaryColor,
        ),
      ),
    );
  }
}

/// Full screen loading
class FullScreenLoading extends StatelessWidget {
  final String? message;

  const FullScreenLoading({
    super.key,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const ModernLoading(size: 48),
            if (message != null) ...[
              const SizedBox(height: 24),
              Text(
                message!,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shimmer loading effect
class ShimmerLoading extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const ShimmerLoading({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: borderRadius ?? BorderRadius.circular(8),
      ),
    )
        .animate(onPlay: (controller) => controller.repeat())
        .shimmer(
          duration: 1500.ms,
          color: Colors.grey[100]!,
        );
  }
}

/// Skeleton loader for cards
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((255 * 0.05).round()),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerLoading(
            width: double.infinity,
            height: 200,
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          const SizedBox(height: 12),
          const ShimmerLoading(width: 150, height: 20),
          const SizedBox(height: 8),
          const ShimmerLoading(width: double.infinity, height: 16),
          const SizedBox(height: 8),
          const ShimmerLoading(width: 200, height: 16),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const ShimmerLoading(width: 80, height: 24),
              ShimmerLoading(
                width: 100,
                height: 36,
                borderRadius: BorderRadius.circular(18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Skeleton loader for list items
class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const ShimmerLoading(
            width: 60,
            height: 60,
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ShimmerLoading(width: 150, height: 16),
                const SizedBox(height: 8),
                const ShimmerLoading(width: double.infinity, height: 14),
                const SizedBox(height: 8),
                ShimmerLoading(
                  width: 100,
                  height: 20,
                  borderRadius: BorderRadius.circular(10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pulsing loading indicator
class PulsingLoading extends StatelessWidget {
  final double size;
  final Color? color;

  const PulsingLoading({
    super.key,
    this.size = 60,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final loadingColor = color ?? Theme.of(context).primaryColor;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: loadingColor.withAlpha((255 * 0.2).round()),
              shape: BoxShape.circle,
            ),
          )
              .animate(onPlay: (controller) => controller.repeat())
              .scale(
                begin: const Offset(0.8, 0.8),
                end: const Offset(1.2, 1.2),
                duration: 1000.ms,
              )
              .fade(begin: 0.5, end: 0.0),
          Container(
            width: size * 0.5,
            height: size * 0.5,
            decoration: BoxDecoration(
              color: loadingColor,
              shape: BoxShape.circle,
            ),
          )
              .animate(onPlay: (controller) => controller.repeat())
              .scale(
                begin: const Offset(1.0, 1.0),
                end: const Offset(0.8, 0.8),
                duration: 1000.ms,
              ),
        ],
      ),
    );
  }
}

/// Dots loading indicator
class DotsLoading extends StatelessWidget {
  final double size;
  final Color? color;

  const DotsLoading({
    super.key,
    this.size = 12,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = color ?? Theme.of(context).primaryColor;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return Container(
          margin: EdgeInsets.symmetric(horizontal: size * 0.2),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          )
              .animate(
                onPlay: (controller) => controller.repeat(),
                delay: (index * 200).ms,
              )
              .moveY(
                begin: 0,
                end: -size,
                duration: 600.ms,
                curve: Curves.easeInOut,
              )
              .then()
              .moveY(
                begin: -size,
                end: 0,
                duration: 600.ms,
                curve: Curves.easeInOut,
              ),
        );
      }),
    );
  }
}

/// Spinning loading indicator
class SpinningLoading extends StatelessWidget {
  final double size;
  final Color? color;

  const SpinningLoading({
    super.key,
    this.size = 40,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final spinColor = color ?? Theme.of(context).primaryColor;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              border: Border.all(
                color: spinColor.withAlpha((255 * 0.2).round()),
                width: 3,
              ),
              shape: BoxShape.circle,
            ),
          ),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: spinColor, width: 3),
                right: BorderSide(color: Colors.transparent, width: 3),
                bottom: BorderSide(color: Colors.transparent, width: 3),
                left: BorderSide(color: Colors.transparent, width: 3),
              ),
              shape: BoxShape.circle,
            ),
          )
              .animate(onPlay: (controller) => controller.repeat())
              .rotate(duration: 1000.ms),
        ],
      ),
    );
  }
}

/// Loading overlay
class LoadingOverlay extends StatelessWidget {
  final Widget child;
  final bool isLoading;
  final String? message;

  const LoadingOverlay({
    super.key,
    required this.child,
    required this.isLoading,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black.withAlpha((255 * 0.5).round()),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const PulsingLoading(size: 60),
                    if (message != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        message!,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Adaptive loading indicator based on platform
class AdaptiveLoading extends StatelessWidget {
  final double size;
  final Color? color;

  const AdaptiveLoading({
    super.key,
    this.size = 40,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Theme.of(context).platform == TargetPlatform.iOS
        ? SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator.adaptive(
              valueColor: AlwaysStoppedAnimation(
                color ?? Theme.of(context).primaryColor,
              ),
            ),
          )
        : ModernLoading(size: size, color: color);
  }
}
