import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/product_model.dart';
import 'core_providers.dart';

/// Job filter categories
const jobTypeCategories = ['Todos', 'CLT', 'PJ', 'Freelance', 'Estágio', 'Temporário'];
const workModeCategories = ['Todos', 'Presencial', 'Remoto', 'Híbrido'];

/// Map display name to API value
String jobTypeCategoryToValue(String display) {
  switch (display) {
    case 'CLT': return 'clt';
    case 'PJ': return 'pj';
    case 'Freelance': return 'freelance';
    case 'Estágio': return 'estagio';
    case 'Temporário': return 'temporario';
    default: return '';
  }
}

String workModeCategoryToValue(String display) {
  switch (display) {
    case 'Presencial': return 'presencial';
    case 'Remoto': return 'remoto';
    case 'Híbrido': return 'hibrido';
    default: return '';
  }
}

/// Job filters class
class JobFilters {
  final String? jobType;
  final String? workMode;
  final String sortBy;

  const JobFilters({
    this.jobType,
    this.workMode,
    this.sortBy = 'recent',
  });

  JobFilters copyWith({
    String? jobType,
    String? workMode,
    String? sortBy,
  }) {
    return JobFilters(
      jobType: jobType ?? this.jobType,
      workMode: workMode ?? this.workMode,
      sortBy: sortBy ?? this.sortBy,
    );
  }

  int get activeFilterCount {
    int count = 0;
    if (jobType != null && jobType!.isNotEmpty) count++;
    if (workMode != null && workMode!.isNotEmpty) count++;
    if (sortBy != 'recent') count++;
    return count;
  }
}

/// Current job filters provider
final jobFiltersProvider = StateProvider.autoDispose<JobFilters>((ref) {
  return const JobFilters();
});

/// Selected job type filter (for category chips)
final selectedJobTypeProvider = StateProvider.autoDispose<String>((ref) => 'Todos');

/// Selected work mode filter
final selectedWorkModeProvider = StateProvider.autoDispose<String>((ref) => 'Todos');

/// Featured jobs provider
final featuredJobsProvider = FutureProvider.autoDispose<List<ProductModel>>((ref) async {
  final selectedType = ref.watch(selectedJobTypeProvider);
  final repository = ref.read(productRepositoryProvider);

  // If a specific type is selected, use filtered endpoint
  if (selectedType != 'Todos') {
    final typeValue = jobTypeCategoryToValue(selectedType);
    final response = await repository.getJobs(
      limit: 10,
      jobType: typeValue,
      sortBy: 'createdAt',
    );
    return response.products;
  }

  return repository.getFeaturedJobs(limit: 10);
});

/// Recent jobs provider
final recentJobsProvider = FutureProvider.autoDispose<List<ProductModel>>((ref) async {
  final selectedType = ref.watch(selectedJobTypeProvider);
  final repository = ref.read(productRepositoryProvider);

  if (selectedType != 'Todos') {
    final typeValue = jobTypeCategoryToValue(selectedType);
    final response = await repository.getJobs(
      limit: 20,
      jobType: typeValue,
      sortBy: 'createdAt',
    );
    return response.products;
  }

  return repository.getRecentJobs(limit: 20);
});

/// Paginated jobs for jobs screen
final paginatedJobsProvider =
    StateNotifierProvider.autoDispose<PaginatedJobsNotifier, PaginatedJobsState>((ref) {
  return PaginatedJobsNotifier(ref);
});

class PaginatedJobsState {
  final List<ProductModel> jobs;
  final bool isLoading;
  final bool hasMore;
  final int currentPage;

  const PaginatedJobsState({
    this.jobs = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.currentPage = 1,
  });

  PaginatedJobsState copyWith({
    List<ProductModel>? jobs,
    bool? isLoading,
    bool? hasMore,
    int? currentPage,
  }) {
    return PaginatedJobsState(
      jobs: jobs ?? this.jobs,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      currentPage: currentPage ?? this.currentPage,
    );
  }
}

class PaginatedJobsNotifier extends StateNotifier<PaginatedJobsState> {
  final Ref _ref;

  PaginatedJobsNotifier(this._ref) : super(const PaginatedJobsState()) {
    loadInitial();
  }

  Future<void> loadInitial() async {
    state = state.copyWith(isLoading: true, currentPage: 1);
    try {
      final repo = _ref.read(productRepositoryProvider);
      final filters = _ref.read(jobFiltersProvider);
      final selectedType = _ref.read(selectedJobTypeProvider);
      final typeValue = selectedType != 'Todos' ? jobTypeCategoryToValue(selectedType) : null;

      final response = await repo.getJobs(
        page: 1,
        limit: 20,
        jobType: typeValue ?? filters.jobType,
        workMode: filters.workMode,
        sortBy: filters.sortBy == 'recent' ? 'createdAt' : filters.sortBy,
      );
      state = PaginatedJobsState(
        jobs: response.products,
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
      final filters = _ref.read(jobFiltersProvider);
      final selectedType = _ref.read(selectedJobTypeProvider);
      final typeValue = selectedType != 'Todos' ? jobTypeCategoryToValue(selectedType) : null;

      final response = await repo.getJobs(
        page: nextPage,
        limit: 20,
        jobType: typeValue ?? filters.jobType,
        workMode: filters.workMode,
        sortBy: filters.sortBy == 'recent' ? 'createdAt' : filters.sortBy,
      );
      state = state.copyWith(
        jobs: [...state.jobs, ...response.products],
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
