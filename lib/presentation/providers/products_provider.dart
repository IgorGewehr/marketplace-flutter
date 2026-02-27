import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/category_model.dart';
import '../../data/models/product_model.dart';
import '../../data/models/promo_banner_model.dart';
import 'auth_providers.dart';
import 'core_providers.dart';
import 'follows_provider.dart';

const _defaultCategories = [
  'Veículos',
  'Eletrônicos',
  'Móveis',
  'Roupas',
  'Doces',
  'Coloniais',
  'Ferramentas',
  'Casa e Jardim',
  'Esportes',
  'Livros',
  'Brinquedos',
  'Serviços',
  'Outros',
];

List<CategoryModel> _buildFallbackModels() {
  final now = DateTime.now();
  return _defaultCategories
      .map((name) => CategoryModel(
            id: name.toLowerCase(),
            name: name,
            slug: name.toLowerCase(),
            createdAt: now,
            updatedAt: now,
          ))
      .toList();
}

/// Category models provider - fetches full CategoryModel objects from API
final categoryModelsProvider = FutureProvider<List<CategoryModel>>((ref) async {
  try {
    final repository = ref.read(productRepositoryProvider);
    final categories = await repository.getCategories();
    if (categories.isNotEmpty) return categories;
  } catch (_) {}
  return _buildFallbackModels();
});

/// Categories provider - returns names for search/filter screens
final categoriesProvider = FutureProvider<List<String>>((ref) async {
  final models = await ref.watch(categoryModelsProvider.future);
  return ['Todos', ...models.map((c) => c.name)];
});

/// Maps category display name to its ID for API calls
final categoryNameToIdProvider = FutureProvider<Map<String, String>>((ref) async {
  final models = await ref.watch(categoryModelsProvider.future);
  return {for (final c in models) c.name: c.id};
});

/// Maps category ID back to its display name (for UI restoration)
final categoryIdToNameProvider = FutureProvider<Map<String, String>>((ref) async {
  final models = await ref.watch(categoryModelsProvider.future);
  return {for (final c in models) c.id: c.name};
});

/// Selected category provider
final selectedCategoryProvider = StateProvider<String>((ref) => 'Todos');

/// Product filters class
class ProductFilters {
  final String? query;
  final String? category;
  final double? minPrice;
  final double? maxPrice;
  final String sortBy; // 'recent', 'price_asc', 'price_desc', 'relevance'
  final int page;
  final int limit;
  final List<String>? tags;
  final bool followedOnly;

  const ProductFilters({
    this.query,
    this.category,
    this.minPrice,
    this.maxPrice,
    this.sortBy = 'recent',
    this.page = 1,
    this.limit = 20,
    this.tags,
    this.followedOnly = false,
  });

  ProductFilters copyWith({
    String? query,
    String? category,
    double? minPrice,
    double? maxPrice,
    String? sortBy,
    int? page,
    int? limit,
    List<String>? tags,
    bool? followedOnly,
  }) {
    return ProductFilters(
      query: query ?? this.query,
      category: category ?? this.category,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      sortBy: sortBy ?? this.sortBy,
      page: page ?? this.page,
      limit: limit ?? this.limit,
      tags: tags ?? this.tags,
      followedOnly: followedOnly ?? this.followedOnly,
    );
  }

  int get activeFilterCount {
    int count = 0;
    if (category != null && category != 'Todos') count++;
    if (minPrice != null) count++;
    if (maxPrice != null) count++;
    if (sortBy != 'recent') count++;
    if (tags != null && tags!.isNotEmpty) count++;
    if (followedOnly) count++;
    return count;
  }

  Map<String, dynamic> toQueryParams() {
    return {
      if (query != null && query!.isNotEmpty) 'q': query,
      if (category != null && category != 'Todos') 'category': category,
      if (minPrice != null) 'min_price': minPrice,
      if (maxPrice != null) 'max_price': maxPrice,
      if (tags != null && tags!.isNotEmpty) 'tags': tags!.join(','),
      'sort': sortBy,
      'page': page,
      'limit': limit,
    };
  }
}

/// Current filters provider
final productFiltersProvider = StateProvider<ProductFilters>((ref) {
  return const ProductFilters();
});

