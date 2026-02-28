import 'package:flutter/material.dart';

/// Section header with title and "Ver todos" button
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onActionPressed;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onActionPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (actionLabel != null && onActionPressed != null)
            TextButton.icon(
              onPressed: onActionPressed,
              icon: Text(
                actionLabel!,
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              label: Icon(
                Icons.chevron_right,
                size: 18,
                color: theme.colorScheme.primary,
              ),
            ),
        ],
      ),
    );
  }
}
