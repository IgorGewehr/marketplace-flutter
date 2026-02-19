import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/category_model.dart';
import '../../data/models/product_model.dart';
import '../../data/models/promo_banner_model.dart';
import 'core_providers.dart';

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

  const ProductFilters({
    this.query,
    this.category,
    this.minPrice,
    this.maxPrice,
    this.sortBy = 'recent',
    this.page = 1,
    this.limit = 20,
    this.tags,
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
    );
  }

  int get activeFilterCount {
    int count = 0;
    if (category != null && category != 'Todos') count++;
    if (minPrice != null) count++;
    if (maxPrice != null) count++;
    if (sortBy != 'recent') count++;
    if (tags != null && tags!.isNotEmpty) count++;
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

  const PaginatedProductsState({
    this.products = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.currentPage = 1,
  });

  PaginatedProductsState copyWith({
    List<ProductModel>? products,
    bool? isLoading,
    bool? hasMore,
    int? currentPage,
  }) {
    return PaginatedProductsState(
      products: products ?? this.products,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

class PaginatedProductsNotifier extends StateNotifier<PaginatedProductsState> {
  final Ref _ref;

  PaginatedProductsNotifier(this._ref) : super(const PaginatedProductsState()) {
    loadInitial();
  }

  Future<void> loadInitial() async {
    state = state.copyWith(isLoading: true, currentPage: 1);
    try {
      final repo = _ref.read(productRepositoryProvider);
      final response = await repo.getProducts(page: 1, limit: 20, sortBy: 'recent');
      state = PaginatedProductsState(
        products: response.products,
        hasMore: response.hasMore,
        currentPage: 1,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
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

/// Products with filters provider
final filteredProductsProvider = FutureProvider<List<ProductModel>>((ref) async {
  final filters = ref.watch(productFiltersProvider);
  final repository = ref.read(productRepositoryProvider);
  final response = await repository.getProducts(
    page: filters.page,
    limit: filters.limit,
    search: filters.query,
    categoryId: filters.category,
    minPrice: filters.minPrice,
    maxPrice: filters.maxPrice,
    sortBy: filters.sortBy,
  );
  return response.products;
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

  void _loadFavorites() {
    try {
      final storage = _ref.read(localStorageProvider);
      final localFavorites = storage.loadFavoriteIds();
      if (localFavorites.isNotEmpty) {
        state = localFavorites;
      }
    } catch (_) {
      // Silent fail, start with empty favorites
    }
  }

  Future<void> toggleFavorite(String productId) async {
    final newState = {...state};

    if (newState.contains(productId)) {
      newState.remove(productId);
    } else {
      newState.add(productId);
    }

    state = newState;
    await _ref.read(localStorageProvider).saveFavoriteIds(newState);
  }

  bool isFavorite(String productId) => state.contains(productId);

  void clearFavorites() {
    state = {};
    _ref.read(localStorageProvider).saveFavoriteIds({});
  }
}

/// Provider for favorite products list (actual product data).
/// Serves from local cache first, then refreshes from API.
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

  // 2. Try to refresh from API
  try {
    final results = await Future.wait(
      favoriteIds.map((id) async {
        try {
          final product = await repository.getById(id);
          // Update cache with fresh data
          storage.cacheProduct(id, product.toJson());
          return product;
        } catch (_) {
          return null;
        }
      }),
    );

    final freshProducts = results.whereType<ProductModel>().toList();
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
    if (response is List) {
      return (response as List<dynamic>)
          .map((b) => PromoBanner.fromJson(b as Map<String, dynamic>))
          .toList();
    }
    return [];
  } catch (e) {
    // Fallback: hide carousel if API fails
    return [];
  }
});
