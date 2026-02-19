import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../data/datasources/mp_card_tokenizer.dart';
import '../../data/models/address_model.dart';
import '../../data/models/order_model.dart';
import '../../domain/repositories/order_repository.dart';
import 'auth_providers.dart';
import 'cart_provider.dart';
import 'core_providers.dart';
import 'mercadopago_provider.dart';

/// Checkout step enum
enum CheckoutStep {
  address,
  payment,
  cardDetails,
  review,
  processing,
  complete,
}

/// Payment method enum
enum PaymentMethod {
  pix,
  creditCard,
  debitCard,
  boleto,
}

/// Checkout state
class CheckoutState {
  final CheckoutStep currentStep;
  final AddressModel? selectedAddress;
  final PaymentMethod? paymentMethod;
  final String? cardToken;
  final String? pixCode;
  final String? pixQrCode;
  final DateTime? pixExpiration;
  final OrderModel? createdOrder;
  final bool isLoading;
  final String? error;

  // Card tokenization result (raw card data never stored in state)
  final String? cardTokenId;
  final int installments;

  const CheckoutState({
    this.currentStep = CheckoutStep.address,
    this.selectedAddress,
    this.paymentMethod,
    this.cardToken,
    this.pixCode,
    this.pixQrCode,
    this.pixExpiration,
    this.createdOrder,
    this.isLoading = false,
    this.error,
    this.cardTokenId,
    this.installments = 1,
  });

  static const _sentinel = Object();

  CheckoutState copyWith({
    CheckoutStep? currentStep,
    AddressModel? selectedAddress,
    PaymentMethod? paymentMethod,
    Object? cardToken = _sentinel,
    Object? pixCode = _sentinel,
    Object? pixQrCode = _sentinel,
    Object? pixExpiration = _sentinel,
    Object? createdOrder = _sentinel,
    bool? isLoading,
    String? error,
    Object? cardTokenId = _sentinel,
    int? installments,
  }) {
    return CheckoutState(
      currentStep: currentStep ?? this.currentStep,
      selectedAddress: selectedAddress ?? this.selectedAddress,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      cardToken: cardToken == _sentinel ? this.cardToken : cardToken as String?,
      pixCode: pixCode == _sentinel ? this.pixCode : pixCode as String?,
      pixQrCode: pixQrCode == _sentinel ? this.pixQrCode : pixQrCode as String?,
      pixExpiration: pixExpiration == _sentinel ? this.pixExpiration : pixExpiration as DateTime?,
      createdOrder: createdOrder == _sentinel ? this.createdOrder : createdOrder as OrderModel?,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      cardTokenId: cardTokenId == _sentinel ? this.cardTokenId : cardTokenId as String?,
      installments: installments ?? this.installments,
    );
  }

  bool get canProceed {
    switch (currentStep) {
      case CheckoutStep.address:
        return selectedAddress != null;
      case CheckoutStep.payment:
        return paymentMethod != null;
      case CheckoutStep.cardDetails:
        return cardTokenId != null;
      case CheckoutStep.review:
        return true;
      case CheckoutStep.processing:
        return false;
      case CheckoutStep.complete:
        return true;
    }
  }

  /// Whether card details step should be shown
  bool get requiresCardDetails =>
      paymentMethod == PaymentMethod.creditCard ||
      paymentMethod == PaymentMethod.debitCard;
}

/// Checkout notifier
class CheckoutNotifier extends Notifier<CheckoutState> {
  @override
  CheckoutState build() {
    // Pre-populate with user's default address
    _loadDefaultAddress();
    return const CheckoutState();
  }

