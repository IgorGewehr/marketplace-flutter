import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../providers/checkout_provider.dart';
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

  @override
  void initState() {
    super.initState();
    
    // Poll for payment status every 5 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final paid = await ref.read(checkoutProvider.notifier).checkPixPayment();
      if (paid && mounted) {
        context.pushReplacement(AppRouter.orderSuccess);
      }
    });

    // Countdown timer
    final expiration = ref.read(checkoutProvider).pixExpiration;
    if (expiration != null) {
      _remainingSeconds = expiration.difference(DateTime.now()).inSeconds.clamp(0, 1800);
    }

    if (_remainingSeconds <= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showExpiredDialog();
      });
      return;
    }

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        _countdownTimer?.cancel();
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
                  _remainingSeconds = expiration != null
                      ? expiration.difference(DateTime.now()).inSeconds.clamp(0, 1800)
                      : 900;
                });
                _countdownTimer?.cancel();
                _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
                  if (_remainingSeconds > 0) {
                    setState(() => _remainingSeconds--);
                  } else {
                    _countdownTimer?.cancel();
                    if (mounted) _showExpiredDialog();
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Código PIX copiado!')),
      );
    }
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final checkoutState = ref.watch(checkoutProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Pagamento PIX'),
        backgroundColor: theme.colorScheme.surface,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () => context.go(AppRouter.home),
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
            const SizedBox(height: 24),

            // Timer
            GlassContainer(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              borderRadius: BorderRadius.circular(30),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.access_time,
                    size: 18,
                    color: _remainingSeconds < 60
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Expira em ${_formatTime(_remainingSeconds)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _remainingSeconds < 60
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // QR Code placeholder (in real app, show actual QR)
            Container(
              width: 220,
              height: 220,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outline.withAlpha(30)),
              ),
              child: checkoutState.pixQrCode != null
                  ? Image.network(
                      checkoutState.pixQrCode!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => _buildQrPlaceholder(theme),
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
    );
  }

  Widget _buildQrPlaceholder(ThemeData theme) {
    return Center(
      child: Icon(
        Icons.qr_code_2,
        size: 150,
        color: theme.colorScheme.primary.withAlpha(50),
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
