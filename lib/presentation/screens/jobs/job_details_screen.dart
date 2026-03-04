import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/product_model.dart';
import '../../providers/auth_providers.dart';
import '../../providers/job_application_provider.dart';
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

  Future<void> _launchEmail(String email) async {
    final uri = Uri(scheme: 'mailto', path: email, queryParameters: {
      'subject': 'Candidatura: ${job.name}',
    });
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final typeColor = _jobTypeColor(job.jobType);
    final hasEmail = job.contactEmail != null && job.contactEmail!.isNotEmpty;
    final hasPhone = job.contactPhone != null && job.contactPhone!.isNotEmpty;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // AppBar with glass-style back button
          SliverAppBar(
            expandedHeight: job.images.isNotEmpty ? 200 : 120,
            pinned: true,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: _GlassIconButton(
                icon: Icons.arrow_back,
                onPressed: () => context.pop(),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: job.images.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: job.images.first.url,
                      fit: BoxFit.cover,
                      color: Colors.black.withAlpha(60),
                      colorBlendMode: BlendMode.darken,
                    )
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [typeColor, typeColor.withAlpha(180)],
                        ),
                      ),
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
                  // Company name (with fallback)
                  Text(
                    job.companyName?.isNotEmpty == true
                        ? job.companyName!
                        : 'Empresa não informada',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),
                  const SizedBox(height: 4),

                  // Job title
                  Text(
                    job.name,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ).animate().fadeIn(duration: 300.ms, delay: 50.ms).slideY(begin: 0.1, end: 0),
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
                  ).animate().fadeIn(duration: 300.ms, delay: 100.ms),

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
                          style: theme.textTheme.headlineMedium?.copyWith(
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
                  ).animate().fadeIn(duration: 300.ms, delay: 150.ms).slideY(begin: 0.05, end: 0),

                  const SizedBox(height: 20),

                  // Seller profile link
                  if (job.tenantId.isNotEmpty)
                    InkWell(
                      onTap: () => context.push('/seller-profile/${job.tenantId}'),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: typeColor.withAlpha(40),
                              child: Icon(Icons.business, color: typeColor, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    job.companyName ?? 'Ver perfil da empresa',
                                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    'Ver todas as vagas e avaliações',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(duration: 300.ms, delay: 200.ms),

                  if (job.tenantId.isNotEmpty) const SizedBox(height: 20),

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
                    ...job.requirements.asMap().entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle_outline, size: 18, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.value,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 200.ms, delay: (300 + entry.key * 50).ms)),
                    const SizedBox(height: 20),
                  ],

                  // Benefits
                  if (job.benefits.isNotEmpty) ...[
                    Text(
                      'Benefícios',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...job.benefits.asMap().entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.star_outline_rounded, size: 18, color: AppColors.warning),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.value,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 200.ms, delay: (300 + entry.key * 50).ms)),
                    const SizedBox(height: 20),
                  ],

                  // Contact info — now interactive
                  if (hasEmail || hasPhone) ...[
                    Text(
                      'Contato',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (hasEmail)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.email_outlined, color: AppColors.primary),
                        title: Text(job.contactEmail!),
                        subtitle: const Text('Toque para enviar e-mail', style: TextStyle(fontSize: 11)),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _launchEmail(job.contactEmail!);
                        },
                      ),
                    if (hasPhone)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.phone_outlined, color: AppColors.primary),
                        title: Text(job.contactPhone!),
                        subtitle: const Text('Toque para ligar', style: TextStyle(fontSize: 11)),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _launchPhone(job.contactPhone!);
                        },
                      ),
                  ],

                  // Bottom padding for action bar
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),

      // Bottom CTA action bar
      bottomNavigationBar: _JobBottomBar(
        job: job,
        typeColor: typeColor,
        hasEmail: hasEmail,
        hasPhone: hasPhone,
      ),
    );
  }
}

class _JobBottomBar extends ConsumerWidget {
  final ProductModel job;
  final Color typeColor;
  final bool hasEmail;
  final bool hasPhone;

  const _JobBottomBar({
    required this.job,
    required this.typeColor,
    required this.hasEmail,
    required this.hasPhone,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isAuth = ref.watch(isAuthenticatedProvider);
    final hasApplied = ref.watch(hasAppliedProvider(job.id)).valueOrNull ?? false;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          // WhatsApp button (if phone available)
          if (hasPhone)
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFF25D366).withAlpha(80),
                ),
                borderRadius: BorderRadius.circular(12),
                color: const Color(0xFF25D366).withAlpha(15),
              ),
              child: IconButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  _launchWhatsApp(job.contactPhone!, job.name);
                },
                icon: const Icon(
                  Icons.chat,
                  color: Color(0xFF25D366),
                ),
                tooltip: 'WhatsApp',
              ),
            ),
          if (hasPhone) const SizedBox(width: 12),

          // Primary CTA: in-app apply
          Expanded(
            child: FilledButton.icon(
              onPressed: hasApplied
                  ? null
                  : () {
                      HapticFeedback.mediumImpact();
                      if (!isAuth) {
                        context.push('/login?redirect=/job/${job.id}');
                        return;
                      }
                      _showApplySheet(context, ref, job);
                    },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: hasApplied ? Colors.grey : typeColor,
              ),
              icon: Icon(hasApplied ? Icons.check : Icons.send),
              label: Text(
                hasApplied ? 'Candidatura enviada' : 'Candidatar-se',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void _launchWhatsApp(String phone, String jobTitle) {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final message = Uri.encodeComponent(
      'Olá! Vi a vaga "$jobTitle" e gostaria de mais informações.',
    );
    launchUrl(Uri.parse('https://wa.me/$cleanPhone?text=$message'));
  }

  static void _showApplySheet(BuildContext context, WidgetRef ref, ProductModel job) {
    final coverLetterCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Candidatar-se',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                job.name,
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Telefone para contato (opcional)',
                  prefixIcon: Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: coverLetterCtrl,
                decoration: const InputDecoration(
                  labelText: 'Carta de apresentação (opcional)',
                  hintText: 'Conte um pouco sobre você e sua experiência...',
                  prefixIcon: Icon(Icons.description_outlined),
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                maxLength: 3000,
              ),
              const SizedBox(height: 20),
              Consumer(builder: (ctx2, ref2, _) {
                final appState = ref2.watch(jobApplicationNotifierProvider);
                return SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: appState.isLoading
                        ? null
                        : () async {
                            final success = await ref2
                                .read(jobApplicationNotifierProvider.notifier)
                                .apply(
                                  jobId: job.id,
                                  coverLetter: coverLetterCtrl.text.trim().isEmpty
                                      ? null
                                      : coverLetterCtrl.text.trim(),
                                  applicantPhone: phoneCtrl.text.trim().isEmpty
                                      ? null
                                      : phoneCtrl.text.trim(),
                                );
                            if (success && ctx2.mounted) {
                              Navigator.of(ctx2).pop();
                              ScaffoldMessenger.of(ctx2).showSnackBar(
                                const SnackBar(
                                  content: Text('Candidatura enviada com sucesso!'),
                                  backgroundColor: AppColors.secondary,
                                ),
                              );
                            } else if (!success && ctx2.mounted) {
                              ScaffoldMessenger.of(ctx2).showSnackBar(
                                SnackBar(
                                  content: Text(appState.error ?? 'Erro ao enviar candidatura'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: appState.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Enviar candidatura',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _GlassIconButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withAlpha(80),
      shape: const CircleBorder(
        side: BorderSide(color: Colors.white24),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}
