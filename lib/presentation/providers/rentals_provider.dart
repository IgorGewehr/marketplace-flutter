import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/product_model.dart';
import 'core_providers.dart';

/// Rental category options (local, not from API)
const rentalCategories = ['Todos', 'Imóveis', 'Equipamentos', 'Veículos', 'Outros'];

/// Selected rental category provider
final selectedRentalCategoryProvider = StateProvider.autoDispose<String>((ref) => 'Todos');

/// Map display name to rentalType API value
String rentalCategoryToType(String display) {
  switch (display) {
    case 'Imóveis':
      return 'imovel';
    case 'Equipamentos':
      return 'equipamento';
    case 'Veículos':
      return 'veiculo';
    case 'Outros':
      return 'outro';
    default:
      return '';
  }
}

/// Rental filters class
class RentalFilters {
  final String? query;
  final String? rentalType;
  final String? rentalPeriod;
  final double? minPrice;
  final double? maxPrice;
  final String? city;
  final int? bedrooms;
  final double? minArea;
  final String sortBy;
  final int page;
  final int limit;

  const RentalFilters({
    this.query,
    this.rentalType,
    this.rentalPeriod,
    this.minPrice,
    this.maxPrice,
    this.city,
    this.bedrooms,
    this.minArea,
    this.sortBy = 'recent',
    this.page = 1,
    this.limit = 20,
  });

  RentalFilters copyWith({
    String? query,
    String? rentalType,
    String? rentalPeriod,
    double? minPrice,
    double? maxPrice,
    String? city,
    int? bedrooms,
    double? minArea,
    String? sortBy,
    int? page,
    int? limit,
  }) {
    return RentalFilters(
      query: query ?? this.query,
      rentalType: rentalType ?? this.rentalType,
      rentalPeriod: rentalPeriod ?? this.rentalPeriod,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      city: city ?? this.city,
      bedrooms: bedrooms ?? this.bedrooms,
      minArea: minArea ?? this.minArea,
      sortBy: sortBy ?? this.sortBy,
      page: page ?? this.page,
      limit: limit ?? this.limit,
    );
  }

  int get activeFilterCount {
    int count = 0;
    if (rentalType != null && rentalType!.isNotEmpty) count++;
    if (rentalPeriod != null) count++;
    if (minPrice != null) count++;
    if (maxPrice != null) count++;
    if (city != null && city!.isNotEmpty) count++;
    if (bedrooms != null) count++;
    if (minArea != null) count++;
    if (sortBy != 'recent') count++;
    return count;
  }
}

/// Current rental filters provider
final rentalFiltersProvider = StateProvider.autoDispose<RentalFilters>((ref) {
  return const RentalFilters();
});

/// Featured rentals provider — observes selected category
final featuredRentalsProvider = FutureProvider.autoDispose<List<ProductModel>>((ref) async {
  final selectedCategory = ref.watch(selectedRentalCategoryProvider);
  final repository = ref.read(productRepositoryProvider);

  if (selectedCategory != 'Todos') {
    final rentalType = rentalCategoryToType(selectedCategory);
    final response = await repository.getRentals(
      limit: 10,
      rentalType: rentalType.isNotEmpty ? rentalType : null,
      sortBy: 'createdAt',
    );
    return response.products;
  }

  return repository.getFeaturedRentals(limit: 10);
});

/// Recent rentals provider — observes selected category
final recentRentalsProvider = FutureProvider.autoDispose<List<ProductModel>>((ref) async {
  final selectedCategory = ref.watch(selectedRentalCategoryProvider);
  final repository = ref.read(productRepositoryProvider);

  if (selectedCategory != 'Todos') {
    final rentalType = rentalCategoryToType(selectedCategory);
    final response = await repository.getRentals(
      limit: 20,
      rentalType: rentalType.isNotEmpty ? rentalType : null,
      sortBy: 'createdAt',
    );
    return response.products;
  }

  return repository.getRecentRentals(limit: 20);
});

/// Paginated rentals for infinite scroll
final paginatedRentalsProvider =
    StateNotifierProvider.autoDispose<PaginatedRentalsNotifier, PaginatedRentalsState>((ref) {
  return PaginatedRentalsNotifier(ref);
});

