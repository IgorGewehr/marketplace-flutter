import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/product_model.dart';
import '../../../data/models/tenant_model.dart';
import '../../providers/auth_providers.dart';
import '../../providers/chat_provider.dart';
import '../../providers/products_provider.dart';
import '../../providers/rentals_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../widgets/products/image_carousel.dart';
import '../../widgets/shared/loading_overlay.dart';
import '../../widgets/shared/whatsapp_button.dart';

/// Rental details screen — shows full rental listing info with contact actions
class RentalDetailsScreen extends ConsumerStatefulWidget {
  final String productId;

  const RentalDetailsScreen({super.key, required this.productId});

  @override
  ConsumerState<RentalDetailsScreen> createState() => _RentalDetailsScreenState();
}

class _RentalDetailsScreenState extends ConsumerState<RentalDetailsScreen> {
  bool _isNavigatingToChat = false;

  Future<void> _navigateToChat(String tenantId) async {
    if (_isNavigatingToChat) return;
    final isAuth = ref.read(isAuthenticatedProvider);
    if (!isAuth) {
      context.push('/login?redirect=/rental/${widget.productId}');
      return;
    }
    setState(() => _isNavigatingToChat = true);
    try {
      final chat = await ref.read(chatsProvider.notifier).getOrCreateChat(tenantId);
      if (chat != null && mounted) {
        context.push('/chats/${chat.id}');
      }
    } finally {
      if (mounted) setState(() => _isNavigatingToChat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rentalAsync = ref.watch(productDetailProvider(widget.productId));

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: rentalAsync.when(
        loading: () => const _RentalDetailsSkeleton(),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              const Text('Erro ao carregar anúncio'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(productDetailProvider(widget.productId)),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
        data: (rental) {
          if (rental == null) {
            return const Center(child: Text('Anúncio não encontrado'));
          }

          return CustomScrollView(
            slivers: [
              // AppBar
              SliverAppBar(
                pinned: true,
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                leading: IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back),
                ),
                actions: [
                  // Favorite button
                  IconButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      ref.read(favoriteRentalIdsProvider.notifier).toggleFavorite(rental.id);
                    },
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(230),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        ref.watch(isRentalFavoriteProvider(rental.id))
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: ref.watch(isRentalFavoriteProvider(rental.id))
                            ? Colors.red
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  // Share button
                  IconButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      final period = rental.rentalInfo?.periodDisplayFull ?? '';
                      final price = rental.rentalPriceDisplay ?? 'R\$ ${rental.price.toStringAsFixed(2)}';
                      Share.share(
                        '${rental.name} — $price/$period\n\nVeja este anúncio no NexMarket!',
                      );
                    },
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(230),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.share),
                    ),
                  ),
                ],
              ),

              // Image carousel
              SliverToBoxAdapter(
                child: ImageCarousel(
                  images: rental.images.map((i) => i.url).toList(),
                  height: 300,
                ),
              ),

              // Rental info
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and rental type badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              rental.name,
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (rental.rentalInfo != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                rental.rentalInfo!.rentalTypeDisplay,
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),
                      const SizedBox(height: 16),

                      // Price and period
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withAlpha(100),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.primary.withAlpha(50),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.vpn_key_rounded,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    rental.rentalPriceDisplay ??
                                        'R\$ ${rental.price.toStringAsFixed(rental.price.truncateToDouble() == rental.price ? 0 : 2)}',
                                    style: theme.textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  if (rental.rentalInfo != null)
                                    Text(
                                      rental.rentalInfo!.periodDisplayFull,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (rental.rentalInfo?.deposit != null)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'Caução',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    'R\$ ${rental.rentalInfo!.deposit!.toStringAsFixed(rental.rentalInfo!.deposit!.truncateToDouble() == rental.rentalInfo!.deposit! ? 0 : 2)}',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 300.ms, delay: 100.ms).slideY(begin: 0.05, end: 0),
                      const SizedBox(height: 16),

                      // Availability badge
                      if (rental.rentalInfo != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: rental.rentalInfo!.isAvailable
                                ? Colors.green.withAlpha(25)
                                : Colors.red.withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: rental.rentalInfo!.isAvailable
                                  ? Colors.green.withAlpha(80)
                                  : Colors.red.withAlpha(80),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                rental.rentalInfo!.isAvailable
                                    ? Icons.check_circle_outline
                                    : Icons.cancel_outlined,
                                size: 16,
                                color: rental.rentalInfo!.isAvailable ? Colors.green : Colors.red,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                rental.rentalInfo!.isAvailable ? 'Disponível' : 'Indisponível',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: rental.rentalInfo!.isAvailable ? Colors.green : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(duration: 300.ms, delay: 150.ms),

                      // Availability notes
                      if (rental.rentalInfo?.availabilityNotes != null &&
                          rental.rentalInfo!.availabilityNotes!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          rental.rentalInfo!.availabilityNotes!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),

                      // Type-specific details section
                      if (rental.rentalInfo != null)
                        _RentalSpecificSection(rental: rental),

                      // Location
                      if (rental.location != null &&
                          rental.location!.formattedLocation.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        _SectionTitle(title: 'Localização'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 18,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                rental.location!.formattedLocation,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),

                      // Description section
                      if (rental.description.isNotEmpty) ...[
                        _SectionTitle(title: 'Sobre'),
                        const SizedBox(height: 12),
                        Text(
                          rental.description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ).animate().fadeIn(duration: 300.ms, delay: 200.ms),
                        const SizedBox(height: 24),
                      ],

                      // Tenant/owner section
                      _TenantSection(tenantId: rental.tenantId),

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),

      // Bottom action bar
      bottomNavigationBar: rentalAsync.when(
        loading: () => null,
        error: (_, __) => null,
        data: (rental) {
          if (rental == null) return null;

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
                // WhatsApp button (if phone available) or chat icon
                Consumer(
                  builder: (context, ref, _) {
                    final tenantAsync = ref.watch(tenantByIdProvider(rental.tenantId));
                    final tenant = tenantAsync.valueOrNull;
                    final phone = tenant?.whatsapp ?? tenant?.phone;

                    if (phone != null && phone.isNotEmpty) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF25D366),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              launchWhatsApp(
                                phoneNumber: phone,
                                message: 'Olá! Tenho interesse no anúncio: ${rental.name}',
                                context: context,
                              );
                            },
                            icon: const Icon(Icons.chat, color: Colors.white),
                            tooltip: 'Chamar no WhatsApp',
                          ),
                        ),
                      );
                    }

