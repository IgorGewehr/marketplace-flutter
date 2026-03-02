import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/product_model.dart';

/// Card widget for job listings — differentiated from ProductCard
class JobCard extends StatefulWidget {
  final ProductModel job;

  const JobCard({super.key, required this.job});

  @override
  State<JobCard> createState() => _JobCardState();
}

class _JobCardState extends State<JobCard> {
  bool _isPressed = false;

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
    final job = widget.job;
    final typeColor = _jobTypeColor(job.jobType);

    return AnimatedScale(
      scale: _isPressed ? 0.96 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeInOut,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          HapticFeedback.selectionClick();
          context.push('/job/${job.id}');
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border.withAlpha(40)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top section: image/placeholder with badge
              Expanded(
                flex: 3,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Image or placeholder
                    job.images.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: job.images.first.url,
                            fit: BoxFit.cover,
                            memCacheWidth: 400,
                            fadeInDuration: const Duration(milliseconds: 300),
                            errorWidget: (_, __, ___) => _JobPlaceholder(color: typeColor),
                          )
                        : _JobPlaceholder(color: typeColor),

                    // Job type badge (top-left)
                    if (job.jobType != null)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: typeColor,
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: typeColor.withAlpha(80),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            job.jobTypeLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.2, curve: Curves.easeOut),
                      ),

                    // Work mode badge (top-right)
                    if (job.workMode != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(150),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            job.workModeLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Info section
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Company name
                    if (job.companyName != null && job.companyName!.isNotEmpty)
                      Text(
                        job.companyName!,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 2),

                    // Job title
                    Text(
                      job.name,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),

                    // Salary
                    Row(
                      children: [
                        Icon(
                          Icons.attach_money_rounded,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            job.salaryDisplay,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    // Location
                    if (job.location?.city != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              _formatLocation(job.location!),
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Relative time
                    const SizedBox(height: 2),
                    Text(
                      Formatters.relativeTime(job.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant.withAlpha(180),
                      ),
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

  String _formatLocation(ProductLocation location) {
    final parts = <String>[];
    if (location.city != null) parts.add(location.city!);
    if (location.state != null) parts.add(location.state!);
    return parts.join(' - ');
  }
}

class _JobPlaceholder extends StatelessWidget {
  final Color color;

  const _JobPlaceholder({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color.withAlpha(25),
      child: Center(
        child: Icon(
          Icons.work_rounded,
          size: 40,
          color: color.withAlpha(120),
        ),
      ),
    );
  }
}
