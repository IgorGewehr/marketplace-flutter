import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/tenant_model.dart';
import '../../providers/auth_providers.dart';
import '../../providers/chat_provider.dart';
import '../../providers/core_providers.dart';
import '../../providers/follows_provider.dart';
import '../../providers/products_provider.dart';
import '../../providers/review_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../widgets/products/product_card.dart';
import '../../widgets/reviews/reviews_bottom_sheet.dart';
import '../../widgets/shared/app_feedback.dart';
import '../../widgets/shared/whatsapp_button.dart';

/// Public seller profile screen showing seller info and their products.
/// When viewed by the tenant owner, also shows a WhatsApp configuration section.
class SellerProfileScreen extends ConsumerStatefulWidget {
  final String tenantId;

  const SellerProfileScreen({super.key, required this.tenantId});

  @override
  ConsumerState<SellerProfileScreen> createState() => _SellerProfileScreenState();
}

class _SellerProfileScreenState extends ConsumerState<SellerProfileScreen> {
  late final TextEditingController _whatsappController;
  bool _whatsappEnabled = false;
  bool _isSavingWhatsApp = false;
  bool _isOpeningChat = false;

  bool _whatsappInitialized = false;

  @override
  void initState() {
    super.initState();
    _whatsappController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final tenant = ref.read(tenantByIdProvider(widget.tenantId)).valueOrNull;
      if (tenant != null) {
        _initWhatsappFromTenant(tenant);
      }
    });
  }

  void _initWhatsappFromTenant(dynamic tenant) {
    if (_whatsappInitialized) return;
    _whatsappInitialized = true;
    if (tenant.whatsapp != null && tenant.whatsapp!.isNotEmpty) {
      _whatsappController.text = tenant.whatsapp!;
      setState(() => _whatsappEnabled = true);
    }
  }

  @override
  void dispose() {
    _whatsappController.dispose();
    super.dispose();
  }

  Future<void> _saveWhatsApp() async {
    final number = _whatsappController.text.trim();
    if (_whatsappEnabled && number.isEmpty) {
      AppFeedback.showError(context, 'Informe o número do WhatsApp');
      return;
    }

    setState(() => _isSavingWhatsApp = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.patch<Map<String, dynamic>>(
        ApiConstants.sellerProfile,
        data: {
          'whatsappNumber': _whatsappEnabled ? number : null,
          'whatsappEnabled': _whatsappEnabled,
        },
      );
      ref.invalidate(tenantByIdProvider(tenantId));
      if (mounted) {
        FocusScope.of(context).unfocus();
        AppFeedback.showSuccess(context, 'WhatsApp salvo com sucesso!');
      }
    } catch (_) {
      if (mounted) AppFeedback.showError(context, 'Erro ao salvar. Tente novamente.');
    } finally {
      if (mounted) setState(() => _isSavingWhatsApp = false);
    }
  }

  String get tenantId => widget.tenantId;

  @override
  Widget build(BuildContext context) {
    final tenantAsync = ref.watch(tenantByIdProvider(tenantId));
    final productsAsync = ref.watch(sellerProductsProvider(tenantId));
    final isFollowing = ref.watch(followsProvider).contains(tenantId);
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final isOwner = currentUser?.tenantId == tenantId;
    final theme = Theme.of(context);
    final canPop = Navigator.canPop(context);

    // Initialize WhatsApp field once tenant data is loaded (handled via ref.listen)
    ref.listen<AsyncValue<dynamic>>(tenantByIdProvider(tenantId), (_, next) {
      final t = next.valueOrNull;
      if (t != null) _initWhatsappFromTenant(t);
    });

    // Fetch owner user data from users/{ownerUserId}
    final tenant = tenantAsync.valueOrNull;
    final ownerUserAsync = ref.watch(userByIdProvider(tenant?.ownerUserId ?? ''));
    final ownerUser = ownerUserAsync.valueOrNull;

    return Scaffold(
      body: tenantAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Scaffold(
          appBar: AppBar(
            leading: canPop
                ? const BackButton()
                : IconButton(
                    icon: const Icon(Icons.home_outlined),
                    onPressed: () => context.go(AppRouter.home),
                  ),
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline,
                    size: 64, color: theme.colorScheme.outline),
                const SizedBox(height: 16),
                const Text('Erro ao carregar perfil do vendedor'),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(tenantByIdProvider(tenantId)),
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        ),
        data: (tenant) {
          if (tenant == null) {
            return const Center(child: Text('Vendedor não encontrado'));
          }

          return CustomScrollView(
            slivers: [
              // App Bar with seller avatar and name
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                // A15: Always provide a leading button — back if possible, home otherwise
                leading: canPop
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.home_outlined, color: Colors.white),
                        onPressed: () => context.go(AppRouter.home),
                      ),
                actions: [
                  if (isOwner)
                    IconButton(
                      onPressed: () =>
                          context.push(AppRouter.sellerEditProfile),
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: Colors.white,
                      ),
                      tooltip: 'Editar perfil da loja',
                    ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.primary.withAlpha(200),
                        ],
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 48, 24, 16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Avatar — tenant logo → owner photoURL → initial
                            CircleAvatar(
                              radius: 40,
                              backgroundImage: tenant.logoURL != null
                                  ? NetworkImage(tenant.logoURL!)
                                  : ownerUser?.photoURL != null
                                      ? NetworkImage(ownerUser!.photoURL!)
                                      : null,
                              backgroundColor: Colors.white.withAlpha(30),
                              child: tenant.logoURL == null && ownerUser?.photoURL == null
                                  ? Text(
                                      tenant.displayName.isNotEmpty
                                          ? tenant.displayName[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(height: 12),

                            // Name + verified badge
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    tenant.displayName,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (tenant.isVerified) ...[
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.verified,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ],
                              ],
                            ),

                            // Location
                            if (tenant.address?.city != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.location_on_outlined,
                                    size: 14,
                                    color: Colors.white70,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${tenant.address!.city} - ${tenant.address!.state}',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Stats row
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _StatItem(
                        icon: Icons.star_rounded,
                        value: tenant.rating > 0
                            ? tenant.rating.toStringAsFixed(1)
                            : '-',
                        label: 'Avaliação',
                        color: AppColors.rating,
                      ),
                      const SizedBox(width: 12),
                      _StatItem(
                        icon: Icons.shopping_bag_outlined,
                        value: '${tenant.marketplace?.totalSales ?? 0}',
                        label: 'Vendas',
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      _StatItem(
                        icon: Icons.rate_review_outlined,
                        value: '${tenant.marketplace?.totalReviews ?? 0}',
                        label: 'Avaliações',
                        color: AppColors.sellerAccent,
                      ),
                    ],
                  ),
                ),
              ),

              // A16: Follow seller button
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: isFollowing
                        ? FilledButton.tonal(
                            onPressed: () {
                              ref.read(followsProvider.notifier).toggleFollow(tenantId);
                              AppFeedback.showSuccess(
                                context,
                                'Você deixou de seguir ${tenant.displayName}',
                              );
                            },
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check, size: 18),
                                SizedBox(width: 6),
                                Text('Seguindo'),
                              ],
                            ),
                          )
                        : OutlinedButton.icon(
                            onPressed: () {
                              ref.read(followsProvider.notifier).toggleFollow(tenantId);
                              AppFeedback.showSuccess(
                                context,
                                'Agora você está seguindo ${tenant.displayName}',
                              );
                            },
                            icon: const Icon(Icons.person_add_outlined, size: 18),
                            label: const Text('Seguir'),
                          ),
                  ),
                ),
              ),

              // Description
              if (tenant.description != null &&
                  tenant.description!.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      tenant.description!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),

              // Seller reviews button
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: _SellerReviewsButton(tenantId: tenantId, tenant: tenant),
                ),
              ),

              // Owner personal info — from users/{ownerUserId}
              if (ownerUser != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundImage: ownerUser.photoURL != null
                                ? NetworkImage(ownerUser.photoURL!)
                                : null,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            child: ownerUser.photoURL == null
                                ? Text(
                                    ownerUser.displayName.isNotEmpty
                                        ? ownerUser.displayName[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ownerUser.displayName,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Proprietário(a)',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Desde ${ownerUser.createdAt.year}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Contact info — phone and email from tenant
              if ((tenant.phone != null && tenant.phone!.isNotEmpty) ||
                  (tenant.email != null && tenant.email!.isNotEmpty))
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Contato',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (tenant.phone != null && tenant.phone!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Icon(Icons.phone_outlined,
                                    size: 16,
                                    color: theme.colorScheme.onSurfaceVariant),
                                const SizedBox(width: 8),
                                Text(
                                  tenant.phone!,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        if (tenant.email != null && tenant.email!.isNotEmpty)
                          Row(
                            children: [
                              Icon(Icons.email_outlined,
                                  size: 16,
                                  color: theme.colorScheme.onSurfaceVariant),
                              const SizedBox(width: 8),
                              Text(
                                tenant.email!,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),

              // Delivery options
              if (tenant.marketplace?.deliveryOptions.isNotEmpty == true)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Formas de Entrega',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: tenant.marketplace!.deliveryOptions
                              .map((opt) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primaryContainer
                                          .withAlpha(80),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: theme.colorScheme.primary
                                            .withAlpha(40),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          switch (opt.type) {
                                            'pickup_in_person' =>
                                              Icons.store_outlined,
                                            'seller_delivery' =>
                                              Icons.delivery_dining_outlined,
                                            'motoboy' =>
                                              Icons.motorcycle_outlined,
                                            _ => Icons.local_shipping_outlined,
                                          },
                                          size: 14,
                                          color: theme.colorScheme.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          opt.displayLabel,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                            color: theme.colorScheme.primary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        if (opt.deliveryFee != null) ...[
                                          const SizedBox(width: 4),
                                          Text(
                                            opt.deliveryFee == 0
                                                ? '· Grátis'
                                                : '· R\$ ${opt.deliveryFee!.toStringAsFixed(2)}',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              color: opt.deliveryFee == 0
                                                  ? Colors.green.shade700
                                                  : theme.colorScheme
                                                      .onSurfaceVariant,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ))
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ),

              // Payment methods
              if (tenant.marketplace?.paymentMethods.isNotEmpty == true)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Formas de Pagamento',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: tenant.marketplace!.paymentMethods
                              .map((method) {
                            final label = switch (method) {
                              'pix' => 'PIX',
                              'credit_card' => 'Cartão de Crédito',
                              'debit_card' => 'Cartão de Débito',
                              'boleto' => 'Boleto',
                              'cash' => 'Dinheiro',
                              _ => method,
                            };
                            final icon = switch (method) {
                              'pix' => Icons.qr_code_outlined,
                              'credit_card' || 'debit_card' =>
                                Icons.credit_card_outlined,
                              'boleto' => Icons.receipt_long_outlined,
                              'cash' => Icons.payments_outlined,
                              _ => Icons.payment_outlined,
                            };
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color:
                                      theme.colorScheme.outline.withAlpha(50),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(icon,
                                      size: 14,
                                      color:
                                          theme.colorScheme.onSurfaceVariant),
                                  const SizedBox(width: 4),
                                  Text(
                                    label,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),

              // WhatsApp configuration section — only visible to the tenant owner
              if (isOwner)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: _WhatsAppConfigSection(
                      controller: _whatsappController,
                      enabled: _whatsappEnabled,
                      isSaving: _isSavingWhatsApp,
                      onToggle: (value) {
                        setState(() {
                          _whatsappEnabled = value;
                          if (!value) _whatsappController.clear();
                        });
                      },
                      onSave: _saveWhatsApp,
                    ),
                  ),
                ),

              // Products header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                  child: Text(
                    'Produtos',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // Products grid
              productsAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (_, __) => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text('Erro ao carregar produtos'),
                    ),
                  ),
                ),
                data: (products) {
                  if (products.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.storefront_outlined,
                                size: 48,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Nenhum produto publicado',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.68,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => ProductCard(
                          product: products[index],
                        ),
                        childCount: products.length,
                      ),
                    ),
                  );
                },
              ),

              // Bottom padding for FAB
              const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
            ],
          );
        },
      ),

      // Contact buttons (chat + optional WhatsApp)
      bottomNavigationBar: tenantAsync.valueOrNull != null
          ? Container(
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
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isOpeningChat
                          ? null
                          : () async {
                              setState(() => _isOpeningChat = true);
                              try {
                                final chat = await ref
                                    .read(chatsProvider.notifier)
                                    .getOrCreateChat(tenantId);
                                if (!context.mounted) return;
                                if (chat == null) {
                                  AppFeedback.showError(context, 'Não foi possível iniciar conversa');
                                  return;
                                }
                                context.push('/chats/${chat.id}');
                              } finally {
                                if (mounted) setState(() => _isOpeningChat = false);
                              }
                            },
                      icon: _isOpeningChat
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.chat_bubble_outline),
                      label: Text(_isOpeningChat ? 'Abrindo...' : 'Enviar mensagem'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  if (tenantAsync.valueOrNull?.whatsapp != null &&
                      tenantAsync.valueOrNull!.whatsapp!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    WhatsAppButton(
                      phoneNumber: tenantAsync.valueOrNull!.whatsapp!,
                      message: 'Olá! Vi sua loja no marketplace e gostaria de saber mais.',
                      isCompact: true,
                    ),
                  ],
                ],
              ),
            )
          : null,
    );
  }
}

