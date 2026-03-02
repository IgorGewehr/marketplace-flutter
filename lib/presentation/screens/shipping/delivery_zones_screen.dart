import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/delivery_zone_model.dart';
import '../../providers/shipping_provider.dart';
import '../../widgets/shared/shimmer_loading.dart';

/// Informative screen listing all delivery zones and pickup points
class DeliveryZonesScreen extends ConsumerWidget {
  const DeliveryZonesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final zonesAsync = ref.watch(deliveryZonesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zonas de Entrega'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: zonesAsync.when(
        loading: () => _buildShimmer(),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              const Text('Erro ao carregar zonas de entrega'),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => ref.invalidate(deliveryZonesProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
        data: (zones) {
          if (zones.isEmpty) {
            return const Center(
              child: Text('Nenhuma zona de entrega configurada'),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: zones.length,
            itemBuilder: (context, index) {
              final zone = zones[index];
              return _ZoneCard(zone: zone)
                  .animate()
                  .fadeIn(delay: Duration(milliseconds: 60 * index), duration: 350.ms)
                  .slideY(begin: 0.1, curve: Curves.easeOut);
            },
          );
        },
      ),
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (_, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: ShimmerBox(
          width: double.infinity,
          height: 120,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _ZoneCard extends StatelessWidget {
  final DeliveryZoneModel zone;

  const _ZoneCard({required this.zone});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final tiers = <String>[];
    if (zone.scheduledAvailable) tiers.add('Entrega padrão');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      '${zone.sortOrder}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        zone.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (zone.description != null)
                        Text(
                          zone.description!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  Formatters.currency(zone.basePrice),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Available tiers
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: tiers.map((tier) => Chip(
                label: Text(tier, style: const TextStyle(fontSize: 11)),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                labelPadding: const EdgeInsets.symmetric(horizontal: 8),
              )).toList(),
            ),
            if (zone.freeDeliveryMinimum != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.local_offer_outlined, size: 14, color: theme.colorScheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    'Frete grátis acima de ${Formatters.currency(zone.freeDeliveryMinimum!)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
            if (zone.estimatedDelivery.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.schedule, size: 14, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    'Prazo: ${zone.estimatedDelivery}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
