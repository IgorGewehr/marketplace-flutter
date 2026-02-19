import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/marketplace_constants.dart';
import '../../data/models/product_model.dart';
import 'auth_providers.dart';
import 'core_providers.dart';

/// Local cart item for Hive storage (immutable)
class LocalCartItem {
  final String productId;
  final String productName;
  final String? productImage;
  final double price;
  final String? variant;
  final int quantity;

  const LocalCartItem({
    required this.productId,
    required this.productName,
    this.productImage,
    required this.price,
    this.variant,
    this.quantity = 1,
  });

  LocalCartItem copyWith({int? quantity}) {
    return LocalCartItem(
      productId: productId,
      productName: productName,
      productImage: productImage,
      price: price,
      variant: variant,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'productName': productName,
        'productImage': productImage,
        'price': price,
        'variant': variant,
        'quantity': quantity,
      };

  factory LocalCartItem.fromJson(Map<String, dynamic> json) => LocalCartItem(
        productId: json['productId'] as String,
        productName: json['productName'] as String,
        productImage: json['productImage'] as String?,
        price: (json['price'] as num).toDouble(),
        variant: json['variant'] as String?,
        quantity: json['quantity'] as int? ?? 1,
      );

  double get total => price * quantity;
}

/// Cart state class
class CartState {
  final List<LocalCartItem> items;
  final bool isLoading;
  final String? error;
  final bool isSynced;

  const CartState({
    this.items = const [],
    this.isLoading = false,
    this.error,
    this.isSynced = false,
  });