/// Featured products provider (homepage highlights)
final featuredProductsProvider = FutureProvider<List<ProductModel>>((ref) async {
  final repository = ref.read(productRepositoryProvider);
  return repository.getFeatured(limit: 10);
});

/// Recent products in area provider
final recentProductsProvider = FutureProvider<List<ProductModel>>((ref) async {
  final repository = ref.read(productRepositoryProvider);
  return repository.getRecent(limit: 20);
});

/// Paginated recent products for infinite scroll on home screen
final paginatedRecentProductsProvider =
    StateNotifierProvider<PaginatedProductsNotifier, PaginatedProductsState>((ref) {
  return PaginatedProductsNotifier(ref);
});

class PaginatedProductsState {
  final List<ProductModel> products;
  final bool isLoading;
  final bool hasMore;
  final int currentPage;
  final Object? error;

  const PaginatedProductsState({
    this.products = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.currentPage = 1,
    this.error,
  });

  PaginatedProductsState copyWith({
    List<ProductModel>? products,
    bool? isLoading,
    bool? hasMore,
    int? currentPage,
    Object? error,
  }) {
    return PaginatedProductsState(
      products: products ?? this.products,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      error: error,
    );
  }
}

class PaginatedProductsNotifier extends StateNotifier<PaginatedProductsState> {
  final Ref _ref;

  PaginatedProductsNotifier(this._ref) : super(const PaginatedProductsState()) {
    loadInitial();
  }

