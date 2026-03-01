import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/product_model.dart';
import '../../domain/repositories/product_repository.dart';
import 'auth_providers.dart';
import 'core_providers.dart';

/// Filter options for my products
enum MyProductsFilter { all, active, paused, outOfStock }

/// Search query for my products.
/// autoDispose so the search resets when the user leaves the Products tab.
final myProductsSearchProvider = StateProvider.autoDispose<String>((ref) => '');

/// Filter state for my products.
/// autoDispose so the filter resets to [all] when the user leaves the Products tab,
/// preventing a stale filter (e.g. "Sem estoque") showing an empty list on re-entry.
final myProductsFilterProvider =
    StateProvider.autoDispose<MyProductsFilter>((ref) => MyProductsFilter.all);

/// Provider for seller's own products
final myProductsProvider = AsyncNotifierProvider<MyProductsNotifier, List<ProductModel>>(() {
  return MyProductsNotifier();
});

/// Filtered products based on search and filter.
/// autoDispose so that when the screen is unmounted the derived state is
/// cleaned up along with the filter/search providers it depends on.
/// Uses [skipLoadingOnRefresh] so that while the list is refreshing in the
/// background the PREVIOUS cards stay visible instead of being replaced by
/// skeleton loaders.
final filteredMyProductsProvider =
    Provider.autoDispose<AsyncValue<List<ProductModel>>>((ref) {
  final productsAsync = ref.watch(myProductsProvider);
  final search = ref.watch(myProductsSearchProvider).toLowerCase();
  final filter = ref.watch(myProductsFilterProvider);

  return productsAsync.when<AsyncValue<List<ProductModel>>>(
    // Keep showing previous cards while a background refresh runs.
    skipLoadingOnRefresh: true,
    // Fresh load (no previous data): show loading indicator.
    skipLoadingOnReload: false,
    data: (products) {
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

      return AsyncData(filtered);
    },
    loading: () => const AsyncLoading<List<ProductModel>>(),
    error: (err, stack) => AsyncError<List<ProductModel>>(err, stack),
  );
});

bool _isOutOfStock(ProductModel product) {
  if (!product.trackInventory) return false;
  if (product.hasVariants) {
    return product.variants.every((v) => (v.quantity ?? 0) <= 0);
  }
  return product.quantity <= 0;
}

class MyProductsNotifier extends AsyncNotifier<List<ProductModel>> {
  @override
  Future<List<ProductModel>> build() async {
    // Wait for the user to be fully loaded before querying products.
    // Using .future avoids the premature empty-list return that occurred when
    // currentUserProvider was still loading (valueOrNull == null).
    final user = await ref.watch(currentUserProvider.future);
    if (user == null || !user.isSeller) return [];

    final repo = ref.read(productRepositoryProvider);
    final response = await repo.getSellerProducts();
    return response.products;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = ref.read(currentUserProvider).valueOrNull;
      if (user == null || !user.isSeller) return [];
      final repo = ref.read(productRepositoryProvider);
      final response = await repo.getSellerProducts();
      return response.products;
    });
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
        images: product.images.isNotEmpty ? product.images : null,
        tags: product.tags.isNotEmpty ? product.tags : null,
        quantity: product.quantity,
        trackInventory: product.trackInventory,
        hasVariants: product.hasVariants,
        variants: product.variants.isNotEmpty
            ? product.variants.map((v) => v.toJson()).toList()
            : null,
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
        images: product.images,
        tags: product.tags,
        quantity: product.quantity,
        trackInventory: product.trackInventory,
        hasVariants: product.hasVariants,
        variants: product.variants.isNotEmpty
            ? product.variants.map((v) => v.toJson()).toList()
            : null,
      ));
      return current.map((p) => p.id == product.id ? updated : p).toList();
    });
  }

  Future<void> toggleProductStatus(String productId) async {
    state = await AsyncValue.guard(() async {
      final current = state.valueOrNull ?? [];
      final product = current.firstWhereOrNull((p) => p.id == productId);
      if (product == null) return current;
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
