import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Reusable profile menu item widget
class ProfileMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Widget? trailing;
  final bool showChevron;
  final bool isDestructive;

  const ProfileMenuItem({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    this.onTap,
    this.iconColor,
    this.trailing,
    this.showChevron = true,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = isDestructive 
        ? AppColors.error 
        : iconColor ?? AppColors.textSecondary;
    final effectiveLabelColor = isDestructive 
        ? AppColors.error 
        : AppColors.textPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: effectiveIconColor.withAlpha(15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: effectiveIconColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              // Label and subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: effectiveLabelColor,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Trailing widget or chevron
              if (trailing != null)
                trailing!
              else if (showChevron)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textHint,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Section divider for profile menu
class ProfileMenuSection extends StatelessWidget {
  final String? title;
  final List<ProfileMenuItem> items;

  const ProfileMenuSection({
    super.key,
    this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                title!,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ...items.map((item) => Column(
            children: [
              item,
              if (items.last != item)
                const Divider(height: 1, indent: 68),
            ],
          )),
        ],
      ),
    );
  }
}