  Future<void> loadInitial() async {
    state = state.copyWith(isLoading: true, currentPage: 1, error: null);
    try {
      final repo = _ref.read(productRepositoryProvider);
      final response = await repo.getProducts(page: 1, limit: 20, sortBy: 'recent');
      state = PaginatedProductsState(
        products: response.products,
        hasMore: response.hasMore,
        currentPage: 1,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;
    state = state.copyWith(isLoading: true);

    try {
      final nextPage = state.currentPage + 1;
      final repo = _ref.read(productRepositoryProvider);
      final response = await repo.getProducts(page: nextPage, limit: 20, sortBy: 'recent');
      state = state.copyWith(
        products: [...state.products, ...response.products],
        hasMore: response.hasMore,
        currentPage: nextPage,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> refresh() async {
    await loadInitial();
  }
}

/// Paginated search/filter state
class FilteredProductsState {
  final List<ProductModel> products;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int currentPage;
  final Object? error;

  const FilteredProductsState({
    this.products = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.currentPage = 1,
    this.error,
  });

  FilteredProductsState copyWith({
    List<ProductModel>? products,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? currentPage,
    Object? error,
  }) {
    return FilteredProductsState(
      products: products ?? this.products,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
      error: error,
    );
  }
}

class FilteredProductsNotifier extends StateNotifier<FilteredProductsState> {
  final Ref _ref;
  static const int _pageSize = 20;

  FilteredProductsNotifier(this._ref) : super(const FilteredProductsState()) {
    _load();
  }

  Future<void> _load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final filters = _ref.read(productFiltersProvider);
      final repository = _ref.read(productRepositoryProvider);

      if (filters.followedOnly) {
        // Fetch products from every followed seller and combine
        final followedIds = _ref.read(followsProvider);
        if (followedIds.isEmpty) {
          state = const FilteredProductsState(products: [], hasMore: false, currentPage: 1);
          return;
        }
        final results = <ProductModel>[];
        await Future.wait(
          followedIds.map((tenantId) async {
            try {
              final response = await repository.getProducts(
                tenantId: tenantId,
                page: 1,
                limit: _pageSize,
                search: filters.query,
                sortBy: filters.sortBy,
              );
              results.addAll(response.products);
            } catch (_) {}
          }),
        );
        state = FilteredProductsState(
          products: results,
          hasMore: false,
          currentPage: 1,
        );
        return;
      }

      final response = await repository.getProducts(
        page: 1,
        limit: _pageSize,
        search: filters.query,
        categoryId: filters.category,
        minPrice: filters.minPrice,
        maxPrice: filters.maxPrice,
        sortBy: filters.sortBy,
      );
      state = FilteredProductsState(
        products: response.products,
        hasMore: response.hasMore,
        currentPage: 1,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    // followedOnly loads everything in one shot — no pagination
    if (_ref.read(productFiltersProvider).followedOnly) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final nextPage = state.currentPage + 1;
      final filters = _ref.read(productFiltersProvider);
      final repository = _ref.read(productRepositoryProvider);
      final response = await repository.getProducts(
        page: nextPage,
        limit: _pageSize,
        search: filters.query,
        categoryId: filters.category,
        minPrice: filters.minPrice,
        maxPrice: filters.maxPrice,
        sortBy: filters.sortBy,
      );
      state = state.copyWith(
        products: [...state.products, ...response.products],
        hasMore: response.hasMore,
        currentPage: nextPage,
        isLoadingMore: false,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<void> refresh() async {
    await _load();
  }
}

/// Products with filters provider (paginated)
final filteredProductsProvider =
    StateNotifierProvider<FilteredProductsNotifier, FilteredProductsState>((ref) {
  final notifier = FilteredProductsNotifier(ref);
  ref.listen(productFiltersProvider, (_, __) {
    notifier.refresh();
  });
  return notifier;
});

/// Products by category provider - for carousel display
/// Accepts a category name and resolves it to an ID for the API call.
final productsByCategoryProvider = FutureProvider.family<List<ProductModel>, String>(
  (ref, category) async {
    final repository = ref.read(productRepositoryProvider);
    final nameToId = ref.watch(categoryNameToIdProvider).valueOrNull ?? {};
    final categoryId = category == 'Todos' ? null : (nameToId[category] ?? category);
    try {
      final response = await repository.getProducts(
        page: 1,
        limit: 10,
        categoryId: categoryId,
        sortBy: 'recent',
      );
      return response.products;
    } catch (e) {
      return [];
    }
  },
);

/// Products from followed sellers — used in the home screen carousel.
/// Automatically refreshes when followsProvider changes (follow/unfollow).
final followedSellersProductsProvider = FutureProvider<List<ProductModel>>((ref) async {
  final followedIds = ref.watch(followsProvider);
  if (followedIds.isEmpty) return [];

  final repository = ref.read(productRepositoryProvider);
  final results = <ProductModel>[];

  // Fetch up to 5 products per seller, capped at the first 6 sellers
  await Future.wait(
    followedIds.take(6).map((tenantId) async {
      try {
        final response = await repository.getProducts(tenantId: tenantId, limit: 5);
        results.addAll(response.products);
      } catch (_) {}
    }),
  );

  return results;
});

/// Seller products provider - fetches products for a specific seller
final sellerProductsProvider = FutureProvider.family<List<ProductModel>, String>(
  (ref, tenantId) async {
    final repository = ref.read(productRepositoryProvider);
    final response = await repository.getProducts(tenantId: tenantId, limit: 50);
    return response.products;
  },
);

/// Product detail provider - caches locally for offline access
final productDetailProvider = FutureProvider.family<ProductModel?, String>((ref, id) async {
  final repository = ref.read(productRepositoryProvider);
  final storage = ref.read(localStorageProvider);

  try {
    final product = await repository.getById(id);
    storage.cacheProduct(id, product.toJson());
    return product;
  } catch (_) {
    // Offline fallback: try local cache
    final cached = storage.getCachedProduct(id);
    if (cached != null) return ProductModel.fromJson(cached);
    return null;
  }
});

/// Search query provider
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Search history provider (local storage)
final searchHistoryProvider = StateNotifierProvider<SearchHistoryNotifier, List<String>>((ref) {
  return SearchHistoryNotifier();
});

class SearchHistoryNotifier extends StateNotifier<List<String>> {
  static const int maxHistory = 10;

  SearchHistoryNotifier() : super([]);

  void addSearch(String query) {
    if (query.isEmpty) return;

    // Remove if already exists
    state = state.where((s) => s != query).toList();

    // Add to beginning
    state = [query, ...state];

    // Limit history size
    if (state.length > maxHistory) {
      state = state.sublist(0, maxHistory);
    }
  }

  void removeSearch(String query) {
    state = state.where((s) => s != query).toList();
  }

  void clearHistory() {
    state = [];
  }
}

/// Favorite products provider with Hive local storage (singleton box)
final favoriteProductIdsProvider = StateNotifierProvider<FavoritesNotifier, Set<String>>((ref) {
  return FavoritesNotifier(ref);
});

class FavoritesNotifier extends StateNotifier<Set<String>> {
  final Ref _ref;

  FavoritesNotifier(this._ref) : super({}) {
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    try {
      final storage = _ref.read(localStorageProvider);
      final localFavorites = storage.loadFavoriteIds();

      // Merge with server favorites when user is authenticated
      final user = _ref.read(currentUserProvider).valueOrNull;
      final Set<String> loaded;
      if (user != null && user.favoriteProductIds.isNotEmpty) {
        loaded = {...localFavorites, ...user.favoriteProductIds};
        await storage.saveFavoriteIds(loaded);
      } else if (localFavorites.isNotEmpty) {
        loaded = localFavorites;
      } else {
        loaded = {};
      }

      // A6: Merge with current state to preserve any toggles that happened
      // while this async load was in flight.
      state = state.union(loaded);
    } catch (_) {
      // Silent fail, start with empty favorites
    }
  }

  Future<void> toggleFavorite(String productId) async {
    final previousState = {...state};
    final newState = {...state};

    if (newState.contains(productId)) {
      newState.remove(productId);
    } else {
      newState.add(productId);
    }

    // Optimistic update: persist locally immediately (offline-first)
    state = newState;
    await _ref.read(localStorageProvider).saveFavoriteIds(newState);

    // Sync to server — revert on failure
    try {
      final authRepo = _ref.read(authRepositoryProvider);
      await authRepo.updateFavorites(newState.toList());
    } catch (_) {
      // Server sync failed — revert to previous state
      state = previousState;
      await _ref.read(localStorageProvider).saveFavoriteIds(previousState);
    }
  }

  bool isFavorite(String productId) => state.contains(productId);

  void clearFavorites() {
    state = {};
    _ref.read(localStorageProvider).saveFavoriteIds({});
  }
}

/// Provider for favorite products list (actual product data).
/// Serves from local cache first, then refreshes from API in batches of 5.
final favoriteProductsProvider = FutureProvider<List<ProductModel>>((ref) async {
  final favoriteIds = ref.watch(favoriteProductIdsProvider);
  if (favoriteIds.isEmpty) return [];

  final storage = ref.read(localStorageProvider);
  final repository = ref.read(productRepositoryProvider);

  // 1. Load from cache immediately
  final cachedJsons = storage.getCachedProducts(favoriteIds);
  final cachedProducts = cachedJsons
      .map((json) => ProductModel.fromJson(json))
      .toList();

  // 2. M9: Refresh from API in sequential batches of 5 (cap at 20 total)
  try {
    final ids = favoriteIds.take(20).toList();
    final freshProducts = <ProductModel>[];

    for (var i = 0; i < ids.length; i += 5) {
      final chunk = ids.sublist(i, min(i + 5, ids.length));
      final batchResults = await Future.wait(
        chunk.map((id) async {
          try {
            final product = await repository.getById(id);
            storage.cacheProduct(id, product.toJson());
            return product;
          } catch (_) {
            return null;
          }
        }),
      );
      freshProducts.addAll(batchResults.whereType<ProductModel>());
    }

    return freshProducts.isNotEmpty ? freshProducts : cachedProducts;
  } catch (_) {
    // Offline - return cached data
    return cachedProducts;
  }
});

/// Check if a product is favorite
final isProductFavoriteProvider = Provider.family<bool, String>((ref, productId) {
  final favorites = ref.watch(favoriteProductIdsProvider);
  return favorites.contains(productId);
});

/// Promo banners provider - fetches from API with fallback to empty list
final promoBannersProvider = FutureProvider<List<PromoBanner>>((ref) async {
  try {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.get<List<dynamic>>('/api/marketplace/banners');
    return response
        .map((b) => PromoBanner.fromJson(b as Map<String, dynamic>))
        .toList();
  } catch (e) {
    // Fallback: hide carousel if API fails
    return [];
  }
});