  Future<void> _loadDefaultAddress() async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user != null && user.addresses.isNotEmpty) {
      final defaultAddress = user.defaultAddress ?? user.addresses.first;
      state = state.copyWith(selectedAddress: defaultAddress);
    }
  }

  void setAddress(AddressModel address) {
    state = state.copyWith(selectedAddress: address);
  }

  void setPaymentMethod(PaymentMethod method) {
    // Reset card token when changing payment method
    state = state.copyWith(
      paymentMethod: method,
      cardTokenId: null,
    );
  }

  void setCardToken(String token) {
    state = state.copyWith(cardToken: token);
  }

  /// Called when card is tokenized via CardPaymentForm
  void onCardTokenized(String tokenId) {
    state = state.copyWith(cardTokenId: tokenId);
  }

  void setInstallments(int installments) {
    state = state.copyWith(installments: installments);
  }

  void goToStep(CheckoutStep step) {
    state = state.copyWith(currentStep: step);
  }

  void nextStep() {
    final currentIndex = CheckoutStep.values.indexOf(state.currentStep);

    // Skip cardDetails step if payment method doesn't require it
    if (state.currentStep == CheckoutStep.payment &&
        !state.requiresCardDetails) {
      state = state.copyWith(currentStep: CheckoutStep.review);
      return;
    }

    if (currentIndex < CheckoutStep.values.length - 1) {
      state = state.copyWith(
          currentStep: CheckoutStep.values[currentIndex + 1]);
    }
  }

  void previousStep() {
    final currentIndex = CheckoutStep.values.indexOf(state.currentStep);

    // Skip cardDetails step going back if payment method doesn't require it
    if (state.currentStep == CheckoutStep.review &&
        !state.requiresCardDetails) {
      state = state.copyWith(currentStep: CheckoutStep.payment);
      return;
    }

    if (currentIndex > 0) {
      state = state.copyWith(
          currentStep: CheckoutStep.values[currentIndex - 1]);
    }
  }

  /// Initialize MP SDK with public key (call once before tokenizing)
  Future<void> initializeMpSdk() async {
    try {
      // Try to get the public key from the API first
      String publicKey;
      try {
        publicKey = await ref.read(mpPublicKeyProvider.future);
      } catch (_) {
        // Fallback to local config
        publicKey = AppConfig.mpPublicKey;
      }

      if (publicKey.isEmpty) {
        state = state.copyWith(error: 'Chave pública do Mercado Pago não configurada');
        return;
      }

      await MpCardTokenizer.initialize(publicKey);
    } catch (e) {
      state = state.copyWith(error: 'Erro ao inicializar SDK: $e');
    }
  }

  /// Create order and process payment
  Future<bool> placeOrder() async {
    if (!state.canProceed) return false;

    state = state.copyWith(isLoading: true, currentStep: CheckoutStep.processing);

    try {
      final orderRepo = ref.read(orderRepositoryProvider);

      // Create order via API using CreateOrderRequest
      final request = CreateOrderRequest(
        deliveryType: 'delivery',
        deliveryAddress: state.selectedAddress,
        paymentMethod: state.paymentMethod!.name,
        cardTokenId: state.cardTokenId,
        installments: state.installments,
      );

      final order = await orderRepo.create(request);

      // Handle PIX payment - populate PIX data from order response
      if (state.paymentMethod == PaymentMethod.pix) {
        state = state.copyWith(
          createdOrder: order,
          pixCode: order.pixCode,
          pixQrCode: order.pixQrCodeUrl,
          pixExpiration: order.pixExpiration ?? DateTime.now().add(const Duration(minutes: 15)),
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          createdOrder: order,
          isLoading: false,
          currentStep: CheckoutStep.complete,
        );
      }

      // Clear cart
      ref.read(cartProvider.notifier).clearCart();

      return true;
    } catch (e) {
      final errorMessage = _userFriendlyError(e);
      state = state.copyWith(
        isLoading: false,
        error: errorMessage,
        currentStep: CheckoutStep.review,
      );
      return false;
    }
  }

  /// Check PIX payment status
  Future<bool> checkPixPayment() async {
    if (state.createdOrder == null) return false;

    try {
      final orderRepo = ref.read(orderRepositoryProvider);
      final order = await orderRepo.getById(state.createdOrder!.id);

      if (order.paymentStatus == 'paid') {
        state = state.copyWith(
          createdOrder: order,
          currentStep: CheckoutStep.complete,
        );
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Regenerate PIX payment for expired orders by creating a new payment
  Future<bool> regeneratePix() async {
    if (state.createdOrder == null) return false;

    state = state.copyWith(isLoading: true);

    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.post<Map<String, dynamic>>(
        '/api/payments/${state.createdOrder!.id}/regenerate-pix',
      );

      final order = OrderModel.fromJson(response);

      state = state.copyWith(
        createdOrder: order,
        pixCode: order.pixCode,
        pixQrCode: order.pixQrCodeUrl,
        pixExpiration: order.pixExpiration ?? DateTime.now().add(const Duration(minutes: 15)),
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _userFriendlyError(e),
      );
      return false;
    }
  }

  /// Convert exception to user-friendly message
  String _userFriendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('timeout') || msg.contains('timed out')) {
      return 'Servidor demorou para responder. Tente novamente.';
    }
    if (msg.contains('network') || msg.contains('socket') || msg.contains('connection')) {
      return 'Sem conexão com a internet. Verifique sua rede e tente novamente.';
    }
    if (msg.contains('401') || msg.contains('unauthorized')) {
      return 'Sessão expirada. Faça login novamente.';
    }
    if (msg.contains('card') || msg.contains('cartão')) {
      return 'Erro no processamento do cartão. Verifique os dados e tente novamente.';
    }
    if (msg.contains('insufficient') || msg.contains('saldo')) {
      return 'Saldo insuficiente. Tente outra forma de pagamento.';
    }
    return 'Erro ao processar pedido. Tente novamente.';
  }

  /// Reset checkout
  void reset() {
    _loadDefaultAddress();
    state = const CheckoutState();
  }
}

/// Checkout provider
final checkoutProvider = NotifierProvider<CheckoutNotifier, CheckoutState>(
  CheckoutNotifier.new,
);

/// Current checkout step provider
final checkoutStepProvider = Provider<CheckoutStep>((ref) {
  return ref.watch(checkoutProvider).currentStep;
});

/// Can proceed to next step provider
final canProceedCheckoutProvider = Provider<bool>((ref) {
  return ref.watch(checkoutProvider).canProceed;
});
