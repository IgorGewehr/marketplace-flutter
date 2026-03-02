import 'package:flutter/material.dart';

import '../../providers/checkout_provider.dart';

/// Checkout stepper indicator widget with animated transitions
class CheckoutStepper extends StatelessWidget {
  final CheckoutStep currentStep;

  const CheckoutStepper({super.key, required this.currentStep});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Build steps dynamically - include cardDetails only when active
    final steps = [
      _StepData(CheckoutStep.address, 'Endereço', Icons.location_on_outlined),
      _StepData(CheckoutStep.delivery, 'Entrega', Icons.local_shipping_outlined),
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
            // Animated connector line with fill effect
            final stepIndex = (index - 1) ~/ 2;
            final isCompleted = stepIndex < currentIndex;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Stack(
                  children: [
                    // Background track
                    Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.outline.withAlpha(40),
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                    // Animated fill
                    AnimatedFractionallySizedBox(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                      widthFactor: isCompleted ? 1.0 : 0.0,
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      ),
                    ),
                  ],
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

/// Animated fractionally sized box for progress line fill
class AnimatedFractionallySizedBox extends ImplicitlyAnimatedWidget {
  final double widthFactor;
  final Widget child;

  const AnimatedFractionallySizedBox({
    super.key,
    required super.duration,
    super.curve,
    required this.widthFactor,
    required this.child,
  });

  @override
  AnimatedFractionallySizedBoxState createState() =>
      AnimatedFractionallySizedBoxState();
}

class AnimatedFractionallySizedBoxState
    extends AnimatedWidgetBaseState<AnimatedFractionallySizedBox> {
  Tween<double>? _widthFactor;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _widthFactor = visitor(
      _widthFactor,
      widget.widthFactor,
      (dynamic value) => Tween<double>(begin: value as double),
    ) as Tween<double>?;
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: _widthFactor?.evaluate(animation) ?? 0.0,
      child: widget.child,
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
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          width: isActive ? 48 : 44,
          height: isActive ? 48 : 44,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
            border: isActive
                ? Border.all(color: theme.colorScheme.primary, width: 2.5)
                : null,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withAlpha(40),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : isCompleted
                    ? [
                        BoxShadow(
                          color: theme.colorScheme.primary.withAlpha(25),
                          blurRadius: 6,
                        ),
                      ]
                    : null,
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) {
                return ScaleTransition(
                  scale: animation,
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: isCompleted
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 22, key: ValueKey('check'))
                  : Icon(stepData.icon, color: iconColor, size: 20, key: ValueKey(stepData.label)),
            ),
          ),
        ),
        const SizedBox(height: 6),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 250),
          style: theme.textTheme.labelSmall!.copyWith(
            color: isActive || isCompleted
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
            fontSize: isActive ? 11.5 : 11,
          ),
          child: Text(stepData.label),
        ),
      ],
    );
  }
}