                    // Fallback: in-app chat icon
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: theme.colorScheme.outline.withAlpha(50),
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          onPressed: _isNavigatingToChat
                              ? null
                              : () => _navigateToChat(rental.tenantId),
                          icon: _isNavigatingToChat
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.chat_bubble_outline),
                        ),
                      ),
                    );
                  },
                ),

                // Main contact CTA
                Expanded(
                  child: FilledButton(
                    onPressed: _isNavigatingToChat
                        ? null
                        : () {
                            HapticFeedback.mediumImpact();
                            _navigateToChat(rental.tenantId);
                          },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: theme.colorScheme.primary,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.message_outlined, size: 20),
                        SizedBox(width: 8),
                        Text('Entrar em contato'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Type-specific section based on rentalType
class _RentalSpecificSection extends StatelessWidget {
  final ProductModel rental;

  const _RentalSpecificSection({required this.rental});

  @override
  Widget build(BuildContext context) {
    final ri = rental.rentalInfo!;

    if (ri.rentalType == 'imovel') {
      return _ImoveiSection(ri: ri);
    }
    if (ri.rentalType == 'veiculo') {
      return _VeiculoSection(ri: ri);
    }

    return const SizedBox.shrink();
  }
}

class _ImoveiSection extends StatelessWidget {
  final RentalInfo ri;

  const _ImoveiSection({required this.ri});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = <_DetailItem>[];

    if (ri.propertyType != null)
      items.add(_DetailItem(icon: Icons.home_outlined, label: 'Tipo', value: ri.propertyTypeDisplay));
    if (ri.bedrooms != null)
      items.add(_DetailItem(icon: Icons.bed_outlined, label: 'Quartos', value: '${ri.bedrooms}'));
    if (ri.bathrooms != null)
      items.add(_DetailItem(icon: Icons.bathtub_outlined, label: 'Banheiros', value: '${ri.bathrooms}'));
    if (ri.area != null)
      items.add(_DetailItem(icon: Icons.square_foot, label: 'Área', value: '${ri.area!.toStringAsFixed(0)} m²'));
    if (ri.furnished != null)
      items.add(_DetailItem(
        icon: ri.furnished! ? Icons.chair : Icons.chair_outlined,
        label: 'Mobiliado',
        value: ri.furnished! ? 'Sim' : 'Não',
      ));
    if (ri.petsAllowed != null)
      items.add(_DetailItem(
        icon: ri.petsAllowed! ? Icons.pets : Icons.no_food_outlined,
        label: 'Pets',
        value: ri.petsAllowed! ? 'Permitido' : 'Não permitido',
      ));

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: 'Detalhes do Imóvel'),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.1,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(item.icon, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(height: 4),
                  Text(
                    item.value,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    item.label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 24),
      ],
    ).animate().fadeIn(duration: 300.ms, delay: 180.ms);
  }
}