  CartState copyWith({
    List<LocalCartItem>? items,
    bool? isLoading,
    String? error,
    bool? isSynced,
  }) {
    return CartState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  double get subtotal => items.fold(0, (sum, item) => sum + item.total);
  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);
  bool get isEmpty => items.isEmpty;
}

/// Cart notifier with local storage and remote sync
class CartNotifier extends Notifier<CartState> {
  @override
  CartState build() {
    // Load synchronously from Hive (Hive reads are sync)
    try {
      final storage = ref.read(localStorageProvider);
      final stored = storage.loadCartItems();

      if (stored != null) {
        final items = stored
            .map((e) => LocalCartItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        return CartState(items: items);
      }
    } catch (_) {
      // Fall through to empty cart on error
    }
    return const CartState();
  }

  Future<void> _saveToLocal() async {
    try {
      final storage = ref.read(localStorageProvider);
      await storage.saveCartItems(state.items.map((e) => e.toJson()).toList());
    } catch (_) {
      // Silently fail for local storage
    }
  }

  /// Add product to cart
  Future<void> addToCart(ProductModel product, {int quantity = 1, String? variant}) async {
    // E2: Block products above checkout price limit
    if (product.price > kCheckoutPriceLimit) {
      state = state.copyWith(
        error: 'Produto acima de R\$ ${kCheckoutPriceLimit.toStringAsFixed(0)} - negocie diretamente com o vendedor',
      );
      return;
    }

    final existingIndex = state.items.indexWhere(
      (item) => item.productId == product.id && item.variant == variant,
    );

    List<LocalCartItem> newItems;
    if (existingIndex >= 0) {
      // Update quantity (immutable)
      newItems = [
        for (int i = 0; i < state.items.length; i++)
          if (i == existingIndex)
            state.items[i].copyWith(quantity: state.items[i].quantity + quantity)
          else
            state.items[i],
      ];
    } else {
      // Add new item
      newItems = [
        ...state.items,
        LocalCartItem(
          productId: product.id,
          productName: product.name,
          productImage: product.mainImageUrl,
          price: product.price,
          variant: variant,
          quantity: quantity,
        ),
      ];
    }

    state = state.copyWith(items: newItems, isSynced: false);
    await _saveToLocal();
    _syncWithRemote();
  }

  /// Remove product from cart
  Future<void> removeFromCart(String productId, {String? variant}) async {
    final newItems = state.items
        .where((item) => !(item.productId == productId && item.variant == variant))
        .toList();

    state = state.copyWith(items: newItems, isSynced: false);
    await _saveToLocal();
    _syncWithRemote();
  }

  /// Update item quantity (immutable)
  Future<void> updateQuantity(String productId, int quantity, {String? variant}) async {
    if (quantity <= 0) {
      return removeFromCart(productId, variant: variant);
    }

    final newItems = [
      for (final item in state.items)
        if (item.productId == productId && item.variant == variant)
          item.copyWith(quantity: quantity)
        else
          item,
    ];

    state = state.copyWith(items: newItems, isSynced: false);
    await _saveToLocal();
    _syncWithRemote();
  }

  /// Clear entire cart
  Future<void> clearCart() async {
    state = state.copyWith(items: [], isSynced: false);
    await _saveToLocal();
    _syncWithRemote();
  }

  /// Sync with remote API (only when logged in)
  Future<void> _syncWithRemote() async {
    final isAuthenticated = ref.read(isAuthenticatedProvider);
    if (!isAuthenticated) return;

    try {
      final cartRepo = ref.read(cartRepositoryProvider);

      // Get current remote cart
      final remoteCart = await cartRepo.getCart();

      // Gap #24: Use a separator that won't appear in IDs
      const sep = '|||';

      // Build map of remote items for quick lookup
      final remoteItemsMap = <String, int>{};
      for (final remoteItem in remoteCart.items) {
        final key = '${remoteItem.productId}$sep${remoteItem.variantId ?? ''}';
        remoteItemsMap[key] = remoteItem.quantity;
      }

      // Process local items - add or update
      for (final localItem in state.items) {
        final key = '${localItem.productId}$sep${localItem.variant ?? ''}';
        final remoteQuantity = remoteItemsMap[key];

        if (remoteQuantity == null) {
          // Item not in remote cart - add it
          await cartRepo.addItem(
            productId: localItem.productId,
            variantId: localItem.variant,
            quantity: localItem.quantity,
          );
        } else if (remoteQuantity != localItem.quantity) {
          // Item exists but quantity differs - update it
          final remoteItem = remoteCart.items.firstWhere(
            (item) => item.productId == localItem.productId && item.variantId == localItem.variant,
          );
          await cartRepo.updateItemQuantity(
            itemId: remoteItem.id,
            quantity: localItem.quantity,
          );
        }

        remoteItemsMap.remove(key);
      }

      // Remove items that exist remotely but not locally
      for (final remoteKey in remoteItemsMap.keys) {
        final parts = remoteKey.split(sep);
        final productId = parts[0];
        final variantId = parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null;

        final remoteItem = remoteCart.items.firstWhere(
          (item) => item.productId == productId && item.variantId == variantId,
        );
        await cartRepo.removeItem(remoteItem.id);
      }

      state = state.copyWith(isSynced: true);
    } catch (_) {
      // Sync failed, will retry on next cart change
    }
  }

  /// Pull remote cart (after login)
  Future<void> pullRemoteCart() async {
    try {
      state = state.copyWith(isLoading: true);

      final cartRepo = ref.read(cartRepositoryProvider);
      final remoteCart = await cartRepo.getCart();

      if (remoteCart.items.isNotEmpty) {
        final localItems = state.items;
        final mergedItems = <LocalCartItem>[];

        // Add remote items
        for (final remoteItem in remoteCart.items) {
          mergedItems.add(LocalCartItem(
            productId: remoteItem.productId,
            productName: remoteItem.name,
            productImage: remoteItem.imageUrl,
            price: remoteItem.unitPrice,
            quantity: remoteItem.quantity,
          ));
        }

        // Add local-only items
        for (final localItem in localItems) {
          if (!mergedItems.any((m) => m.productId == localItem.productId)) {
            mergedItems.add(localItem);
          }
        }

        state = state.copyWith(items: mergedItems, isLoading: false, isSynced: true);
        await _saveToLocal();
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

/// Cart provider
final cartProvider = NotifierProvider<CartNotifier, CartState>(CartNotifier.new);

/// Cart item count provider
final cartItemCountProvider = Provider<int>((ref) {
  return ref.watch(cartProvider).itemCount;
});

/// Cart subtotal provider
final cartSubtotalProvider = Provider<double>((ref) {
  return ref.watch(cartProvider).subtotal;
});

/// Cart total provider (no shipping - platform doesn't handle delivery)
final cartTotalProvider = Provider<double>((ref) {
  return ref.watch(cartSubtotalProvider);
});
