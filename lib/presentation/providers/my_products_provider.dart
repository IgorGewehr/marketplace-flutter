import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/product_model.dart';
import '../../domain/repositories/product_repository.dart';
import 'auth_providers.dart';
import 'core_providers.dart';

/// Filter options for my products
enum MyProductsFilter { all, active, paused, outOfStock }

/// Search query for my products
final myProductsSearchProvider = StateProvider<String>((ref) => '');

/// Filter state for my products
final myProductsFilterProvider = StateProvider<MyProductsFilter>((ref) => MyProductsFilter.all);

/// Provider for seller's own products
final myProductsProvider = AsyncNotifierProvider<MyProductsNotifier, List<ProductModel>>(() {
  return MyProductsNotifier();
});

/// Filtered products based on search and filter
final filteredMyProductsProvider = Provider<AsyncValue<List<ProductModel>>>((ref) {
  final productsAsync = ref.watch(myProductsProvider);
  final search = ref.watch(myProductsSearchProvider).toLowerCase();
  final filter = ref.watch(myProductsFilterProvider);

  return productsAsync.whenData((products) {
    var filtered = products;

    // Apply search filter
    if (search.isNotEmpty) {
      filtered = filtered.where((p) => p.name.toLowerCase().contains(search)).toList();
    }

    // Apply status filter
    switch (filter) {
      case MyProductsFilter.active:
        filtered = filtered.where((p) => p.status == 'active').toList();
        break;
      case MyProductsFilter.paused:
        filtered = filtered.where((p) => p.status == 'draft').toList();
        break;
      case MyProductsFilter.outOfStock:
        filtered = filtered.where((p) => p.status == 'active' && _isOutOfStock(p)).toList();
        break;
      case MyProductsFilter.all:
        break;
    }

    return filtered;
  });
});

bool _isOutOfStock(ProductModel product) {
  if (!product.trackInventory) return false;
  if (product.hasVariants) {
    return product.variants.every((v) => (v.quantity ?? 0) <= 0);
  }
  return (product.quantity ?? 0) <= 0;
}

class MyProductsNotifier extends AsyncNotifier<List<ProductModel>> {
  @override
  Future<List<ProductModel>> build() async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null || !user.isSeller) return [];

    try {
      final repo = ref.read(productRepositoryProvider);
      final response = await repo.getSellerProducts();
      return response.products;
    } catch (e) {
      return [];
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => build());
  }

  Future<void> createProduct(ProductModel product) async {
    state = await AsyncValue.guard(() async {
      final current = state.valueOrNull ?? [];
      final repo = ref.read(productRepositoryProvider);
      final created = await repo.create(CreateProductRequest(
        name: product.name,
        description: product.description,
        categoryId: product.categoryId,
        price: product.price,
        compareAtPrice: product.compareAtPrice,
        visibility: product.visibility,
      ));
      return [...current, created];
    });
  }

  Future<void> updateProduct(ProductModel product) async {
    state = await AsyncValue.guard(() async {
      final current = state.valueOrNull ?? [];
      final repo = ref.read(productRepositoryProvider);
      final updated = await repo.update(product.id, UpdateProductRequest(
        name: product.name,
        description: product.description,
        categoryId: product.categoryId,
        price: product.price,
        compareAtPrice: product.compareAtPrice,
        visibility: product.visibility,
        status: product.status,
      ));
      return current.map((p) => p.id == product.id ? updated : p).toList();
    });
  }

  Future<void> toggleProductStatus(String productId) async {
    state = await AsyncValue.guard(() async {
      final current = state.valueOrNull ?? [];
      final product = current.firstWhere((p) => p.id == productId);
      final newStatus = product.status == 'active' ? 'draft' : 'active';

      final repo = ref.read(productRepositoryProvider);
      final updated = await repo.update(productId, UpdateProductRequest(status: newStatus));
      return current.map((p) => p.id == productId ? updated : p).toList();
    });
  }

  Future<void> deleteProduct(String productId) async {
    state = await AsyncValue.guard(() async {
      final current = state.valueOrNull ?? [];
      final repo = ref.read(productRepositoryProvider);
      await repo.delete(productId);
      return current.where((p) => p.id != productId).toList();
    });
  }
}
