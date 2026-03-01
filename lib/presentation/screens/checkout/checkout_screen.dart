import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/address_model.dart';
import '../../providers/address_provider.dart';
import '../../providers/cart_provider.dart';
import '../../providers/checkout_provider.dart';
import '../../providers/mercadopago_provider.dart';
import '../../providers/products_provider.dart';
import '../../widgets/card_payment_form.dart';
import '../../widgets/checkout/checkout_stepper.dart';
import '../../widgets/shared/app_feedback.dart';
import '../../widgets/shared/loading_overlay.dart';
import '../../widgets/shared/shimmer_loading.dart';

/// Checkout screen with multi-step flow
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  bool _isPlacingOrder = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Validate cart is not empty
      final cart = ref.read(cartProvider);
      if (cart.isEmpty) {
        AppFeedback.showWarning(context, 'Seu carrinho está vazio');
        context.pop();
        return;
      }
      // Reset checkout when entering (await ensures default address is pre-populated)
      await ref.read(checkoutProvider.notifier).reset();
      // Check for items potentially out of stock by re-reading product details
      // This is a best-effort check - the backend will enforce atomically
      final cartItems = ref.read(cartProvider).items;
      for (final item in cartItems) {
        final product = ref.read(productDetailProvider(item.productId)).valueOrNull;
        if (product != null && product.quantity != null && item.quantity > product.quantity!) {
          AppFeedback.showWarning(
            context,
            '${item.productName} tem apenas ${product.quantity} unidade(s) disponível(is). Ajuste a quantidade.',
          );
        }
      }
      // Pre-initialize MP SDK for card payments
      ref.read(checkoutProvider.notifier).initializeMpSdk();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final checkoutState = ref.watch(checkoutProvider);
    final total = ref.watch(cartTotalProvider);

    // Reactive navigation: avoids being stuck on processing spinner
    ref.listen<CheckoutState>(checkoutProvider, (previous, next) {
      if (!mounted) return;
      // PIX: navigate as soon as pixCode is available
      if (next.pixCode != null && previous?.pixCode == null) {
        context.pushReplacement(AppRouter.pixPayment);
      }
      // Card: navigate when order completes
      else if (next.currentStep == CheckoutStep.complete &&
          previous?.currentStep != CheckoutStep.complete) {
        context.pushReplacement(AppRouter.orderSuccess);
      }
    });

    final loadingMessage = checkoutState.paymentMethod == PaymentMethod.pix
        ? 'Gerando seu PIX...'
        : 'Processando pagamento...';

    return PopScope(
      canPop: checkoutState.currentStep == CheckoutStep.address,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          ref.read(checkoutProvider.notifier).previousStep();
        }
      },
      child: Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Finalizar Compra'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (checkoutState.currentStep == CheckoutStep.address) {
              context.pop();
            } else {
              ref.read(checkoutProvider.notifier).previousStep();
            }
          },
        ),
      ),
      body: checkoutState.isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const LoadingIndicator(),
                  const SizedBox(height: 16),
                  Text(loadingMessage),
                ],
              ),
            )
          : Column(
              children: [
                // Step indicator
                CheckoutStepper(currentStep: checkoutState.currentStep),

                const Divider(),

                // Step content
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _buildStepContent(checkoutState),
                  ),
                ),

                // Bottom actions
                if (!checkoutState.isLoading &&
                    checkoutState.currentStep != CheckoutStep.processing &&
                    checkoutState.currentStep != CheckoutStep.complete)
                  _BottomActions(
                    currentStep: checkoutState.currentStep,
                    canProceed: checkoutState.canProceed,
                    total: total,
                    onBack: () {
                      ref.read(checkoutProvider.notifier).previousStep();
                    },
                    onNext: () async {
                      if (checkoutState.currentStep == CheckoutStep.review) {
                        if (_isPlacingOrder) return; // Guard against double-tap
                        HapticFeedback.mediumImpact();
                        setState(() => _isPlacingOrder = true);
                        try {
                          // Navigation is handled reactively by ref.listen above
                          await ref.read(checkoutProvider.notifier).placeOrder();
                        } finally {
                          if (mounted) setState(() => _isPlacingOrder = false);
                        }
                      } else {
                        ref.read(checkoutProvider.notifier).nextStep();
                      }
                    },
                  ),
              ],
            ),
    ),
    );
  }

  Widget _buildStepContent(CheckoutState state) {
    switch (state.currentStep) {
      case CheckoutStep.address:
        return _AddressStep(selectedAddress: state.selectedAddress);
      case CheckoutStep.payment:
        return _PaymentStep(selectedMethod: state.paymentMethod);
      case CheckoutStep.cardDetails:
        return _CardDetailsStep();
      case CheckoutStep.review:
        return _ReviewStep(state: state);
      case CheckoutStep.processing:
      case CheckoutStep.complete:
        return const Center(child: LoadingIndicator());
    }
  }
}

