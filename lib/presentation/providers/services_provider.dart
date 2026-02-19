import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/service_model.dart';
import 'core_providers.dart';

/// Service categories provider - fetches from API
final serviceCategoriesProvider = FutureProvider<List<String>>((ref) async {
  final repository = ref.read(serviceRepositoryProvider);
  final categories = await repository.getCategories();

  // Add "Todos" as first option
  return ['Todos', ...categories.map((c) => c.name).toList()];
});

/// Selected service category provider
final selectedServiceCategoryProvider = StateProvider<String>((ref) => 'Todos');

/// Service filters class
class ServiceFilters {
  final String? query;
  final String? categoryId;
  final String? subcategoryId;
  final double? minPrice;
  final double? maxPrice;
  final String? pricingType;
  final String? city;
  final String? state;
  final bool? isRemote;
  final String sortBy; // 'recent', 'price_asc', 'price_desc', 'rating', 'popular'
  final int page;
  final int limit;

  const ServiceFilters({
    this.query,
    this.categoryId,
    this.subcategoryId,
    this.minPrice,
    this.maxPrice,
    this.pricingType,
    this.city,
    this.state,
    this.isRemote,
    this.sortBy = 'recent',
    this.page = 1,
    this.limit = 20,
  });

  ServiceFilters copyWith({
    String? query,
    String? categoryId,
    String? subcategoryId,
    double? minPrice,
    double? maxPrice,
    String? pricingType,
    String? city,
    String? state,
    bool? isRemote,
    String? sortBy,
    int? page,
    int? limit,
  }) {
    return ServiceFilters(
      query: query ?? this.query,
      categoryId: categoryId ?? this.categoryId,
      subcategoryId: subcategoryId ?? this.subcategoryId,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      pricingType: pricingType ?? this.pricingType,
      city: city ?? this.city,
      state: state ?? this.state,
      isRemote: isRemote ?? this.isRemote,
      sortBy: sortBy ?? this.sortBy,
      page: page ?? this.page,
      limit: limit ?? this.limit,
    );
  }

  Map<String, dynamic> toQueryParams() {
    return {
      if (query != null && query!.isNotEmpty) 'q': query,
      if (categoryId != null && categoryId != 'Todos') 'categoryId': categoryId,
      if (subcategoryId != null) 'subcategoryId': subcategoryId,
      if (minPrice != null) 'minPrice': minPrice,
      if (maxPrice != null) 'maxPrice': maxPrice,
      if (pricingType != null) 'pricingType': pricingType,
      if (city != null) 'city': city,
      if (state != null) 'state': state,
      if (isRemote != null) 'isRemote': isRemote,
      'sortBy': sortBy,
      'page': page,
      'limit': limit,
    };
  }
}

/// Current service filters provider
final serviceFiltersProvider = StateProvider<ServiceFilters>((ref) {
  return const ServiceFilters();
});

/// Featured services provider (homepage highlights)
final featuredServicesProvider = FutureProvider<List<MarketplaceServiceModel>>((ref) async {
  final repository = ref.read(serviceRepositoryProvider);
  return repository.getFeatured(limit: 10);
});

/// Recent services provider
final recentServicesProvider = FutureProvider<List<MarketplaceServiceModel>>((ref) async {
  final repository = ref.read(serviceRepositoryProvider);
  return repository.getRecent(limit: 20);
});

/// Paginated recent services for infinite scroll
final paginatedRecentServicesProvider =
    StateNotifierProvider<PaginatedServicesNotifier, PaginatedServicesState>((ref) {
  return PaginatedServicesNotifier(ref);
});

class PaginatedServicesState {
  final List<MarketplaceServiceModel> services;
  final bool isLoading;
  final bool hasMore;
  final int currentPage;

  const PaginatedServicesState({
    this.services = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.currentPage = 1,
  });

