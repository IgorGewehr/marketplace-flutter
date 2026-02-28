import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/order_model.dart';

/// Order timeline widget showing status history
class OrderTimeline extends StatelessWidget {
  final OrderModel order;

  const OrderTimeline({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final steps = _buildTimelineSteps();
    final currentIndex = _getCurrentStepIndex();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(
        steps.length,
        (index) => _TimelineStep(
          step: steps[index],
          isFirst: index == 0,
          isLast: index == steps.length - 1,
          isCompleted: index <= currentIndex,
          isCurrent: index == currentIndex,
          stepNumber: index + 1,
        ),
      ),
    );
  }

  // Gap #16: Handle all status values including out_for_delivery and pending_payment
  int _getCurrentStepIndex() {
    if (order.isDeliveryConfirmed) return 5;
    return switch (order.status) {
      'pending' || 'pending_payment' => 0,
      'confirmed' => 1,
      'preparing' || 'processing' => 2,
      'shipped' || 'ready' || 'out_for_delivery' => 3,
      'delivered' => 4,
      'cancelled' || 'refunded' => -1,
      _ => 0,
    };
  }

  DateTime? _getDateForStatus(String status) {
    // Look through statusHistory for this status
    try {
      final found = order.statusHistory.firstWhere(
        (h) => h.status == status,
      );
      return found.timestamp;
    } catch (_) {
      return null;
    }
  }

  List<_TimelineStepData> _buildTimelineSteps() {
    return [
      _TimelineStepData(
        icon: Icons.receipt_long_outlined,
        title: 'Pedido realizado',
        date: order.createdAt,
        description: 'Aguardando confirmação',
      ),
      _TimelineStepData(
        icon: Icons.check_circle_outline,
        title: 'Confirmado',
        date: _getDateForStatus('confirmed'),
        description: 'Pagamento aprovado',
      ),
      _TimelineStepData(
        icon: Icons.inventory_2_outlined,
        title: 'Em preparação',
        date: _getDateForStatus('preparing') ?? _getDateForStatus('processing'),
        description: 'Preparando seu pedido',
      ),
      _TimelineStepData(
        icon: Icons.local_shipping_outlined,
        title: 'Enviado',
        date: _getDateForStatus('shipped') ?? _getDateForStatus('ready'),
        description: 'A caminho',
      ),
      _TimelineStepData(
        icon: Icons.home_outlined,
        title: 'Entregue',
        date: _getDateForStatus('delivered'),
        description: 'Pedido finalizado',
      ),

      // D5: Conditional delivery confirmation step
      if (order.status == 'delivered' || order.isDeliveryConfirmed)
        _TimelineStepData(
          icon: Icons.verified_outlined,
          title: 'Recebimento confirmado',
          date: order.deliveryConfirmedAt,
          description: order.isDeliveryConfirmed
              ? 'Pagamento será liberado em até 24h'
              : 'Aguardando confirmação do comprador',
        ),
    ];
  }
}

class _TimelineStepData {
  final IconData icon;
  final String title;
  final DateTime? date;
  final String description;

  _TimelineStepData({
    required this.icon,
    required this.title,
    this.date,
    required this.description,
  });
}

class _TimelineStep extends StatelessWidget {
  final _TimelineStepData step;
  final bool isFirst;
  final bool isLast;
  final bool isCompleted;
  final bool isCurrent;
  final int stepNumber;

  const _TimelineStep({
    required this.step,
    required this.isFirst,
    required this.isLast,
    required this.isCompleted,
    required this.isCurrent,
    required this.stepNumber,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Connector line colours
    final lineColor = (isCompleted && !isCurrent)
        ? AppColors.primary
        : theme.colorScheme.outline.withAlpha(100);

    // Build the step indicator circle
    Widget stepCircle;

    if (isCompleted && !isCurrent) {
      // Completed steps: filled primary circle with a check mark
      stepCircle = AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check, color: Colors.white, size: 16),
      );
    } else if (isCurrent) {
      // Active step: filled primary circle with step number + pulse shadow
      final circle = AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '$stepNumber',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );

      stepCircle = circle
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .custom(
            duration: 1200.ms,
            curve: Curves.easeInOut,
            builder: (_, value, child) => Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withAlpha((60 * value).round()),
                    blurRadius: 10 * value,
                    spreadRadius: 3 * value,
                  ),
                ],
              ),
              child: child,
            ),
          );
    } else {
      // Future steps: outlined circle with greyed number
      stepCircle = AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: theme.colorScheme.outline.withAlpha(80),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            '$stepNumber',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator column
          SizedBox(
            width: 36,
            child: Column(
              children: [
                // Top connector line
                if (!isFirst)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    width: 2,
                    height: 10,
                    color: lineColor,
                  ),

                stepCircle,

                // Bottom connector line
                if (!isLast)
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      width: 2,
                      color: lineColor,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                top: isFirst ? 4 : 10,
                bottom: isLast ? 0 : 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        step.icon,
                        size: 18,
                        color: isCompleted
                            ? AppColors.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        step.title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                          color: isCompleted
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    step.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (step.date != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      Formatters.dateTime(step.date!),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