class _VeiculoSection extends StatelessWidget {
  final RentalInfo ri;

  const _VeiculoSection({required this.ri});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = <_DetailItem>[];

    if (ri.brand != null)
      items.add(_DetailItem(icon: Icons.branding_watermark_outlined, label: 'Marca', value: ri.brand!));
    if (ri.model != null)
      items.add(_DetailItem(icon: Icons.directions_car_outlined, label: 'Modelo', value: ri.model!));
    if (ri.year != null)
      items.add(_DetailItem(icon: Icons.calendar_today_outlined, label: 'Ano', value: '${ri.year}'));

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: 'Detalhes do Veículo'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items.map((item) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.icon, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        item.value,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
      ],
    ).animate().fadeIn(duration: 300.ms, delay: 180.ms);
  }
}

class _DetailItem {
  final IconData icon;
  final String label;
  final String value;

  const _DetailItem({required this.icon, required this.label, required this.value});
}

/// Section title widget
class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// Tenant/owner info section
class _TenantSection extends ConsumerWidget {
  final String tenantId;

  const _TenantSection({required this.tenantId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tenantAsync = ref.watch(tenantByIdProvider(tenantId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(title: 'Proprietário / Anunciante'),
        const SizedBox(height: 12),
        tenantAsync.when(
          loading: () => Shimmer.fromColors(
            baseColor: theme.colorScheme.surfaceContainerHighest,
            highlightColor: theme.colorScheme.surface,
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (tenant) {
            if (tenant == null) return const SizedBox.shrink();
            return _TenantCard(tenant: tenant);
          },
        ),
      ],
    );
  }
}

class _TenantCard extends StatelessWidget {
  final TenantModel tenant;

  const _TenantCard({required this.tenant});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Logo or initial avatar
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: tenant.logoURL != null && tenant.logoURL!.isNotEmpty
                ? Image.network(
                    tenant.logoURL!,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _TenantAvatar(name: tenant.displayName),
                  )
                : _TenantAvatar(name: tenant.displayName),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tenant.displayName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (tenant.isVerified)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.verified,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                  ],
                ),
                if (tenant.address?.city != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        [tenant.address!.city, tenant.address!.state]
                            .where((s) => s.isNotEmpty)
                            .join(' - '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
                if (tenant.rating > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 14, color: Colors.amber),
                      const SizedBox(width: 4),
                      Text(
                        tenant.rating.toStringAsFixed(1),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // View profile arrow
          IconButton(
            onPressed: () => context.push('/seller-profile/${tenant.id}'),
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Ver perfil',
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms, delay: 250.ms).slideY(begin: 0.05, end: 0);
  }
}

class _TenantAvatar extends StatelessWidget {
  final String name;

  const _TenantAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 28,
      backgroundColor: AppColors.primary,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Shimmer skeleton for the rental details page while loading
class _RentalDetailsSkeleton extends StatelessWidget {
  const _RentalDetailsSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.colorScheme.surfaceContainerHighest;
    final highlight = theme.colorScheme.surface;

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App bar placeholder
            Container(height: 56, color: base),

            // Image placeholder
            Container(height: 300, color: base),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Container(
                    height: 28,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: base,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 28,
                    width: 200,
                    decoration: BoxDecoration(
                      color: base,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Price card
                  Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: base,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Details row
                  Row(
                    children: List.generate(3, (_) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Container(
                          height: 70,
                          decoration: BoxDecoration(
                            color: base,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    )),
                  ),
                  const SizedBox(height: 24),

                  // Description lines
                  ...List.generate(4, (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      height: 14,
                      width: i % 3 == 2 ? 200 : double.infinity,
                      decoration: BoxDecoration(
                        color: base,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  )),
                  const SizedBox(height: 24),

                  // Tenant card
                  Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: base,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
