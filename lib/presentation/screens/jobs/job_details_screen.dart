import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/product_model.dart';
import '../../providers/products_provider.dart';

/// Job details screen — shows full job listing info with contact actions
class JobDetailsScreen extends ConsumerWidget {
  final String jobId;

  const JobDetailsScreen({super.key, required this.jobId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobAsync = ref.watch(productDetailProvider(jobId));
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: jobAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('Erro ao carregar vaga'),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => ref.invalidate(productDetailProvider(jobId)),
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
        data: (job) {
          if (job == null) {
            return const Center(child: Text('Vaga não encontrada'));
          }
          return _JobDetailsBody(job: job);
        },
      ),
    );
  }
}

class _JobDetailsBody extends StatelessWidget {
  final ProductModel job;

  const _JobDetailsBody({required this.job});

  Color _jobTypeColor(String? type) {
    switch (type) {
      case 'clt': return AppColors.jobClt;
      case 'pj': return AppColors.jobPj;
      case 'freelance': return AppColors.jobFreelance;
      case 'estagio': return AppColors.jobEstagio;
      case 'temporario': return AppColors.jobTemporario;
      default: return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeColor = _jobTypeColor(job.jobType);

    return CustomScrollView(
      slivers: [
        // AppBar
        SliverAppBar(
          expandedHeight: job.images.isNotEmpty ? 200 : 120,
          pinned: true,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          flexibleSpace: FlexibleSpaceBar(
            background: job.images.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: job.images.first.url,
                    fit: BoxFit.cover,
                    color: Colors.black.withAlpha(60),
                    colorBlendMode: BlendMode.darken,
                  )
                : Container(
                    color: AppColors.primary,
                    child: const Center(
                      child: Icon(Icons.work_rounded, size: 48, color: Colors.white70),
                    ),
                  ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Company name
                if (job.companyName != null && job.companyName!.isNotEmpty) ...[
                  Text(
                    job.companyName!,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],

                // Job title
                Text(
                  job.name,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                // Location + time
                Row(
                  children: [
                    if (job.location?.city != null) ...[
                      Icon(Icons.location_on_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        job.location!.formattedLocation,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Icon(Icons.schedule, size: 16, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      Formatters.relativeTime(job.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Salary card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withAlpha(40)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Salário',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        job.salaryDisplay,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Type + mode chips
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (job.jobType != null)
                            Chip(
                              label: Text(job.jobTypeLabel),
                              backgroundColor: typeColor.withAlpha(25),
                              labelStyle: TextStyle(color: typeColor, fontWeight: FontWeight.w600, fontSize: 12),
                              side: BorderSide(color: typeColor.withAlpha(60)),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                          if (job.workMode != null)
                            Chip(
                              label: Text(job.workModeLabel),
                              backgroundColor: theme.colorScheme.surfaceContainerHighest,
                              labelStyle: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                              side: BorderSide.none,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Description
                if (job.description.isNotEmpty) ...[
                  Text(
                    'Descrição',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    job.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Requirements
                if (job.requirements.isNotEmpty) ...[
                  Text(
                    'Requisitos',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...job.requirements.map((req) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_outline, size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            req,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
                  const SizedBox(height: 20),
                ],

                // Benefits
                if (job.benefits.isNotEmpty) ...[
                  Text(
                    'Benefícios',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...job.benefits.map((b) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.star_outline_rounded, size: 18, color: AppColors.warning),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            b,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
                  const SizedBox(height: 20),
                ],

                // Contact info
                if (job.contactEmail != null || job.contactPhone != null) ...[
                  Text(
                    'Contato',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (job.contactEmail != null && job.contactEmail!.isNotEmpty)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.email_outlined),
                      title: Text(job.contactEmail!),
                    ),
                  if (job.contactPhone != null && job.contactPhone!.isNotEmpty)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.phone_outlined),
                      title: Text(job.contactPhone!),
                    ),
                ],

                // Bottom padding for nav buttons
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
