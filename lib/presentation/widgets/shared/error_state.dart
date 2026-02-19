import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Error state widget with icon, message, and retry button
class ErrorState extends StatelessWidget {
  final String? title;
  final String message;
  final VoidCallback? onRetry;
  final IconData icon;

  const ErrorState({
    super.key,
    this.title,
    this.message = 'Algo deu errado. Tente novamente.',
    this.onRetry,
    this.icon = Icons.error_outline_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.error.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 24),
            if (title != null) ...[
              Text(
                title!,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
            ],
            Text(
              message,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text(
                  'Tentar novamente',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Network error state
class NetworkErrorState extends StatelessWidget {
  final VoidCallback? onRetry;

  const NetworkErrorState({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ErrorState(
      icon: Icons.wifi_off_rounded,
      title: 'Sem conexão',
      message: 'Verifique sua conexão com a internet e tente novamente.',
      onRetry: onRetry,
    );
  }
}

/// Server error state
class ServerErrorState extends StatelessWidget {
  final VoidCallback? onRetry;

  const ServerErrorState({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ErrorState(
      icon: Icons.cloud_off_rounded,
      title: 'Serviço indisponível',
      message: 'Nossos servidores estão sobrecarregados. Tente novamente em alguns minutos.',
      onRetry: onRetry,
    );
  }
}
