import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../providers/checkout_provider.dart';
import '../../widgets/shared/app_feedback.dart';

/// PIX payment screen focused on copy-paste code
class PixPaymentScreen extends ConsumerStatefulWidget {
  const PixPaymentScreen({super.key});

  @override
  ConsumerState<PixPaymentScreen> createState() => _PixPaymentScreenState();
}

class _PixPaymentScreenState extends ConsumerState<PixPaymentScreen> {
  Timer? _pollTimer;
  Timer? _countdownTimer;
  int _remainingSeconds = 900; // 15 minutes
  int _totalSeconds = 900;
  bool _isExpired = false;
  bool _copied = false;

  @override
  void initState() {
    super.initState();

    final expiration = ref.read(checkoutProvider).pixExpiration;
    if (expiration != null) {
      _remainingSeconds = expiration.difference(DateTime.now()).inSeconds.clamp(0, 1800);
    }
    _totalSeconds = _remainingSeconds;

    if (_remainingSeconds <= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showExpiredDialog();
      });
      return;
    }

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
        if (mounted) _showExpiredDialog();
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
      barrierColor: Colors.black.withAlpha(100),
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                    _copied = false;
                    _remainingSeconds = expiration != null
                        ? expiration.difference(DateTime.now()).inSeconds.clamp(0, 1800)
                        : 900;
                    _totalSeconds = _remainingSeconds;
                  });

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
      ),
    );
  }

  void _copyPixCode() {
    final checkoutState = ref.read(checkoutProvider);
    if (checkoutState.pixCode != null) {
      Clipboard.setData(ClipboardData(text: checkoutState.pixCode!));
      HapticFeedback.mediumImpact();
      setState(() => _copied = true);
      AppFeedback.showInfo(context, 'Código PIX copiado!');
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _copied = false);
      });
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
      barrierColor: Colors.black.withAlpha(100),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
    final isUrgent = _remainingSeconds < 60;

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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            children: [
              // PIX icon + status
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary.withAlpha(30),
                      AppColors.primaryLight.withAlpha(20),
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primary.withAlpha(50)),
                ),
                child: const Icon(Icons.pix, size: 36, color: AppColors.primary),
              ).animate().scale(begin: const Offset(0.8, 0.8), duration: 400.ms, curve: Curves.elasticOut),
              const SizedBox(height: 20),

              Text(
                'Aguardando pagamento',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ).animate().fadeIn(delay: 100.ms, duration: 300.ms),
              const SizedBox(height: 6),
              Text(
                'Copie o código e pague no app do seu banco',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ).animate().fadeIn(delay: 150.ms, duration: 300.ms),
              const SizedBox(height: 16),

              // Amount badge
              if (checkoutState.createdOrder != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(15),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: AppColors.primary.withAlpha(40)),
                  ),
                  child: Text(
                    Formatters.currency(checkoutState.createdOrder!.total),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ).animate().fadeIn(delay: 200.ms, duration: 300.ms),
              const SizedBox(height: 20),

              // Timer
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: isUrgent
                      ? theme.colorScheme.error.withAlpha(15)
                      : theme.colorScheme.surfaceContainerHighest.withAlpha(120),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: isUrgent
                        ? theme.colorScheme.error.withAlpha(60)
                        : theme.colorScheme.outline.withAlpha(30),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        value: _totalSeconds > 0 ? _remainingSeconds / _totalSeconds : 0.0,
                        strokeWidth: 2.5,
                        color: isUrgent ? theme.colorScheme.error : AppColors.primary,
                        backgroundColor: isUrgent
                            ? theme.colorScheme.error.withAlpha(30)
                            : AppColors.primary.withAlpha(30),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Expira em ${_formatTime(_remainingSeconds)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isUrgent
                            ? theme.colorScheme.error
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // PIX Code Container
              if (checkoutState.pixCode != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.colorScheme.outline.withAlpha(40)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.content_copy_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Text(
                            'Código PIX Copia e Cola',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.colorScheme.outline.withAlpha(30)),
                        ),
                        child: SelectableText(
                          checkoutState.pixCode!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            height: 1.6,
                            color: theme.colorScheme.onSurface.withAlpha(180),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 250.ms, duration: 350.ms).slideY(begin: 0.05),
                const SizedBox(height: 16),

                // Copy button
                SizedBox(
                  width: double.infinity,
                  child: TweenAnimationBuilder<Color?>(
                    tween: ColorTween(
                      begin: _copied ? AppColors.primary : AppColors.primaryDark,
                      end: _copied ? AppColors.primaryDark : AppColors.primary,
                    ),
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                    builder: (context, color, child) {
                      return FilledButton.icon(
                        onPressed: _copyPixCode,
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            _copied ? Icons.check_rounded : Icons.copy_rounded,
                            key: ValueKey(_copied),
                            size: 20,
                          ),
                        ),
                        label: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Text(
                            _copied ? 'Copiado!' : 'Copiar código PIX',
                            key: ValueKey(_copied),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: color,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      );
                    },
                  ),
                ).animate().fadeIn(delay: 350.ms, duration: 300.ms),
              ] else ...[
                // No PIX code available
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer.withAlpha(50),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.colorScheme.error.withAlpha(40)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.error_outline, size: 40, color: theme.colorScheme.error),
                      const SizedBox(height: 12),
                      Text(
                        'Código PIX indisponível',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () => ref.read(checkoutProvider.notifier).regeneratePix(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Gerar novo código'),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),

              // Instructions
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withAlpha(60),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Como pagar',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _InstructionStep(
                      number: 1,
                      text: 'Copie o código acima',
                      icon: Icons.copy_rounded,
                    ),
                    _InstructionStep(
                      number: 2,
                      text: 'Abra o app do seu banco',
                      icon: Icons.account_balance_outlined,
                    ),
                    _InstructionStep(
                      number: 3,
                      text: 'Escolha pagar via PIX Copia e Cola',
                      icon: Icons.pix,
                    ),
                    _InstructionStep(
                      number: 4,
                      text: 'Cole o código e confirme',
                      icon: Icons.check_circle_outline,
                      isLast: true,
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 450.ms, duration: 350.ms),
              const SizedBox(height: 20),

              // Waiting indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.onSurfaceVariant.withAlpha(100),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Acompanhando o pagamento automaticamente',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withAlpha(150),
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 550.ms, duration: 300.ms),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _InstructionStep extends StatelessWidget {
  final int number;
  final String text;
  final IconData icon;
  final bool isLast;

  const _InstructionStep({
    required this.number,
    required this.text,
    required this.icon,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$number',
                style: TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(200),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
