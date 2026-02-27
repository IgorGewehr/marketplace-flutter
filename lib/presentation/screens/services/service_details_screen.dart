import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/auth_providers.dart';
import '../../providers/chat_provider.dart';
import '../../providers/services_provider.dart';
import '../../widgets/products/image_carousel.dart';
import '../../widgets/shared/loading_overlay.dart';

/// Service details screen
class ServiceDetailsScreen extends ConsumerStatefulWidget {
  final String serviceId;

  const ServiceDetailsScreen({super.key, required this.serviceId});

  @override
  ConsumerState<ServiceDetailsScreen> createState() => _ServiceDetailsScreenState();
}

class _ServiceDetailsScreenState extends ConsumerState<ServiceDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isNavigatingToChat = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _requestQuote() async {
    final service = ref.read(serviceDetailProvider(widget.serviceId)).valueOrNull;
    if (service == null) return;
    await _navigateToChat(service.tenantId);
  }

  Future<void> _contactProvider() async {
    final service = ref.read(serviceDetailProvider(widget.serviceId)).valueOrNull;
    if (service == null) return;
    await _navigateToChat(service.tenantId);
  }

  Future<void> _navigateToChat(String tenantId) async {
    if (_isNavigatingToChat) return;
    final isAuth = ref.read(isAuthenticatedProvider);
    if (!isAuth) {
      context.push('${AppRouter.login}?redirect=/service/${widget.serviceId}');
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
    final serviceAsync = ref.watch(serviceDetailProvider(widget.serviceId));

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: serviceAsync.when(
        loading: () => const Center(child: LoadingIndicator()),
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
              const Text('Erro ao carregar serviço'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(serviceDetailProvider(widget.serviceId)),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
        data: (service) {
          if (service == null) {
            return const Center(child: Text('Serviço não encontrado'));
          }

          return CustomScrollView(
            slivers: [
              // App bar
              SliverAppBar(
                pinned: true,
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                leading: IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back),
                ),
                actions: [
                  IconButton(
                    onPressed: () {
                      ref.read(favoriteServiceIdsProvider.notifier).toggleFavorite(service.id);
                    },
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(230),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        ref.watch(isServiceFavoriteProvider(service.id))
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: ref.watch(isServiceFavoriteProvider(service.id))
                            ? Colors.red
                            : null,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      // Share service
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
                  images: service.images.map((i) => i.url).toList(),
                  height: 350,
                ),
              ),

              // Service info
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and badges
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              service.name,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (service.isRemote)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.laptop_mac,
                                    size: 14,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Remoto',
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Rating and stats
                      Row(
                        children: [
                          if (service.rating > 0) ...[
                            const Icon(Icons.star, color: Colors.amber, size: 20),
                            const SizedBox(width: 4),
                            Text(
                              service.rating.toStringAsFixed(1),
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '(${service.reviewCount} avaliações)',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 16),
                          ],
                          if (service.completedJobs > 0) ...[
                            Icon(
                              Icons.check_circle_outline,
                              size: 18,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${service.completedJobs} trabalhos',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Price
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
                              Icons.payments_outlined,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    service.pricingDisplay,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  if (service.duration != null)
                                    Text(
                                      'Duração: ${service.duration!.displayText}',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Tabs
                      TabBar(
                        controller: _tabController,
                        tabs: const [
                          Tab(text: 'Sobre'),
                          Tab(text: 'Portfólio'),
                          Tab(text: 'Prestador'),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Tab content
                      SizedBox(
                        height: 400,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            // About tab
                            _AboutTab(service: service),

                            // Portfolio tab
                            _PortfolioTab(service: service),

                            // Provider tab
                            _ProviderTab(service: service),
                          ],
                        ),
                      ),

                      // Bottom padding for action buttons
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),

      // Bottom action buttons
      bottomNavigationBar: serviceAsync.when(
        loading: () => null,
        error: (_, __) => null,
        data: (service) {
          if (service == null) return null;

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
                // Chat with provider
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: theme.colorScheme.outline.withAlpha(50),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    onPressed: _isNavigatingToChat ? null : _contactProvider,
                    icon: _isNavigatingToChat
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chat_bubble_outline),
                  ),
                ),
                const SizedBox(width: 12),

                // Request quote / Instant booking
                Expanded(
                  child: FilledButton(
                    onPressed: _isNavigatingToChat
                        ? null
                        : (service.instantBooking ? _contactProvider : _requestQuote),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: theme.colorScheme.primary,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          service.instantBooking
                              ? Icons.event_available
                              : Icons.description_outlined,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          service.instantBooking ? 'Agendar agora' : 'Solicitar orçamento',
                        ),
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

class _AboutTab extends StatelessWidget {
  final service;

  const _AboutTab({required this.service});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description
          Text(
            service.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),

          if (service.includes.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'O que está incluso',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...service.includes.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                )),
          ],

          if (service.requirements.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Requisitos',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...service.requirements.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                )),
          ],

          if (service.certifications.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Certificações',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: service.certifications.map<Widget>((cert) {
                return Chip(
                  label: Text(cert),
                  avatar: const Icon(Icons.verified, size: 16),
                );
              }).toList(),
            ),
          ],

          if (service.serviceAreas.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Áreas de atendimento',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: service.serviceAreas.map<Widget>((area) {
                return Chip(
                  label: Text(area.displayName),
                  avatar: const Icon(Icons.location_on, size: 16),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _PortfolioTab extends StatelessWidget {
  final service;

  const _PortfolioTab({required this.service});

  @override
  Widget build(BuildContext context) {
    if (service.portfolioImages.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('Nenhuma imagem de portfólio disponível'),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: service.portfolioImages.length,
      itemBuilder: (context, index) {
        final image = service.portfolioImages[index];
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            image.url,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: Colors.grey[200],
              child: const Icon(Icons.broken_image, color: Colors.grey),
            ),
          ),
        );
      },
    );
  }
}

class _ProviderTab extends StatelessWidget {
  final service;

  const _ProviderTab({required this.service});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = service.marketplaceStats;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Provider info card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: theme.colorScheme.primary,
                  child: Text(
                    service.tenantId[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Prestador de Serviços',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (service.experience != null)
                        Text(
                          service.experience!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Statistics
          if (stats != null) ...[
            Text(
              'Estatísticas',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.work_outline,
                    label: 'Trabalhos',
                    value: stats.completedJobs.toString(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.star_outline,
                    label: 'Avaliação',
                    value: stats.rating.toStringAsFixed(1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (stats.responseTime != null)
              _StatCard(
                icon: Icons.speed,
                label: 'Tempo de resposta',
                value: '${stats.responseTime!.round()}h',
              ),
          ],
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
