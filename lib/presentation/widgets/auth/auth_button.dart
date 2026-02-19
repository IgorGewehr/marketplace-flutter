import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Glass-styled button with loading state for authentication forms
class AuthButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? textColor;
  final double? width;
  final double height;
  final double borderRadius;

  const AuthButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.icon,
    this.backgroundColor,
    this.textColor,
    this.width,
    this.height = 56,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDisabled = onPressed == null || isLoading;

    final bgColor = backgroundColor ??
        (isOutlined ? Colors.transparent : theme.colorScheme.primary);
    final fgColor = textColor ??
        (isOutlined ? theme.colorScheme.primary : Colors.white);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: isOutlined
            ? null
            : LinearGradient(
                colors: [
                  bgColor,
                  bgColor.withAlpha((255 * 0.85).round()),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        border: isOutlined
            ? Border.all(
                color: isDisabled
                    ? theme.colorScheme.outline.withAlpha((255 * 0.5).round())
                    : theme.colorScheme.primary,
                width: 1.5,
              )
            : null,
        boxShadow: isOutlined || isDisabled
            ? null
            : [
                BoxShadow(
                  color: bgColor.withAlpha((255 * 0.3).round()),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isDisabled ? null : onPressed,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(fgColor),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(
                          icon,
                          color: isDisabled ? fgColor.withAlpha((255 * 0.5).round()) : fgColor,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                      ],
                      Text(
                        text,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: isDisabled ? fgColor.withAlpha((255 * 0.5).round()) : fgColor,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Secondary text button for auth flows
class AuthTextButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? color;

  const AuthTextButton({
    super.key,
    required this.text,
    this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color ?? Theme.of(context).colorScheme.primary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Divider with text (e.g., "ou")
class AuthDivider extends StatelessWidget {
  final String text;

  const AuthDivider({
    super.key,
    this.text = 'ou',
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outline;

    return Row(
      children: [
        Expanded(child: Divider(color: color)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(child: Divider(color: color)),
      ],
    );
  }
}
