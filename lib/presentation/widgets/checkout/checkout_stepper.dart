import 'package:flutter/material.dart';

import '../../providers/checkout_provider.dart';

/// Checkout stepper indicator widget
class CheckoutStepper extends StatelessWidget {
  final CheckoutStep currentStep;

  const CheckoutStepper({super.key, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Build steps dynamically - include cardDetails only when active
    final steps = [
      _StepData(CheckoutStep.address, 'Endereço', Icons.location_on_outlined),
      _StepData(CheckoutStep.payment, 'Pagamento', Icons.credit_card_outlined),
      if (currentStep == CheckoutStep.cardDetails)
        _StepData(CheckoutStep.cardDetails, 'Cartão', Icons.credit_score_outlined),
      _StepData(CheckoutStep.review, 'Revisão', Icons.checklist_outlined),
    ];

    final currentIndex = steps.indexWhere((s) => s.step == currentStep);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (index) {
          if (index.isOdd) {
            // Connector line
            final stepIndex = (index - 1) ~/ 2;
            final isCompleted = stepIndex < currentIndex;
            return Expanded(
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline.withAlpha(50),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            );
          } else {
            // Step indicator
            final stepIndex = index ~/ 2;
            final step = steps[stepIndex];
            final isActive = stepIndex == currentIndex;
            final isCompleted = stepIndex < currentIndex;

            return _StepIndicator(
              stepData: step,
              isActive: isActive,
              isCompleted: isCompleted,
              stepNumber: stepIndex + 1,
            );
          }
        }),
      ),
    );
  }
}

class _StepData {
  final CheckoutStep step;
  final String label;
  final IconData icon;

  _StepData(this.step, this.label, this.icon);
}

class _StepIndicator extends StatelessWidget {
  final _StepData stepData;
  final bool isActive;
  final bool isCompleted;
  final int stepNumber;

  const _StepIndicator({
    required this.stepData,
    required this.isActive,
    required this.isCompleted,
    required this.stepNumber,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color backgroundColor;
    Color iconColor;

    if (isCompleted) {
      backgroundColor = theme.colorScheme.primary;
      iconColor = Colors.white;
    } else if (isActive) {
      backgroundColor = theme.colorScheme.primaryContainer;
      iconColor = theme.colorScheme.primary;
    } else {
      backgroundColor = theme.colorScheme.surfaceContainerHighest;
      iconColor = theme.colorScheme.onSurfaceVariant;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
            border: isActive
                ? Border.all(color: theme.colorScheme.primary, width: 2)
                : null,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : Icon(stepData.icon, color: iconColor, size: 20),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          stepData.label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: isActive || isCompleted
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}
