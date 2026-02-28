import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../providers/checkout_provider.dart';

/// Order success screen with confetti animation
class OrderSuccessScreen extends ConsumerStatefulWidget {
  const OrderSuccessScreen({super.key});

  @override
  ConsumerState<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends ConsumerState<OrderSuccessScreen>
    with TickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _pulseController;
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 4));
    _confettiController.play();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  void _navigateHome() {
    context.go(AppRouter.home);
  }

  void _navigateToOrder() {
    final order = ref.read(checkoutProvider).createdOrder;
    if (order != null) {
      context.go('/orders/${order.id}');
    } else {
      context.go(AppRouter.orders);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final checkoutState = ref.watch(checkoutProvider);
    final order = checkoutState.createdOrder;
    final isPix = checkoutState.paymentMethod == PaymentMethod.pix;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _navigateHome();
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: Stack(
          children: [
            // Subtle gradient background
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      theme.colorScheme.primary.withAlpha(12),
                      theme.colorScheme.surface,
                      theme.colorScheme.surface,
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
            ),

            // Content
            SafeArea(
              child: Column(
                children: [
                  // Top bar with close button
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8, right: 8),
                      child: IconButton(
                        onPressed: _navigateHome,
                        icon: const Icon(Icons.close_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          foregroundColor: theme.colorScheme.onSurfaceVariant,
                        ),
                        tooltip: 'Fechar',
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 1200.ms, duration: 400.ms),

                  // Scrollable content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          const SizedBox(height: 24),

                          // Success icon with animated glow + elasticOut entrance
                          _SuccessIcon(pulseController: _pulseController)
                              .animate()
                              .scale(
                                begin: const Offset(0, 0),
                                end: const Offset(1, 1),
                                duration: 800.ms,
                                curve: Curves.elasticOut,
                              )
                              .fadeIn(duration: 300.ms),
                          const SizedBox(height: 28),

                          // Title
                          Text(
                            'Pedido confirmado!',
                            style:
                                theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          )
                              .animate()
                              .fadeIn(delay: 500.ms, duration: 500.ms)
                              .slideY(
                                begin: 0.3,
                                end: 0,
                                delay: 500.ms,
                                duration: 500.ms,
                                curve: Curves.elasticOut,
                              )
                              .scale(
                                begin: const Offset(0.8, 0.8),
                                end: const Offset(1, 1),
                                delay: 500.ms,
                                duration: 600.ms,
                                curve: Curves.elasticOut,
                              ),
                          const SizedBox(height: 8),

                          // Subtitle
                          Text(
                            isPix
                                ? 'Pagamento via PIX confirmado com sucesso'
                                : 'Seu pedido foi realizado com sucesso',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          )
                              .animate()
                              .fadeIn(delay: 650.ms, duration: 400.ms)
                              .slideY(
                                begin: 0.15,
                                end: 0,
                                delay: 650.ms,
                                duration: 400.ms,
                                curve: Curves.easeOutCubic,
                              ),

                          if (order != null) ...[
                            const SizedBox(height: 32),

                            // Order summary card
                            _OrderSummaryCard(
                              order: order,
                              isPix: isPix,
                            )
                                .animate()
                                .fadeIn(delay: 800.ms, duration: 500.ms)
                                .slideY(
                                  begin: 0.15,
                                  end: 0,
                                  delay: 800.ms,
                                  duration: 500.ms,
                                  curve: Curves.easeOutCubic,
                                ),

                            const SizedBox(height: 16),

                            // Next steps hint
                            _NextStepsHint()
                                .animate()
                                .fadeIn(delay: 1000.ms, duration: 400.ms)
                                .slideY(
                                  begin: 0.1,
                                  end: 0,
                                  delay: 1000.ms,
                                  duration: 400.ms,
                                ),
                          ],

                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),

                  // Bottom actions
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _navigateToOrder,
                            icon: const Icon(Icons.receipt_long_rounded,
                                size: 20),
                            label: const Text('Ver pedido'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _navigateHome,
                            icon: const Icon(Icons.storefront_rounded,
                                size: 20),
                            label: const Text('Continuar comprando'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 1100.ms, duration: 500.ms)
                      .slideY(
                        begin: 0.2,
                        end: 0,
                        delay: 1100.ms,
                        duration: 500.ms,
                        curve: Curves.easeOutCubic,
                      ),
                ],
              ),
            ),

            // Confetti
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                colors: [
                  AppColors.primary,
                  AppColors.secondary,
                  AppColors.primaryLight,
                  AppColors.primaryDark,
                  const Color(0xFF81C784), // light green
                  const Color(0xFFE8F5E9), // very light green
                ],
                emissionFrequency: 0.04,
                numberOfParticles: 25,
                gravity: 0.2,
                maxBlastForce: 30,
                minBlastForce: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated success icon with pulsing glow
class _SuccessIcon extends StatelessWidget {
  final AnimationController pulseController;

  const _SuccessIcon({required this.pulseController});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: pulseController,
      builder: (context, child) {
        final glowRadius = 24.0 + (pulseController.value * 12.0);
        final glowAlpha = (40 + (pulseController.value * 30)).toInt();

        return Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withAlpha(glowAlpha),
                blurRadius: glowRadius,
                spreadRadius: 4 + (pulseController.value * 4),
              ),
            ],
          ),
          child: child,
        );
      },
      child: const Icon(
        Icons.check_rounded,
        size: 60,
        color: Colors.white,
      ),
    );
  }
}

/// Order summary card with visual hierarchy
class _OrderSummaryCard extends StatelessWidget {
  final dynamic order;
  final bool isPix;

  const _OrderSummaryCard({required this.order, required this.isPix});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withAlpha(60),
        ),
      ),
      child: Column(
        children: [
          // Header with payment method indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withAlpha(15),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isPix ? Icons.pix_rounded : Icons.credit_card_rounded,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  isPix ? 'Pago via PIX' : 'Pago com cartao',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Confirmado',
                        style: TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Order details
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _DetailRow(
                  label: 'Pedido',
                  value:
                      '#${order.orderNumber.isNotEmpty ? order.orderNumber : (order.id.length >= 8 ? order.id.substring(0, 8).toUpperCase() : order.id.toUpperCase())}',
                  isMono: true,
                ),
                const SizedBox(height: 14),
                _DetailRow(
                  label: 'Total',
                  value: Formatters.currency(order.total),
                  isPrimary: true,
                ),
                const SizedBox(height: 14),
                _DetailRow(
                  label: 'Itens',
                  value:
                      '${order.totalItemsQuantity} ${order.totalItemsQuantity == 1 ? 'item' : 'itens'}',
                ),
                if (order.estimatedDelivery != null) ...[
                  const SizedBox(height: 14),
                  _DetailRow(
                    label: 'Entrega estimada',
                    value: Formatters.date(order.estimatedDelivery!),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Row for order detail display
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isPrimary;
  final bool isMono;

  const _DetailRow({
    required this.label,
    required this.value,
    this.isPrimary = false,
    this.isMono = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            fontFamily: isMono ? 'monospace' : null,
            color: isPrimary ? theme.colorScheme.primary : null,
          ),
        ),
      ],
    );
  }
}

/// Next steps hint card
class _NextStepsHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withAlpha(40),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.secondaryContainer.withAlpha(80),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.local_shipping_outlined,
            size: 22,
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Acompanhe o status do seu pedido na aba "Meus Pedidos"',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