/// Address selection step
class _AddressStep extends ConsumerWidget {
  final AddressModel? selectedAddress;

  const _AddressStep({this.selectedAddress});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final addressesAsync = ref.watch(addressProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Endereço de entrega',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          addressesAsync.when(
            loading: () => const ShimmerLoading(itemCount: 2, isGrid: false, height: 80),
            error: (_, __) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Erro ao carregar endereços'),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => ref.invalidate(addressProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar novamente'),
                ),
              ],
            ),
            data: (addresses) {
              if (addresses.isNotEmpty) {
                return Column(
                  children: addresses.map((address) => _AddressCard(
                    address: address,
                    isSelected: selectedAddress?.id == address.id,
                    onTap: () {
                      ref.read(checkoutProvider.notifier).setAddress(address);
                    },
                  )).toList(),
                );
              }
              return Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.location_off_outlined,
                      size: 48,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    const Text('Nenhum endereço cadastrado'),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () {
                        context.push(AppRouter.addresses);
                      },
                      child: const Text('Adicionar endereço'),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              context.push(AppRouter.addresses);
            },
            icon: const Icon(Icons.add),
            label: const Text('Novo endereço'),
          ),
        ],
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  final AddressModel address;
  final bool isSelected;
  final VoidCallback onTap;

  const _AddressCard({
    required this.address,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withAlpha(30),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (address.label != null)
                    Text(
                      address.label!,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  Text('${address.street}, ${address.number}'),
                  Text(
                    '${address.neighborhood} - ${address.city}/${address.state}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    'CEP: ${address.zipCode}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Payment method selection step
class _PaymentStep extends ConsumerWidget {
  final PaymentMethod? selectedMethod;

  const _PaymentStep({this.selectedMethod});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final total = ref.watch(cartTotalProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Forma de pagamento',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total a pagar',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                Text(
                  Formatters.currency(total),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _PaymentMethodCard(
            method: PaymentMethod.pix,
            icon: Icons.pix,
            title: 'PIX',
            subtitle: 'Aprovação instantânea',
            isSelected: selectedMethod == PaymentMethod.pix,
            onTap: () {
              ref.read(checkoutProvider.notifier).setPaymentMethod(PaymentMethod.pix);
            },
          ),
          if (selectedMethod == PaymentMethod.pix)
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 12),
              child: Text(
                'O pagamento PIX expira em 15 minutos',
                style: TextStyle(fontSize: 12, color: Colors.orange[700]),
              ),
            ),

          _PaymentMethodCard(
            method: PaymentMethod.creditCard,
            icon: Icons.credit_card,
            title: 'Cartão de Crédito',
            subtitle: 'Em até 12x',
            isSelected: selectedMethod == PaymentMethod.creditCard,
            onTap: () {
              ref.read(checkoutProvider.notifier).setPaymentMethod(PaymentMethod.creditCard);
            },
          ),

          // Boleto removido - não disponível na plataforma
        ],
      ),
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  final PaymentMethod method;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _PaymentMethodCard({
    required this.method,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withAlpha(30),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// Card details step (Mercado Pago tokenization)
class _CardDetailsStep extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final checkoutState = ref.watch(checkoutProvider);
    final total = ref.watch(cartTotalProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (checkoutState.cardTokenId != null) ...[
            // Success badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withAlpha(20),
                    AppColors.primaryLight.withAlpha(15),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withAlpha(60)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(30),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cartão verificado',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        Text(
                          'Agora escolha o parcelamento',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 350.ms).slideY(begin: -0.1),
            const SizedBox(height: 24),

            // Installment selector for credit card
            if (checkoutState.paymentMethod == PaymentMethod.creditCard) ...[
              Text(
                'Parcelas',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  final bin = checkoutState.cardBin ?? '';
                  if (bin.length < 6) {
                    return _InstallmentsList(
                      options: List.generate(12, (i) {
                        final n = i + 1;
                        return _InstallmentOption(
                          installments: n,
                          amount: total / n,
                          totalAmount: total,
                          interestFree: true,
                        );
                      }),
                      selectedInstallments: checkoutState.installments,
                      onSelected: (value) {
                        ref.read(checkoutProvider.notifier).setInstallments(value);
                      },
                    );
                  }

                  final installmentsAsync = ref.watch(
                    installmentOptionsProvider(
                      InstallmentsParams(amount: total, bin: bin),
                    ),
                  );

                  return installmentsAsync.when(
                    loading: () => Column(
                      children: List.generate(3, (i) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        height: 64,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                          borderRadius: BorderRadius.circular(14),
                        ),
                      )).animate(interval: 100.ms).fadeIn().shimmer(duration: 800.ms),
                    ),
                    error: (_, __) => _InstallmentsList(
                      options: List.generate(12, (i) {
                        final n = i + 1;
                        return _InstallmentOption(
                          installments: n,
                          amount: total / n,
                          totalAmount: total,
                          interestFree: true,
                        );
                      }),
                      selectedInstallments: checkoutState.installments,
                      onSelected: (value) {
                        ref.read(checkoutProvider.notifier).setInstallments(value);
                      },
                    ),
                    data: (options) {
                      final validOption = options.any((o) => o.installments == checkoutState.installments);
                      if (!validOption && options.isNotEmpty) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          ref.read(checkoutProvider.notifier).setInstallments(1);
                          if (context.mounted) {
                            AppFeedback.showInfo(context, 'Parcelamento ajustado. Selecione o número de parcelas.');
                          }
                        });
                      }
                      return _InstallmentsList(
                        options: options.map((o) => _InstallmentOption(
                          installments: o.installments,
                          amount: o.installmentAmount,
                          totalAmount: o.totalAmount,
                          interestFree: o.interestFree,
                          label: o.recommendedMessage,
                        )).toList(),
                        selectedInstallments: validOption ? checkoutState.installments : 1,
                        onSelected: (value) {
                          ref.read(checkoutProvider.notifier).setInstallments(value);
                        },
                      );
                    },
                  );
                },
              ),
            ],
          ] else
            CardPaymentForm(
              onTokenized: (tokenId, {String? bin}) {
                ref.read(checkoutProvider.notifier).onCardTokenized(tokenId, bin: bin);
              },
              isLoading: checkoutState.isLoading,
            ),
        ],
      ),
    );
  }
}

