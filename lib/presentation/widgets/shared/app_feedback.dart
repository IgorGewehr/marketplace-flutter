/// Modern feedback system (snackbars, toasts, dialogs)
library;

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// Extension on BuildContext for safe snackbar display (always clears previous)
extension SafeSnackBar on BuildContext {
  void showSafeSnackBar(SnackBar snackBar) {
    ScaffoldMessenger.of(this)
      ..clearSnackBars()
      ..showSnackBar(snackBar);
  }
}

/// Feedback types
enum FeedbackType {
  success,
  error,
  warning,
  info,
}

/// Modern feedback system
class AppFeedback {
  /// Show success message
  static void showSuccess(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onTap,
  }) {
    _showSnackBar(
      context,
      message,
      title: title,
      type: FeedbackType.success,
      duration: duration,
      onTap: onTap,
    );
  }

  /// Show error message
  static void showError(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onTap,
  }) {
    _showSnackBar(
      context,
      message,
      title: title,
      type: FeedbackType.error,
      duration: duration,
      onTap: onTap,
    );
  }

  /// Show warning message
  static void showWarning(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onTap,
  }) {
    _showSnackBar(
      context,
      message,
      title: title,
      type: FeedbackType.warning,
      duration: duration,
      onTap: onTap,
    );
  }

  /// Show info message
  static void showInfo(
    BuildContext context,
    String message, {
    String? title,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onTap,
  }) {
    _showSnackBar(
      context,
      message,
      title: title,
      type: FeedbackType.info,
      duration: duration,
      onTap: onTap,
    );
  }

  /// Show confirmation dialog
  static Future<bool> showConfirmation(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirmar',
    String cancelText = 'Cancelar',
    bool isDangerous = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _ConfirmationDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        isDangerous: isDangerous,
      ),
    );
    return result ?? false;
  }

  /// Show loading dialog
  static void showLoading(
    BuildContext context, {
    String message = 'Carregando...',
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _LoadingDialog(message: message),
    );
  }

  /// Hide loading dialog
  static void hideLoading(BuildContext context) {
    Navigator.of(context).pop();
  }

  /// Internal method to show snackbar
  static void _showSnackBar(
    BuildContext context,
    String message, {
    String? title,
    required FeedbackType type,
    required Duration duration,
    VoidCallback? onTap,
  }) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: _FeedbackContent(
          message: message,
          title: title,
          type: type,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        padding: EdgeInsets.zero,
        onVisible: onTap,
      ),
    );
  }
}

/// Feedback content widget
class _FeedbackContent extends StatelessWidget {
  final String message;
  final String? title;
  final FeedbackType type;

  const _FeedbackContent({
    required this.message,
    this.title,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getFeedbackConfig(type);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: config.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((255 * 0.1).round()),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: config.iconBackgroundColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              config.icon,
              color: config.iconColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  message,
                  style: TextStyle(
                    color: Colors.white.withAlpha((255 * 0.9).round()),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _FeedbackConfig _getFeedbackConfig(FeedbackType type) {
    switch (type) {
      case FeedbackType.success:
        return _FeedbackConfig(
          icon: LucideIcons.checkCircle2,
          iconColor: const Color(0xFF10B981),
          iconBackgroundColor: const Color(0xFF10B981).withAlpha((255 * 0.2).round()),
          backgroundColor: const Color(0xFF065F46),
        );
      case FeedbackType.error:
        return _FeedbackConfig(
          icon: LucideIcons.xCircle,
          iconColor: const Color(0xFFEF4444),
          iconBackgroundColor: const Color(0xFFEF4444).withAlpha((255 * 0.2).round()),
          backgroundColor: const Color(0xFF991B1B),
        );
      case FeedbackType.warning:
        return _FeedbackConfig(
          icon: LucideIcons.alertTriangle,
          iconColor: const Color(0xFFF59E0B),
          iconBackgroundColor: const Color(0xFFF59E0B).withAlpha((255 * 0.2).round()),
          backgroundColor: const Color(0xFF92400E),
        );
      case FeedbackType.info:
        return _FeedbackConfig(
          icon: LucideIcons.info,
          iconColor: const Color(0xFF3B82F6),
          iconBackgroundColor: const Color(0xFF3B82F6).withAlpha((255 * 0.2).round()),
          backgroundColor: const Color(0xFF1E40AF),
        );
    }
  }
}

class _FeedbackConfig {
  final IconData icon;
  final Color iconColor;
  final Color iconBackgroundColor;
  final Color backgroundColor;

  _FeedbackConfig({
    required this.icon,
    required this.iconColor,
    required this.iconBackgroundColor,
    required this.backgroundColor,
  });
}

/// Confirmation dialog
class _ConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final bool isDangerous;

  const _ConfirmationDialog({
    required this.title,
    required this.message,
    required this.confirmText,
    required this.cancelText,
    required this.isDangerous,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDangerous
                        ? const Color(0xFFEF4444).withAlpha((255 * 0.1).round())
                        : const Color(0xFF3B82F6).withAlpha((255 * 0.1).round()),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isDangerous ? LucideIcons.alertTriangle : LucideIcons.helpCircle,
                    color: isDangerous ? const Color(0xFFEF4444) : const Color(0xFF3B82F6),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(cancelText),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDangerous
                        ? const Color(0xFFEF4444)
                        : Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(confirmText),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Loading dialog
class _LoadingDialog extends StatelessWidget {
  final String message;

  const _LoadingDialog({required this.message});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