class PaginatedRentalsState {
  final List<ProductModel> rentals;
  final bool isLoading;
  final bool hasMore;
  final int currentPage;

  const PaginatedRentalsState({
    this.rentals = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.currentPage = 1,
  });

  PaginatedRentalsState copyWith({
    List<ProductModel>? rentals,
    bool? isLoading,
    bool? hasMore,
    int? currentPage,
  }) {
    return PaginatedRentalsState(
      rentals: rentals ?? this.rentals,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

class PaginatedRentalsNotifier extends StateNotifier<PaginatedRentalsState> {
  final Ref _ref;

  PaginatedRentalsNotifier(this._ref) : super(const PaginatedRentalsState()) {
    loadInitial();
  }

  Future<void> loadInitial() async {
    state = state.copyWith(isLoading: true, currentPage: 1);
    try {
      final repo = _ref.read(productRepositoryProvider);
      final filters = _ref.read(rentalFiltersProvider);
      final response = await repo.getRentals(
        page: 1,
        limit: 20,
        rentalType: filters.rentalType,
        minPrice: filters.minPrice,
        maxPrice: filters.maxPrice,
        sortBy: filters.sortBy,
        search: filters.query,
      );
      state = PaginatedRentalsState(
        rentals: response.products,
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
      final filters = _ref.read(rentalFiltersProvider);
      final response = await repo.getRentals(
        page: nextPage,
        limit: 20,
        rentalType: filters.rentalType,
        minPrice: filters.minPrice,
        maxPrice: filters.maxPrice,
        sortBy: filters.sortBy,
        search: filters.query,
      );
      state = state.copyWith(
        rentals: [...state.rentals, ...response.products],
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

/// Filtered rentals provider
final filteredRentalsProvider = FutureProvider.autoDispose<List<ProductModel>>((ref) async {
  final filters = ref.watch(rentalFiltersProvider);
  final repository = ref.read(productRepositoryProvider);
  final response = await repository.getRentals(
    page: filters.page,
    limit: filters.limit,
    rentalType: filters.rentalType,
    rentalPeriod: filters.rentalPeriod,
    minPrice: filters.minPrice,
    maxPrice: filters.maxPrice,
    city: filters.city,
    bedrooms: filters.bedrooms,
    minArea: filters.minArea,
    sortBy: filters.sortBy,
    search: filters.query,
  );
  return response.products;
});

/// Search rentals by query — used by cross-type search in search screen
final rentalSearchProvider = FutureProvider.autoDispose.family<List<ProductModel>, String>((ref, query) async {
  if (query.isEmpty) return [];
  final repository = ref.read(productRepositoryProvider);
  final response = await repository.getRentals(search: query, limit: 5);
  return response.products;
});

// ─── Rental Favorites ────────────────────────────────────────────────────────

/// Favorite rental IDs with Hive local storage persistence (Hive-only, no server sync)
final favoriteRentalIdsProvider =
    StateNotifierProvider<FavoriteRentalIdsNotifier, Set<String>>((ref) {
  return FavoriteRentalIdsNotifier(ref);
});

class FavoriteRentalIdsNotifier extends StateNotifier<Set<String>> {
  final Ref _ref;

  FavoriteRentalIdsNotifier(this._ref) : super({}) {
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    try {
      final ids = _ref.read(localStorageProvider).loadRentalFavoriteIds();
      state = ids;
    } catch (_) {}
  }

  Future<void> toggleFavorite(String rentalId) async {
    final newState = {...state};
    if (newState.contains(rentalId)) {
      newState.remove(rentalId);
    } else {
      newState.add(rentalId);
    }
    state = newState;
    await _ref.read(localStorageProvider).saveRentalFavoriteIds(newState);
  }

  void clearFavorites() {
    state = {};
    _ref.read(localStorageProvider).saveRentalFavoriteIds({});
  }
}

/// Check if a rental is favorite
final isRentalFavoriteProvider = Provider.family<bool, String>((ref, rentalId) {
  return ref.watch(favoriteRentalIdsProvider).contains(rentalId);
});