/// WhatsApp configuration widget shown only to the tenant owner.
/// Allows the seller to enable/disable WhatsApp contact and set their number.
class _WhatsAppConfigSection extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final bool isSaving;
  final ValueChanged<bool> onToggle;
  final VoidCallback onSave;

  const _WhatsAppConfigSection({
    required this.controller,
    required this.enabled,
    required this.isSaving,
    required this.onToggle,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF25D366).withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.chat_rounded,
                  color: Color(0xFF25D366),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Contato via WhatsApp',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Toggle row
          Row(
            children: [
              Expanded(
                child: Text(
                  'Permitir clientes entrarem em contato via WhatsApp',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Switch(
                value: enabled,
                onChanged: onToggle,
                activeThumbColor: const Color(0xFF25D366),
                activeTrackColor: const Color(0xFF25D366).withAlpha(80),
              ),
            ],
          ),

          // Number field — only visible when toggle is ON
          if (enabled) ...[
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d+\s\-]')),
                LengthLimitingTextInputFormatter(20),
              ],
              decoration: InputDecoration(
                labelText: 'Número do WhatsApp',
                hintText: '+55 11 99999-9999',
                helperText: 'Clientes verão um botão "Chamar no WhatsApp" na sua loja',
                helperMaxLines: 2,
                prefixIcon: const Icon(Icons.phone_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isSaving ? null : onSave,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined, size: 18),
                label: Text(isSaving ? 'Salvando...' : 'Salvar número'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// Seller Reviews Button
// ============================================================================

class _SellerReviewsButton extends ConsumerWidget {
  final String tenantId;
  final TenantModel tenant;

  const _SellerReviewsButton({required this.tenantId, required this.tenant});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(sellerReviewsProvider(tenantId));
    final reviews = reviewsAsync.valueOrNull ?? [];
    final hasReviews = reviews.isNotEmpty;

    final avg = hasReviews
        ? reviews.fold(0.0, (double sum, r) => sum + r.rating) / reviews.length
        : tenant.rating;

    final total = hasReviews
        ? reviews.length
        : (tenant.marketplace?.totalReviews ?? 0);

    return ReviewsSummaryButton(
      averageRating: double.parse(avg.toStringAsFixed(1)),
      totalReviews: total,
      onTap: hasReviews
          ? () => showReviewsBottomSheet(
                context,
                targetLabel: tenant.displayName,
                reviews: reviews,
                averageRating: avg,
              )
          : null,
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(40)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
