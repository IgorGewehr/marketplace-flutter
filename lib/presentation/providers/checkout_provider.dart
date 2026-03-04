import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/errors/app_exception.dart';
import '../../data/datasources/mp_card_tokenizer.dart';
import '../../data/models/address_model.dart';
import '../../data/models/freight_option_model.dart';
import '../../data/models/order_model.dart';
import '../../data/models/product_model.dart';
import '../../domain/repositories/order_repository.dart';
import '../../domain/repositories/shipping_repository.dart';
import 'address_provider.dart';
import 'auth_providers.dart';
import 'cart_provider.dart';
import 'core_providers.dart';
import 'mercadopago_provider.dart';
import 'orders_provider.dart';

/// Checkout step enum
enum CheckoutStep {
  address,
  delivery,
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
  final String? cardBin; // First 6 digits of the card (BIN) for installments query
  final int installments;

  // Customer notes for the order
  final String? customerNotes;

  // 3DS challenge URL
  final String? threeDsUrl;

  // Delivery / freight fields
  final List<FreightOptionModel>? freightOptions;
  final FreightOptionModel? selectedFreightOption;
  final bool isCalculatingFreight;
  final String? freightError;
  final String? freeDeliveryMessage;
  final bool hasMixedCart;
  final int pickupOnlyCount;

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
    this.cardBin,
    this.installments = 1,
    this.customerNotes,
    this.threeDsUrl,
    this.freightOptions,
    this.selectedFreightOption,
    this.isCalculatingFreight = false,
    this.freightError,
    this.freeDeliveryMessage,
    this.hasMixedCart = false,
    this.pickupOnlyCount = 0,
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
    Object? cardBin = _sentinel,
    int? installments,
    Object? customerNotes = _sentinel,
    Object? threeDsUrl = _sentinel,
    Object? freightOptions = _sentinel,
    Object? selectedFreightOption = _sentinel,
    bool? isCalculatingFreight,
    Object? freightError = _sentinel,
    Object? freeDeliveryMessage = _sentinel,
    bool? hasMixedCart,
    int? pickupOnlyCount,
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
      cardBin: cardBin == _sentinel ? this.cardBin : cardBin as String?,
      installments: installments ?? this.installments,
      customerNotes: customerNotes == _sentinel ? this.customerNotes : customerNotes as String?,
      threeDsUrl: threeDsUrl == _sentinel ? this.threeDsUrl : threeDsUrl as String?,
      freightOptions: freightOptions == _sentinel ? this.freightOptions : freightOptions as List<FreightOptionModel>?,
      selectedFreightOption: selectedFreightOption == _sentinel ? this.selectedFreightOption : selectedFreightOption as FreightOptionModel?,
      isCalculatingFreight: isCalculatingFreight ?? this.isCalculatingFreight,
      freightError: freightError == _sentinel ? this.freightError : freightError as String?,
      freeDeliveryMessage: freeDeliveryMessage == _sentinel ? this.freeDeliveryMessage : freeDeliveryMessage as String?,
      hasMixedCart: hasMixedCart ?? this.hasMixedCart,
      pickupOnlyCount: pickupOnlyCount ?? this.pickupOnlyCount,
    );
  }

  bool get canProceed {
    switch (currentStep) {
      case CheckoutStep.address:
        return selectedAddress != null;
      case CheckoutStep.delivery:
        return selectedFreightOption != null;
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
      paymentMethod == PaymentMethod.creditCard;
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
    final addresses = ref.read(addressProvider).valueOrNull;
    if (addresses != null && addresses.isNotEmpty) {
      final defaultAddress = addresses.where((a) => a.isDefault).firstOrNull ?? addresses.first;
      state = state.copyWith(selectedAddress: defaultAddress);
    }
  }

  void setAddress(AddressModel address) {
    // Reset freight options when address changes
    state = state.copyWith(
      selectedAddress: address,
      freightOptions: null,
      selectedFreightOption: null,
      freightError: null,
      freeDeliveryMessage: null,
    );
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
  void onCardTokenized(String tokenId, {String? bin}) {
    state = state.copyWith(cardTokenId: tokenId, cardBin: bin);
  }

  void setCustomerNotes(String notes) {
    state = state.copyWith(
      customerNotes: notes.trim().isEmpty ? null : notes.trim(),
    );
  }

  void setInstallments(int installments) {
    state = state.copyWith(installments: installments);
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  void goToStep(CheckoutStep step) {
    state = state.copyWith(currentStep: step);
  }

  /// Select a freight option
  void selectFreightOption(FreightOptionModel option) {
    state = state.copyWith(selectedFreightOption: option);
  }

  /// Calculate freight options for the current address
  Future<void> calculateFreight() async {
    if (state.selectedAddress == null) return;

    state = state.copyWith(
      isCalculatingFreight: true,
      freightError: null,
      freightOptions: null,
      selectedFreightOption: null,
    );

    try {
      final shippingRepo = ref.read(shippingRepositoryProvider);
      final cart = ref.read(cartProvider);

      // Extract tenantId from cart
      final tenantId = cart.items.isNotEmpty ? cart.items.first.tenantId : '';

      // Build freight items from cart with product shipping data from cache
      final storage = ref.read(localStorageProvider);
      final freightItems = cart.items.map((item) {
        final cachedJson = storage.getCachedProduct(item.productId);
        final product = cachedJson != null ? ProductModel.fromJson(cachedJson) : null;
        // If product has no weight and requires delivery, log warning
        if (product?.weight == null && product?.shippingPolicy != 'pickup_only') {
          debugPrint('[CheckoutProvider] WARNING: product ${item.productId} has no weight set');
        }
        return FreightItemRequest(
          quantity: item.quantity,
          weight: product?.weight,
          dimensions: product?.dimensions != null
              ? {
                  'width': product!.dimensions!.width,
                  'height': product.dimensions!.height,
                  'length': product.dimensions!.length,
                }
              : null,
          shippingPolicy: product?.shippingPolicy,
        );
      }).toList();

      final result = await shippingRepo.calculateFreight(
        zipCode: state.selectedAddress!.zipCode,
        city: state.selectedAddress!.city,
        subtotal: cart.subtotal,
        items: freightItems,
        tenantId: tenantId,
      );

      // Auto-select the cheapest available option
      FreightOptionModel? autoSelected;
      final availableOptions = result.options.where((o) => o.available).toList();
      if (availableOptions.isNotEmpty) {
        availableOptions.sort((a, b) => a.price.compareTo(b.price));
        autoSelected = availableOptions.first;
      }

      state = state.copyWith(
        isCalculatingFreight: false,
        freightOptions: result.options,
        selectedFreightOption: autoSelected,
        freeDeliveryMessage: result.freeDeliveryMessage,
        hasMixedCart: result.hasMixedCart,
        pickupOnlyCount: result.pickupOnlyCount,
      );
    } catch (e) {
      state = state.copyWith(
        isCalculatingFreight: false,
        freightError: 'Erro ao calcular frete. Tente novamente.',
      );
    }
  }

  void nextStep() {
    final current = state.currentStep;

    if (current == CheckoutStep.address) {
      // After address → always go to delivery step (calculate freight)
      state = state.copyWith(currentStep: CheckoutStep.delivery);
      calculateFreight();
      return;
    }

    if (current == CheckoutStep.delivery) {
      state = state.copyWith(currentStep: CheckoutStep.payment);
      return;
    }

    // Skip cardDetails step if payment method doesn't require it
    if (current == CheckoutStep.payment && !state.requiresCardDetails) {
      state = state.copyWith(currentStep: CheckoutStep.review);
      return;
    }

    final currentIndex = CheckoutStep.values.indexOf(current);
    if (currentIndex < CheckoutStep.values.length - 1) {
      state = state.copyWith(
          currentStep: CheckoutStep.values[currentIndex + 1]);
    }
  }

  void previousStep() {
    final current = state.currentStep;

    if (current == CheckoutStep.payment) {
      // Always go back to delivery step
      state = state.copyWith(currentStep: CheckoutStep.delivery);
      return;
    }

    // Skip cardDetails step going back if payment method doesn't require it
    if (current == CheckoutStep.review && !state.requiresCardDetails) {
      state = state.copyWith(currentStep: CheckoutStep.payment);
      return;
    }

    final currentIndex = CheckoutStep.values.indexOf(current);
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

      // SDK is only needed for card tokenization — don't surface failures
      // to the user here, as PIX doesn't need it. Card form handles its own errors.
      if (publicKey.isEmpty) return;

      await MpCardTokenizer.initialize(publicKey);
    } catch (_) {
      // Silent failure: SDK init errors are irrelevant for PIX payments.
      // CardPaymentForm will catch and surface errors during card tokenization.
    }
  }

  /// Create order and process payment
  Future<bool> placeOrder() async {
    if (!state.canProceed || state.isLoading) return false;

    final previousStep = state.currentStep;

    // Pre-validate CPF for PIX payments.
    if (state.paymentMethod == PaymentMethod.pix) {
      try {
        final user = await ref.read(currentUserProvider.future);
        if (user != null) {
          final cpfDigits = (user.cpfCnpj ?? '').replaceAll(RegExp(r'\D'), '');
          if (cpfDigits.length < 11) {
            state = state.copyWith(
              error: 'Para pagar via PIX é necessário ter CPF cadastrado. Adicione seu CPF no perfil antes de continuar.',
              currentStep: previousStep,
            );
            return false;
          }
        }
      } catch (_) {
        // Can't read user data — let the backend perform the authoritative check.
      }
    }

    state = state.copyWith(isLoading: true, currentStep: CheckoutStep.processing);

    try {
      // Force-sync the local cart with Firestore before placing the order.
      final synced = await ref.read(cartProvider.notifier).ensureSynced();
      if (!synced) {
        state = state.copyWith(
          isLoading: false,
          error: 'Não foi possível sincronizar o carrinho. Verifique sua conexão e tente novamente.',
          currentStep: previousStep,
        );
        return false;
      }

      final orderRepo = ref.read(orderRepositoryProvider);

      // Determine delivery type based on selected freight option
      final freightOption = state.selectedFreightOption;
      final String deliveryType;
      if (freightOption?.tier == 'pickup_point') {
        deliveryType = 'pickup';
      } else if (freightOption?.tier == 'seller_arranges') {
        deliveryType = 'seller_arranges';
      } else {
        deliveryType = 'delivery';
      }

      // Create order via API using CreateOrderRequest
      final request = CreateOrderRequest(
        deliveryType: deliveryType,
        deliveryAddress: state.selectedAddress,
        paymentMethod: state.paymentMethod!.name,
        cardTokenId: state.cardTokenId,
        installments: state.installments,
        customerNotes: state.customerNotes,
        deliveryTier: freightOption?.tier,
        deliveryZoneId: freightOption?.zoneId,
        pickupPointId: freightOption?.pickupPointId,
        deliveryFeeFromClient: freightOption?.price,
      );

      final order = await orderRepo.create(request);

      // Handle 3DS challenge
      if (order.paymentStatus == 'pending_challenge') {
        state = state.copyWith(
          createdOrder: order,
          isLoading: false,
          currentStep: CheckoutStep.processing,
          threeDsUrl: order.threeDsUrl,
        );
        return true;
      }

      // Invalidate orders list so the buyer sees the new order immediately
      ref.invalidate(ordersProvider);

      // Handle PIX payment - populate PIX data from order response
      if (state.paymentMethod == PaymentMethod.pix) {
        state = state.copyWith(
          createdOrder: order,
          pixCode: order.pixCode,
          pixQrCode: order.pixQrCodeUrl,
          pixExpiration: order.pixExpiration ?? DateTime.now().add(const Duration(minutes: 15)),
          isLoading: false,
        );
        // Don't clear cart yet — wait until PIX payment is confirmed
      } else {
        state = state.copyWith(
          createdOrder: order,
          isLoading: false,
          currentStep: CheckoutStep.complete,
        );
        // Clear cart immediately for non-PIX (card is processed instantly)
        ref.read(cartProvider.notifier).clearCart();
      }

      return true;
    } catch (e) {
      _notifySellerViaChat(e);
      final errorMessage = _userFriendlyError(e);
      state = state.copyWith(
        isLoading: false,
        error: errorMessage,
        currentStep: previousStep,
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
        // PIX confirmed — now safe to clear cart
        ref.read(cartProvider.notifier).clearCart();
        // Refresh orders list so the buyer sees the updated payment status
        ref.invalidate(ordersProvider);
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

  /// Fire-and-forget: auto-sends a chat message to the seller when the
  /// checkout fails due to seller-side configuration issues.
  void _notifySellerViaChat(Object error) {
    try {
      // Detect error code from ApiException.responseData or fallback to string matching
      String? code;
      if (error is ApiException) {
        code = error.responseData?['code'] as String?;
      }
      final msg = error.toString().toLowerCase();

      String? chatMessage;
      String? errorType;
      if (code == 'SELLER_PIX_NOT_ENABLED' ||
          msg.contains('seller_pix_not_enabled') ||
          msg.contains('key enabled for qr')) {
        errorType = 'pix_not_enabled';
        chatMessage =
            'Olá! Tentei comprar um produto da sua loja via PIX, mas não '
            'consegui finalizar. Parece que o recebimento via PIX ainda não '
            'está habilitado na sua conta do Mercado Pago. Poderia verificar '
            'se você tem uma chave PIX cadastrada? Obrigado!';
      } else if (code == 'SELLER_NOT_CONNECTED' ||
          msg.contains('seller_not_connected') ||
          msg.contains('não conectou') ||
          msg.contains('nao conectou')) {
        errorType = 'not_connected';
        chatMessage =
            'Olá! Tentei comprar um produto da sua loja, mas não consegui '
            'finalizar o pagamento porque sua conta do Mercado Pago ainda '
            'não está conectada. Poderia verificar? Obrigado!';
      }

      if (chatMessage == null || errorType == null) return;

      // Get tenantId from cart items
      final cartItems = ref.read(cartProvider).items;
      if (cartItems.isEmpty) return;
      final tenantId = cartItems.first.tenantId;
      if (tenantId.isEmpty) return;

      // Dedup: check if we already notified this tenant about this error
      final localStorage = ref.read(localStorageProvider);
      final dedupKey = 'seller_notified_${tenantId}_$errorType';
      if (localStorage.getBool(dedupKey) == true) return;

      // Mark as notified before sending (prevents duplicates on rapid retries)
      localStorage.setBool(dedupKey, true);

      // Fire-and-forget — startChat + sendMessage
      final chatRepo = ref.read(chatRepositoryProvider);
      chatRepo.startChat(tenantId: tenantId).then((chat) {
        chatRepo.sendMessage(chatId: chat.id, text: chatMessage!);
      }).catchError((_) {
        // Silently ignore — never affect buyer flow
      });
    } catch (_) {
      // Silently ignore any error
    }
  }

  /// Convert exception to user-friendly message
  String _userFriendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('missing_identification') ||
        msg.contains('cpf cadastrado') ||
        msg.contains('cpf obrigat')) {
      return 'Para pagar via PIX é necessário ter CPF cadastrado. Acesse seu perfil e adicione seu CPF antes de continuar.';
    }
    if (msg.contains('seller_not_connected') ||
        msg.contains('não conectou') ||
        msg.contains('nao conectou') ||
        msg.contains('não configurou')) {
      return 'O vendedor ainda não configurou o recebimento de pagamentos. Tente novamente mais tarde.';
    }
    if (msg.contains('seller_pix_not_enabled') ||
        msg.contains('não habilitou o recebimento via pix') ||
        msg.contains('habilitou o recebimento via pix')) {
      return 'O vendedor ainda não habilitou o recebimento via PIX no Mercado Pago. Tente pagar com cartão de crédito.';
    }
    if (msg.contains('out_of_delivery_area')) {
      return 'Endereço fora da área de entrega. Escolha outro endereço ou selecione retirada.';
    }
    if (msg.contains('invalid_delivery_option') || msg.contains('delivery_unavailable')) {
      return 'Opção de entrega não disponível. Selecione outra opção.';
    }
    if (msg.contains('produto não encontrado') || msg.contains('produto nao encontrado')) {
      return 'Um dos produtos do carrinho não está mais disponível. Atualize seu carrinho.';
    }
    if (msg.contains('carrinho vazio')) {
      return 'Seu carrinho está vazio.';
    }
    if (msg.contains('estoque') || msg.contains('stock')) {
      final original = e.toString();
      final colonIdx = original.indexOf(': ');
      if (colonIdx >= 0) {
        return original.substring(colonIdx + 2);
      }
      return 'Estoque insuficiente para um dos produtos.';
    }
    if (msg.contains('email') && msg.contains('obrigat')) {
      return 'Email é obrigatório para pagamento. Atualize seu perfil.';
    }
    if (msg.contains('dados de pagamento') || msg.contains('dados inv')) {
      return 'Dados de pagamento inválidos. Verifique suas informações e tente novamente.';
    }
    if (msg.contains('timeout') || msg.contains('timed out')) {
      return 'Erro de conexão. Tente novamente.';
    }
    if (msg.contains('network') || msg.contains('socket') || msg.contains('connection')) {
      return 'Erro de conexão. Tente novamente.';
    }
    if (msg.contains('401') || msg.contains('unauthorized')) {
      return 'Sessão expirada. Faça login novamente.';
    }
    if (msg.contains('cc_rejected') || msg.contains('rejected')) {
      return 'Cartão recusado. Verifique os dados ou tente outro cartão.';
    }
    if (msg.contains('insufficient') || msg.contains('saldo')) {
      return 'Saldo insuficiente no cartão.';
    }
    if (msg.contains('invalid_card') || msg.contains('invalid')) {
      return 'Dados do cartão inválidos.';
    }
    if (msg.contains('expired') || msg.contains('expirado')) {
      return 'Cartão expirado.';
    }
    if (msg.contains('pending') || msg.contains('in_process')) {
      return 'Pagamento em análise. Aguarde a confirmação.';
    }
    return 'Erro no pagamento. Tente novamente ou use outro método.';
  }

  /// Reset checkout
  Future<void> reset() async {
    state = const CheckoutState();
    await _loadDefaultAddress();
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
