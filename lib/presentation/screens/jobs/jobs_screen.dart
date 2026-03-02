import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../providers/jobs_provider.dart';
import '../../widgets/home/section_header.dart';
import '../../widgets/jobs/job_card.dart';
import '../../widgets/shared/error_state.dart';
import '../../widgets/shared/shimmer_loading.dart';

/// Jobs listing screen with filters — follows Services screen pattern
class JobsScreen extends ConsumerStatefulWidget {
  const JobsScreen({super.key});

  @override
  ConsumerState<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends ConsumerState<JobsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(paginatedJobsProvider.notifier).loadMore();
    }
  }

  Future<void> _onRefresh() async {
    ref.invalidate(featuredJobsProvider);
    ref.invalidate(recentJobsProvider);
    ref.read(paginatedJobsProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final featuredAsync = ref.watch(featuredJobsProvider);
    final recentAsync = ref.watch(recentJobsProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Vagas de Emprego'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/search'),
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterBottomSheet(context),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Category chips (job types)
              SliverToBoxAdapter(
                child: _JobCategoryChips(),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // Featured jobs section
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'Em Destaque',
                  actionLabel: 'Ver todas',
                  onActionPressed: () {
                    ref.read(selectedJobTypeProvider.notifier).state = 'Todos';
                    ref.invalidate(featuredJobsProvider);
                  },
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // Featured jobs grid
              featuredAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: ShimmerLoading(itemCount: 4, isGrid: true),
                ),
                error: (_, __) => SliverToBoxAdapter(
                  child: ErrorState(
                    icon: Icons.cloud_off_rounded,
                    message: 'Erro ao carregar vagas em destaque.',
                    onRetry: () => ref.invalidate(featuredJobsProvider),
                  ),
                ),
                data: (jobs) {
                  if (jobs.isEmpty) {
                    return SliverToBoxAdapter(
                      child: _AnimatedEmptySection(
                        icon: Icons.work_outline_rounded,
                        title: 'Nenhuma vaga em destaque',
                        subtitle: 'Novas vagas aparecerão aqui em breve',
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.68,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => JobCard(job: jobs[index])
                            .animate(delay: Duration(milliseconds: (index % 6) * 60))
                            .fadeIn(duration: 300.ms, curve: Curves.easeOut)
                            .slideY(begin: 0.08, end: 0, duration: 300.ms, curve: Curves.easeOut),
                        childCount: jobs.length,
                      ),
                    ),
                  );
                },
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),

              // Recent jobs section
              SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'Vagas Recentes',
                  actionLabel: 'Ver todas',
                  onActionPressed: () {
                    ref.read(selectedJobTypeProvider.notifier).state = 'Todos';
                    ref.invalidate(recentJobsProvider);
                  },
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // Recent jobs grid
              recentAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: ShimmerLoading(itemCount: 4, isGrid: true),
                ),
                error: (_, __) => SliverToBoxAdapter(
                  child: ErrorState(
                    icon: Icons.cloud_off_rounded,
                    message: 'Erro ao carregar vagas recentes.',
                    onRetry: () => ref.invalidate(recentJobsProvider),
                  ),
                ),
                data: (jobs) {
                  if (jobs.isEmpty) {
                    return SliverToBoxAdapter(
                      child: _AnimatedEmptySection(
                        icon: Icons.schedule_rounded,
                        title: 'Nenhuma vaga recente',
                        subtitle: 'Vagas adicionadas recentemente aparecerão aqui',
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.68,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => JobCard(job: jobs[index])
                            .animate(delay: Duration(milliseconds: (index % 6) * 60))
                            .fadeIn(duration: 300.ms, curve: Curves.easeOut)
                            .slideY(begin: 0.08, end: 0, duration: 300.ms, curve: Curves.easeOut),
                        childCount: jobs.length,
                      ),
                    ),
                  );
                },
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),

              // Paginated "Mais Vagas" section (infinite scroll)
              ..._buildPaginatedJobs(),

              // Bottom padding for floating nav
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPaginatedJobs() {
    final paginatedState = ref.watch(paginatedJobsProvider);
    if (paginatedState.jobs.isEmpty && !paginatedState.isLoading) {
      return [];
    }

    return [
      SliverToBoxAdapter(
        child: SectionHeader(
          title: 'Mais Vagas',
          actionLabel: '',
          onActionPressed: () {},
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: 12)),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.68,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index >= paginatedState.jobs.length) return null;
              return JobCard(job: paginatedState.jobs[index])
                  .animate(delay: Duration(milliseconds: (index % 6) * 60))
                  .fadeIn(duration: 300.ms, curve: Curves.easeOut)
                  .slideY(begin: 0.08, end: 0, duration: 300.ms, curve: Curves.easeOut);
            },
            childCount: paginatedState.jobs.length,
          ),
        ),
      ),
      if (paginatedState.isLoading)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ShimmerLoading(itemCount: 2, isGrid: true),
          ),
        ),
    ];
  }

  void _showFilterBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _JobFilterSheet(),
    );
  }
}

