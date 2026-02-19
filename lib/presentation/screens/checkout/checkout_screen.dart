import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/address_model.dart';
import '../../providers/auth_providers.dart';
import '../../providers/cart_provider.dart';
import '../../providers/checkout_provider.dart';
import '../../widgets/card_payment_form.dart';
import '../../widgets/checkout/checkout_stepper.dart';
import '../../widgets/shared/loading_overlay.dart';

/// Checkout screen with multi-step flow
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Validate cart is not empty
      final cart = ref.read(cartProvider);
      if (cart.isEmpty) {
        ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
          const SnackBar(content: Text('Seu carrinho está vazio')),
        );
        context.pop();
        return;
      }
      // Reset checkout when entering
      ref.read(checkoutProvider.notifier).reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final checkoutState = ref.watch(checkoutProvider);
    final cartItems = ref.watch(cartProvider).items;
    final total = ref.watch(cartTotalProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Finalizar Compra'),
        backgroundColor: theme.colorScheme.surface,
      ),
      body: checkoutState.isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  LoadingIndicator(),
                  SizedBox(height: 16),
                  Text('Processando pedido...'),
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
                        final success = await ref.read(checkoutProvider.notifier).placeOrder();
                        if (success && mounted) {
                          final state = ref.read(checkoutProvider);
                          if (state.paymentMethod == PaymentMethod.pix) {
                            context.pushReplacement(AppRouter.pixPayment);
                          } else {
                            context.pushReplacement(AppRouter.orderSuccess);
                          }
                        }
                      } else {
                        ref.read(checkoutProvider.notifier).nextStep();
                      }
                    },
                  ),
              ],
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
    final user = ref.watch(currentUserProvider).valueOrNull;

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

          if (user != null && user.addresses.isNotEmpty)
            ...user.addresses.map((address) => _AddressCard(
                  address: address,
                  isSelected: selectedAddress?.id == address.id,
                  onTap: () {
                    ref.read(checkoutProvider.notifier).setAddress(address);
                  },
                ))
          else
            Container(
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
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: theme.colorScheme.secondary,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Cartão verificado com sucesso!'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Payment info - à vista only
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: theme.colorScheme.primary,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.radio_button_checked,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '1x de ${Formatters.currency(total)} (à vista)',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ] else
            CardPaymentForm(
              onTokenized: (tokenId) {
                ref.read(checkoutProvider.notifier).onCardTokenized(tokenId);
              },
              isLoading: checkoutState.isLoading,
            ),
        ],
      ),
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

          // Address summary
          _ReviewSection(
            title: 'Endereço',
            icon: Icons.location_on_outlined,
            content: state.selectedAddress != null
                ? '${state.selectedAddress!.street}, ${state.selectedAddress!.number}\n'
                    '${state.selectedAddress!.city}/${state.selectedAddress!.state}'
                : 'Não selecionado',
          ),

          // Payment summary
          _ReviewSection(
            title: 'Pagamento',
            icon: Icons.payment_outlined,
            content: _getPaymentMethodLabel(state.paymentMethod),
          ),

          // Items summary
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
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
                              '${item.quantity}x ${item.productName}',
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
          ),

          if (state.error != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.error!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                ],
              ),
            ),
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
      PaymentMethod.debitCard => 'Cartão de Débito',
      PaymentMethod.boleto => 'Boleto',
      null => 'Não selecionado',
    };
  }
}

class _ReviewSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final String content;

  const _ReviewSection({
    required this.title,
    required this.icon,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
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
          Icon(
            Icons.edit_outlined,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
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