/// Data class for installment option display
class _InstallmentOption {
  final int installments;
  final double amount;
  final double totalAmount;
  final bool interestFree;
  final String? label;

  const _InstallmentOption({
    required this.installments,
    required this.amount,
    required this.totalAmount,
    required this.interestFree,
    this.label,
  });
}

/// Modern installments list replacing DropdownButtonFormField
class _InstallmentsList extends StatelessWidget {
  final List<_InstallmentOption> options;
  final int selectedInstallments;
  final ValueChanged<int> onSelected;

  const _InstallmentsList({
    required this.options,
    required this.selectedInstallments,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: options.map((option) {
        final isSelected = option.installments == selectedInstallments;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onSelected(option.installments);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withAlpha(12)
                  : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : theme.colorScheme.outline.withAlpha(40),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                // Selection indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : theme.colorScheme.outline.withAlpha(80),
                      width: isSelected ? 0 : 1.5,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 14),

                // Installment info
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        '${option.installments}x',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isSelected ? AppColors.primaryDark : null,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'de ${Formatters.currency(option.amount)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isSelected
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                // Badge
                if (option.interestFree && option.installments > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'sem juros',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else if (!option.interestFree)
                  Text(
                    Formatters.currency(option.totalAmount),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error.withAlpha(180),
                      fontWeight: FontWeight.w500,
                    ),
                  )
                else if (option.installments == 1)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withAlpha(60),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'à vista',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Review step
class _ReviewStep extends ConsumerWidget {
  final CheckoutState state;

  const _ReviewStep({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cartItems = ref.watch(cartProvider).items;
    final subtotal = ref.watch(cartSubtotalProvider);
    final total = ref.watch(cartTotalProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Revise seu pedido',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          if (state.error != null && state.error!.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.error!,
                          style: TextStyle(color: theme.colorScheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                  if (state.error!.toLowerCase().contains('cpf')) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await context.push(AppRouter.editProfile);
                        // Clear the CPF error so the user can retry without
                        // having to dismiss the banner manually.
                        if (context.mounted) {
                          ref.read(checkoutProvider.notifier).clearError();
                        }
                      },
                      icon: const Icon(Icons.badge_outlined, size: 18),
                      label: const Text('Adicionar CPF no perfil'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.onErrorContainer,
                        side: BorderSide(color: theme.colorScheme.onErrorContainer),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ],
              ),
            ),

          // Address summary
          _ReviewSection(
            title: 'Endereço',
            icon: Icons.location_on_outlined,
            content: state.selectedAddress != null
                ? '${state.selectedAddress!.street}, ${state.selectedAddress!.number}\n'
                    '${state.selectedAddress!.city}/${state.selectedAddress!.state}'
                : 'Não selecionado',
            onEdit: () => ref.read(checkoutProvider.notifier).goToStep(CheckoutStep.address),
          ).animate().fadeIn(delay: 100.ms, duration: 350.ms).slideY(begin: 0.1, curve: Curves.easeOut),

          // Payment summary
          _ReviewSection(
            title: 'Pagamento',
            icon: state.paymentMethod == PaymentMethod.pix
                ? Icons.pix
                : Icons.credit_card_outlined,
            content: _getPaymentMethodLabel(state.paymentMethod),
            onEdit: () => ref.read(checkoutProvider.notifier).goToStep(CheckoutStep.payment),
          ).animate().fadeIn(delay: 200.ms, duration: 350.ms).slideY(begin: 0.1, curve: Curves.easeOut),

          // Items summary
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.colorScheme.outline.withAlpha(30)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Itens (${cartItems.length})',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                ...cartItems.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              '${item.quantity}x ${item.productName}${item.variant != null ? ' - ${item.variant}' : ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(Formatters.currency(item.total)),
                        ],
                      ),
                    )),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Subtotal'),
                    Text(Formatters.currency(subtotal)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      Formatters.currency(total),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(delay: 300.ms, duration: 350.ms).slideY(begin: 0.1, curve: Curves.easeOut),

          // Customer notes field
          const SizedBox(height: 8),
          TextField(
            decoration: InputDecoration(
              labelText: 'Observações para o vendedor (opcional)',
              hintText: 'Ex: Deixar na portaria, cor preferida...',
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.note_outlined),
            ),
            maxLines: 2,
            maxLength: 200,
            onChanged: (value) {
              ref.read(checkoutProvider.notifier).setCustomerNotes(value);
            },
          ).animate().fadeIn(delay: 400.ms, duration: 350.ms),
          const SizedBox(height: 8),

        ],
      ),
    );
  }

  String _getPaymentMethodLabel(PaymentMethod? method) {
    final installments = state.installments;
    final suffix = method == PaymentMethod.creditCard && installments > 1
        ? ' (${installments}x)'
        : '';
    return switch (method) {
      PaymentMethod.pix => 'PIX',
      PaymentMethod.creditCard => 'Cartão de Crédito$suffix',
      null => 'Não selecionado',
    };
  }
}

class _ReviewSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final String content;
  final VoidCallback? onEdit;

  const _ReviewSection({
    required this.title,
    required this.icon,
    required this.content,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outline.withAlpha(30),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: theme.colorScheme.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    content,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (onEdit != null)
              Icon(
                Icons.edit_outlined,
                size: 20,
                color: theme.colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}

/// Bottom action buttons
class _BottomActions extends StatelessWidget {
  final CheckoutStep currentStep;
  final bool canProceed;
  final double total;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _BottomActions({
    required this.currentStep,
    required this.canProceed,
    required this.total,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            if (currentStep != CheckoutStep.address)
              Expanded(
                child: OutlinedButton(
                  onPressed: onBack,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Voltar'),
                ),
              ),
            if (currentStep != CheckoutStep.address) const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: canProceed ? onNext : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  currentStep == CheckoutStep.review
                      ? 'Confirmar ${Formatters.currency(total)}'
                      : 'Continuar',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
