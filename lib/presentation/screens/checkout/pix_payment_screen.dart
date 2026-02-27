import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../providers/checkout_provider.dart';
import '../../widgets/shared/app_feedback.dart';
import '../../widgets/shared/glass_container.dart';

/// PIX payment screen with QR code and timer
class PixPaymentScreen extends ConsumerStatefulWidget {
  const PixPaymentScreen({super.key});

  @override
  ConsumerState<PixPaymentScreen> createState() => _PixPaymentScreenState();
}

class _PixPaymentScreenState extends ConsumerState<PixPaymentScreen> {
  Timer? _pollTimer;
  Timer? _countdownTimer;
  int _remainingSeconds = 900; // 15 minutes
  int _totalSeconds = 900; // Used for circular progress denominator
  bool _isExpired = false;

  @override
  void initState() {
    super.initState();

    // Countdown timer
    final expiration = ref.read(checkoutProvider).pixExpiration;
    if (expiration != null) {
      _remainingSeconds = expiration.difference(DateTime.now()).inSeconds.clamp(0, 1800);
    }
    _totalSeconds = _remainingSeconds;

    // Gap #5: Check expiration before starting timers
    if (_remainingSeconds <= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showExpiredDialog();
      });
      return;
    }

    // Poll for payment status every 5 seconds (only if not expired)
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (_isExpired) return;
      final paid = await ref.read(checkoutProvider.notifier).checkPixPayment();
      if (paid && mounted) {
        context.pushReplacement(AppRouter.orderSuccess);
      }
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _isExpired = true;
        _countdownTimer?.cancel();
        _pollTimer?.cancel();
        if (mounted) {
          _showExpiredDialog();
        }
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _showExpiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('PIX expirado'),
        content: const Text('O tempo para pagamento expirou. Deseja gerar um novo código?'),
        actions: [
          TextButton(
            onPressed: () => context.go(AppRouter.home),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await ref.read(checkoutProvider.notifier).regeneratePix();
              if (success && mounted) {
                final expiration = ref.read(checkoutProvider).pixExpiration;
                setState(() {
                  _isExpired = false;
                  _remainingSeconds = expiration != null
                      ? expiration.difference(DateTime.now()).inSeconds.clamp(0, 1800)
                      : 900;
                  _totalSeconds = _remainingSeconds;
                });

                // Restart countdown timer
                _countdownTimer?.cancel();
                _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
                  if (_remainingSeconds > 0) {
                    setState(() => _remainingSeconds--);
                  } else {
                    _countdownTimer?.cancel();
                    _pollTimer?.cancel();
                    if (mounted) _showExpiredDialog();
                  }
                });

                // Restart poll timer to detect payment confirmation
                _pollTimer?.cancel();
                _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
                  final paid = await ref.read(checkoutProvider.notifier).checkPixPayment();
                  if (paid && mounted) {
                    context.pushReplacement(AppRouter.orderSuccess);
                  }
                });
              }
            },
            child: const Text('Gerar novo'),
          ),
        ],
      ),
    );
  }

  void _copyPixCode() {
    final checkoutState = ref.read(checkoutProvider);
    if (checkoutState.pixCode != null) {
      Clipboard.setData(ClipboardData(text: checkoutState.pixCode!));
      AppFeedback.showInfo(context, 'Código PIX copiado!');
    }
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _showCancelDialog() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancelar pagamento?'),
        content: const Text('Se sair agora, o pagamento PIX será perdido.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sair'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Continuar aqui'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) {
      ref.read(checkoutProvider.notifier).reset();
      context.go(AppRouter.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final checkoutState = ref.watch(checkoutProvider);

    // Gap #5: Prevent accidental back-press
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _showCancelDialog();
      },
      child: Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Pagamento PIX'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: _showCancelDialog,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Success indicator
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.pix,
                size: 40,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),

            Text(
              'Aguardando pagamento',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Escaneie o QR Code ou copie o código',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            if (checkoutState.createdOrder != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  Formatters.currency(checkoutState.createdOrder!.total),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            const SizedBox(height: 24),

            // Timer with circular progress indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 36,
                  height: 36,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: _totalSeconds > 0
                            ? _remainingSeconds / _totalSeconds
                            : 0.0,
                        strokeWidth: 3,
                        color: _remainingSeconds < 60
                            ? theme.colorScheme.error
                            : AppColors.primary,
                        backgroundColor: AppColors.primary.withAlpha(30),
                      ),
                      Icon(
                        Icons.access_time,
                        size: 16,
                        color: _remainingSeconds < 60
                            ? theme.colorScheme.error
                            : AppColors.primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                GlassContainer(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  borderRadius: BorderRadius.circular(30),
                  child: Text(
                    'Expira em ${_formatTime(_remainingSeconds)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _remainingSeconds < 60
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // PIX QR Code — generated locally from the copia-e-cola string
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outline.withAlpha(30)),
              ),
              child: checkoutState.pixCode != null
                  ? QrImageView(
                      data: checkoutState.pixCode!,
                      version: QrVersions.auto,
                      size: 220,
                      backgroundColor: Colors.white,
                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                    )
                  : _buildQrPlaceholder(theme),
            ),
            const SizedBox(height: 32),

            // Copy code button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _copyPixCode,
                icon: const Icon(Icons.copy),
                label: const Text('Copiar código PIX'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // PIX code preview
            if (checkoutState.pixCode != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  checkoutState.pixCode!.length > 50
                      ? '${checkoutState.pixCode!.substring(0, 50)}...'
                      : checkoutState.pixCode!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            const SizedBox(height: 32),

            // Instructions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withAlpha(50),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Como pagar:',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _InstructionStep(
                    number: 1,
                    text: 'Abra o app do seu banco',
                  ),
                  _InstructionStep(
                    number: 2,
                    text: 'Escolha pagar via PIX com QR Code ou código',
                  ),
                  _InstructionStep(
                    number: 3,
                    text: 'Confirme as informações e finalize',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildQrPlaceholder(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: 8),
          Text(
            'Código PIX indisponível',
            style: TextStyle(color: theme.colorScheme.error),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () =>
                ref.read(checkoutProvider.notifier).regeneratePix(),
            icon: const Icon(Icons.refresh),
            label: const Text('Gerar novo código'),
          ),
        ],
      ),
    );
  }
}

class _InstructionStep extends StatelessWidget {
  final int number;
  final String text;

  const _InstructionStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
