import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/product_model.dart';
import '../../providers/job_application_provider.dart';
import '../../providers/my_products_provider.dart';

/// Provider that filters seller's products to only show jobs
final sellerJobsProvider = Provider.autoDispose<AsyncValue<List<ProductModel>>>((ref) {
  final productsAsync = ref.watch(myProductsProvider);
  return productsAsync.whenData(
    (products) => products.where((p) => p.isJob).toList(),
  );
});

class SellerJobsScreen extends ConsumerWidget {
  const SellerJobsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final jobsAsync = ref.watch(sellerJobsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Vagas'),
        actions: [
          IconButton(
            onPressed: () => context.push('/seller/products/new?type=job'),
            icon: const Icon(Icons.add),
            tooltip: 'Criar vaga',
          ),
        ],
      ),
      body: jobsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              const Text('Erro ao carregar vagas'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(myProductsProvider),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
        data: (jobs) {
          if (jobs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.work_off_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Nenhuma vaga publicada',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Crie sua primeira vaga de emprego',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => context.push('/seller/products/new?type=job'),
                    icon: const Icon(Icons.add),
                    label: const Text('Criar Vaga'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: jobs.length,
            itemBuilder: (context, index) {
              final job = jobs[index];
              return _SellerJobCard(job: job)
                  .animate(delay: Duration(milliseconds: index * 60))
                  .fadeIn(duration: 300.ms)
                  .slideY(begin: 0.05, end: 0, duration: 300.ms);
            },
          );
        },
      ),
    );
  }
}

class _SellerJobCard extends ConsumerWidget {
  final ProductModel job;

  const _SellerJobCard({required this.job});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final applicationsAsync = ref.watch(jobApplicationsForJobProvider(job.id));
    final applicationCount = applicationsAsync.valueOrNull?.length ?? 0;
    final pendingCount = applicationsAsync.valueOrNull
            ?.where((a) => a.isPending)
            .length ??
        0;

    final isActive = job.status == 'active';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/job/${job.id}'),
        onLongPress: () {
          HapticFeedback.mediumImpact();
          context.push('/seller/products/${job.id}/edit');
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title + status
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      job.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.secondary.withAlpha(20) : Colors.grey.withAlpha(20),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isActive ? 'Ativa' : 'Pausada',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isActive ? AppColors.secondary : Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Job type + work mode
              Row(
                children: [
                  if (job.jobType != null)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.sellerAccent.withAlpha(15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        job.jobTypeLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.sellerAccent,
                        ),
                      ),
                    ),
                  if (job.workMode != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.blue.withAlpha(15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        job.workModeLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Applications count
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$applicationCount candidatura${applicationCount == 1 ? '' : 's'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (pendingCount > 0) ...[
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$pendingCount nova${pendingCount == 1 ? '' : 's'}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    TextButton(
                      onPressed: () => _showApplications(context, ref, job),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Ver candidaturas'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showApplications(BuildContext context, WidgetRef ref, ProductModel job) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text(
                  'Candidaturas — ${job.name}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                child: Consumer(builder: (ctx2, ref2, _) {
                  final appsAsync = ref2.watch(jobApplicationsForJobProvider(job.id));
                  return appsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (_, __) => const Center(child: Text('Erro ao carregar candidaturas')),
                    data: (apps) {
                      if (apps.isEmpty) {
                        return const Center(
                          child: Text('Nenhuma candidatura recebida'),
                        );
                      }
                      return ListView.separated(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.all(16),
                        itemCount: apps.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final app = apps[i];
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            leading: CircleAvatar(
                              backgroundColor: app.isPending
                                  ? Colors.amber.withAlpha(30)
                                  : app.isAccepted
                                      ? Colors.green.withAlpha(30)
                                      : Colors.grey.withAlpha(30),
                              child: Icon(
                                app.isPending
                                    ? Icons.hourglass_top
                                    : app.isAccepted
                                        ? Icons.check
                                        : Icons.close,
                                color: app.isPending
                                    ? Colors.amber
                                    : app.isAccepted
                                        ? Colors.green
                                        : Colors.grey,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              app.applicantName.isNotEmpty ? app.applicantName : app.applicantEmail,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (app.applicantEmail.isNotEmpty)
                                  Text(app.applicantEmail, style: const TextStyle(fontSize: 12)),
                                if (app.coverLetter != null)
                                  Text(
                                    app.coverLetter!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                            trailing: app.isPending
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        onPressed: () async {
                                          await ref2
                                              .read(jobApplicationNotifierProvider.notifier)
                                              .updateStatus(
                                                applicationId: app.id,
                                                status: 'accepted',
                                                jobId: job.id,
                                              );
                                        },
                                        icon: const Icon(Icons.check_circle, color: Colors.green),
                                        tooltip: 'Aceitar',
                                      ),
                                      IconButton(
                                        onPressed: () async {
                                          await ref2
                                              .read(jobApplicationNotifierProvider.notifier)
                                              .updateStatus(
                                                applicationId: app.id,
                                                status: 'rejected',
                                                jobId: job.id,
                                              );
                                        },
                                        icon: const Icon(Icons.cancel, color: Colors.red),
                                        tooltip: 'Rejeitar',
                                      ),
                                    ],
                                  )
                                : Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: app.isAccepted
                                          ? Colors.green.withAlpha(20)
                                          : Colors.grey.withAlpha(20),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      app.statusLabel,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: app.isAccepted ? Colors.green : Colors.grey,
                                      ),
                                    ),
                                  ),
                          );
                        },
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
