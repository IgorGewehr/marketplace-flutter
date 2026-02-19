import 'dart:ui';

import 'package:flutter/material.dart';

/// Glassmorphism container with frosted glass effect
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final Color? color;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderWidth;
  final Color? borderColor;
  final List<BoxShadow>? boxShadow;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 20,
    this.opacity = 0.85,
    this.color,
    this.borderRadius,
    this.padding,
    this.margin,
    this.borderWidth = 1,
    this.borderColor,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = color ?? Colors.white;
    final border = borderColor ?? theme.colorScheme.outline.withAlpha(30);
    final radius = borderRadius ?? BorderRadius.circular(16);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: boxShadow ??
            [
              BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: bgColor.withAlpha((opacity * 255).toInt()),
              borderRadius: radius,
              border: Border.all(
                color: border,
                width: borderWidth,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Glass card variant for product cards
class GlassCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const GlassCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: padding ?? const EdgeInsets.all(16),
      margin: margin,
      borderRadius: BorderRadius.circular(20),
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              child: child,
            )
          : child,
    );
  }
}

/// Glass overlay for product info on images
class GlassOverlay extends StatelessWidget {
  final Widget child;
  final AlignmentGeometry alignment;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const GlassOverlay({
    super.key,
    required this.child,
    this.alignment = Alignment.bottomCenter,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: GlassContainer(
        padding: padding ?? const EdgeInsets.all(12),
        margin: margin ?? const EdgeInsets.all(8),
        blur: 15,
        opacity: 0.9,
        borderRadius: BorderRadius.circular(12),
        child: child,
      ),
    );
  }
}
