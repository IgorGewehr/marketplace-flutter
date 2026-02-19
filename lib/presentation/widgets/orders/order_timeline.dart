import 'package:flutter/material.dart';

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
        ),
      ),
    );
  }

  int _getCurrentStepIndex() {
    return switch (order.status) {
      'pending' => 0,
      'confirmed' => 1,
      'preparing' || 'processing' => 2,
      'shipped' || 'ready' => 3,
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

  const _TimelineStep({
    required this.step,
    required this.isFirst,
    required this.isLast,
    required this.isCompleted,
    required this.isCurrent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color dotColor;
    Color lineColor;

    if (isCurrent) {
      dotColor = theme.colorScheme.secondary;
      lineColor = theme.colorScheme.outline.withAlpha(50);
    } else if (isCompleted) {
      dotColor = theme.colorScheme.primary;
      lineColor = theme.colorScheme.primary;
    } else {
      dotColor = theme.colorScheme.outline.withAlpha(50);
      lineColor = theme.colorScheme.outline.withAlpha(50);
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline line and dot
          SizedBox(
            width: 32,
            child: Column(
              children: [
                // Top line
                if (!isFirst)
                  Container(
                    width: 2,
                    height: 12,
                    color: lineColor,
                  ),

                // Dot
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                    border: isCurrent
                        ? Border.all(
                            color: theme.colorScheme.secondary.withAlpha(100),
                            width: 4,
                          )
                        : null,
                  ),
                ),

                // Bottom line
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isCompleted && !isCurrent
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline.withAlpha(50),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        step.icon,
                        size: 20,
                        color: isCompleted
                            ? theme.colorScheme.primary
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