  PaginatedServicesState copyWith({
    List<MarketplaceServiceModel>? services,
    bool? isLoading,
    bool? hasMore,
    int? currentPage,
  }) {
    return PaginatedServicesState(
      services: services ?? this.services,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

class PaginatedServicesNotifier extends StateNotifier<PaginatedServicesState> {
  final Ref _ref;

  PaginatedServicesNotifier(this._ref) : super(const PaginatedServicesState()) {
    loadInitial();
  }

  Future<void> loadInitial() async {
    state = state.copyWith(isLoading: true, currentPage: 1);
    try {
      final repo = _ref.read(serviceRepositoryProvider);
      final response = await repo.getServices(page: 1, limit: 20, sortBy: 'recent');
      state = PaginatedServicesState(
        services: response.services,
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
      final repo = _ref.read(serviceRepositoryProvider);
      final response = await repo.getServices(page: nextPage, limit: 20, sortBy: 'recent');
      state = state.copyWith(
        services: [...state.services, ...response.services],
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

/// Services with filters provider
final filteredServicesProvider = FutureProvider<List<MarketplaceServiceModel>>((ref) async {
  final filters = ref.watch(serviceFiltersProvider);
  final repository = ref.read(serviceRepositoryProvider);
  final response = await repository.getServices(
    page: filters.page,
    limit: filters.limit,
    categoryId: filters.categoryId,
    subcategoryId: filters.subcategoryId,
    minPrice: filters.minPrice,
    maxPrice: filters.maxPrice,
    pricingType: filters.pricingType,
    city: filters.city,
    state: filters.state,
    isRemote: filters.isRemote,
    sortBy: filters.sortBy,
  );
  return response.services;
});

/// Service detail provider
final serviceDetailProvider = FutureProvider.family<ServiceModel?, String>((ref, id) async {
  final repository = ref.read(serviceRepositoryProvider);
  try {
    return await repository.getById(id);
  } catch (_) {
    return null;
  }
});

/// Service search query provider
final serviceSearchQueryProvider = StateProvider<String>((ref) => '');

/// Service search history provider (local storage)
final serviceSearchHistoryProvider = StateNotifierProvider<ServiceSearchHistoryNotifier, List<String>>((ref) {
  return ServiceSearchHistoryNotifier();
});

class ServiceSearchHistoryNotifier extends StateNotifier<List<String>> {
  static const int maxHistory = 10;

  ServiceSearchHistoryNotifier() : super([]);

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

/// Favorite services provider with Hive local storage persistence
final favoriteServiceIdsProvider = StateNotifierProvider<FavoriteServicesNotifier, Set<String>>((ref) {
  return FavoriteServicesNotifier(ref);
});

class FavoriteServicesNotifier extends StateNotifier<Set<String>> {
  final Ref _ref;

  FavoriteServicesNotifier(this._ref) : super({}) {
    _loadFavorites();
  }

  void _loadFavorites() {
    try {
      final storage = _ref.read(localStorageProvider);
      final localFavorites = storage.loadServiceFavoriteIds();
      if (localFavorites.isNotEmpty) {
        state = localFavorites;
      }
    } catch (_) {
      // Silent fail, start with empty favorites
    }
  }

  Future<void> toggleFavorite(String serviceId) async {
    final newState = {...state};

    if (newState.contains(serviceId)) {
      newState.remove(serviceId);
    } else {
      newState.add(serviceId);
    }

    state = newState;
    await _ref.read(localStorageProvider).saveServiceFavoriteIds(newState);
  }

  bool isFavorite(String serviceId) => state.contains(serviceId);

  void clearFavorites() {
    state = {};
    _ref.read(localStorageProvider).saveServiceFavoriteIds({});
  }
}

/// Check if a service is favorite
final isServiceFavoriteProvider = Provider.family<bool, String>((ref, serviceId) {
  final favorites = ref.watch(favoriteServiceIdsProvider);
  return favorites.contains(serviceId);
});

/// Pricing type filter options
final pricingTypeOptions = [
  'Todos',
  'Por hora',
  'Por projeto',
  'Mensal',
  'Preço fixo',
  'Sob demanda',
];

/// Map pricing type display to API value
String pricingTypeToApi(String display) {
  switch (display) {
    case 'Por hora':
      return 'hourly';
    case 'Por projeto':
      return 'project';
    case 'Mensal':
      return 'monthly';
    case 'Preço fixo':
      return 'fixed';
    case 'Sob demanda':
      return 'on_demand';
    default:
      return '';
  }
}

/// Map pricing type API value to display
String pricingTypeToDisplay(String api) {
  switch (api) {
    case 'hourly':
      return 'Por hora';
    case 'project':
      return 'Por projeto';
    case 'monthly':
      return 'Mensal';
    case 'fixed':
      return 'Preço fixo';
    case 'on_demand':
      return 'Sob demanda';
    default:
      return 'Todos';
  }
}