class _JobCategoryChips extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectedType = ref.watch(selectedJobTypeProvider);

    // Hide if only "Todos" would show (shouldn't happen, but guard)
    if (jobTypeCategories.length <= 1) return const SizedBox.shrink();

    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 16, right: 16, top: 8),
        itemCount: jobTypeCategories.length,
        itemBuilder: (context, index) {
          final category = jobTypeCategories[index];
          final isSelected = category == selectedType;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(category),
              selected: isSelected,
              showCheckmark: false,
              onSelected: (selected) {
                if (selected) {
                  HapticFeedback.selectionClick();
                  ref.read(selectedJobTypeProvider.notifier).state = category;
                  ref.invalidate(featuredJobsProvider);
                  ref.invalidate(recentJobsProvider);
                }
              },
              backgroundColor: theme.colorScheme.surface,
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected
                    ? AppColors.primary
                    : theme.colorScheme.outline.withAlpha(50),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Animated empty section for when a job category returns no data
class _AnimatedEmptySection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _AnimatedEmptySection({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
        child: Column(
          children: [
            Icon(
              icon,
              size: 80,
              color: AppColors.border,
            ).animate().scale(
                  duration: 600.ms,
                  curve: Curves.elasticOut,
                ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 500.ms, duration: 400.ms),
          ],
        ),
      ),
    );
  }
}

class _JobFilterSheet extends ConsumerStatefulWidget {
  const _JobFilterSheet();

  @override
  ConsumerState<_JobFilterSheet> createState() => _JobFilterSheetState();
}

class _JobFilterSheetState extends ConsumerState<_JobFilterSheet> {
  String _jobType = 'Todos';
  String _workMode = 'Todos';
  String _sortBy = 'recent';

  @override
  void initState() {
    super.initState();
    final filters = ref.read(jobFiltersProvider);
    if (filters.jobType != null) {
      // Reverse map API value to display
      for (final cat in jobTypeCategories) {
        if (jobTypeCategoryToValue(cat) == filters.jobType) {
          _jobType = cat;
          break;
        }
      }
    }
    if (filters.workMode != null) {
      for (final cat in workModeCategories) {
        if (workModeCategoryToValue(cat) == filters.workMode) {
          _workMode = cat;
          break;
        }
      }
    }
    _sortBy = filters.sortBy;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filtros',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _jobType = 'Todos';
                        _workMode = 'Todos';
                        _sortBy = 'recent';
                      });
                    },
                    child: const Text('Limpar'),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Job type
                  Text(
                    'Tipo de Vaga',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: jobTypeCategories.map((type) {
                      final isSelected = type == _jobType;
                      return ChoiceChip(
                        label: Text(type),
                        selected: isSelected,
                        showCheckmark: false,
                        onSelected: (selected) {
                          if (selected) setState(() => _jobType = type);
                        },
                        backgroundColor: theme.colorScheme.surface,
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.primary
                              : theme.colorScheme.outline.withAlpha(50),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // Work mode
                  Text(
                    'Modo de Trabalho',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: workModeCategories.map((mode) {
                      final isSelected = mode == _workMode;
                      return ChoiceChip(
                        label: Text(mode),
                        selected: isSelected,
                        showCheckmark: false,
                        onSelected: (selected) {
                          if (selected) setState(() => _workMode = mode);
                        },
                        backgroundColor: theme.colorScheme.surface,
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.primary
                              : theme.colorScheme.outline.withAlpha(50),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // Sort by
                  Text(
                    'Ordenar por',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: {
                      'recent': 'Mais recentes',
                      'price_desc': 'Maior salário',
                      'price_asc': 'Menor salário',
                    }.entries.map((e) {
                      final isSelected = _sortBy == e.key;
                      return ChoiceChip(
                        label: Text(e.value),
                        selected: isSelected,
                        showCheckmark: false,
                        onSelected: (selected) {
                          if (selected) setState(() => _sortBy = e.key);
                        },
                        backgroundColor: theme.colorScheme.surface,
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                        side: BorderSide(
                          color: isSelected
                              ? AppColors.primary
                              : theme.colorScheme.outline.withAlpha(50),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            // Apply button
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  onPressed: () {
                    final jobTypeValue = _jobType != 'Todos' ? jobTypeCategoryToValue(_jobType) : null;
                    final workModeValue = _workMode != 'Todos' ? workModeCategoryToValue(_workMode) : null;

                    ref.read(jobFiltersProvider.notifier).state = JobFilters(
                      jobType: jobTypeValue,
                      workMode: workModeValue,
                      sortBy: _sortBy,
                    );

                    ref.invalidate(featuredJobsProvider);
                    ref.invalidate(recentJobsProvider);
                    ref.read(paginatedJobsProvider.notifier).refresh();
                    Navigator.pop(context);
                  },
                  child: const Text('Aplicar filtros'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
