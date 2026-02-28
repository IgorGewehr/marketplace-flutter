import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/product_model.dart';
import '../../providers/auth_providers.dart';
import '../../providers/cart_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/products_provider.dart';
import '../../providers/review_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../widgets/products/image_carousel.dart';
import '../../widgets/reviews/review_tile.dart';
import '../../widgets/reviews/reviews_bottom_sheet.dart';
import '../../widgets/shared/app_feedback.dart';
import '../../widgets/shared/loading_overlay.dart';
import '../../widgets/shared/shimmer_loading.dart';
import '../../widgets/shared/whatsapp_button.dart';

/// Product details screen
class ProductDetailsScreen extends ConsumerStatefulWidget {
  final String productId;

  const ProductDetailsScreen({super.key, required this.productId});

  @override
  ConsumerState<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends ConsumerState<ProductDetailsScreen> {
  int _quantity = 1;
  bool _isAddingToCart = false;
  bool _isOpeningChat = false;
  String? _selectedVariantId;
  bool _isDescriptionExpanded = false;

  /// The currently selected variant object (null if none selected)
  ProductVariant? get _selectedVariant {
    final product = ref.read(productDetailProvider(widget.productId)).valueOrNull;
    if (product == null || _selectedVariantId == null) return null;
    return product.variants.firstWhereOrNull((v) => v.id == _selectedVariantId);
  }

  /// Effective price: variant price (if selected and > 0) or product base price
  double _effectivePrice(ProductModel p) {
    final v = _selectedVariant;
    if (v != null && v.price != null && v.price! > 0) return v.price!;
    return p.price;
  }

  /// Effective compare-at price: variant compareAtPrice or product base compareAtPrice
  double? _effectiveCompareAtPrice(ProductModel p) {
    final v = _selectedVariant;
    if (v != null && v.compareAtPrice != null && v.compareAtPrice! > 0) return v.compareAtPrice;
    return p.compareAtPrice;
  }

  /// Effective stock quantity: variant quantity if selected, otherwise product quantity
  int? _effectiveQuantity(ProductModel p) {
    final v = _selectedVariant;
    if (v != null && v.quantity != null) return v.quantity;
    return p.quantity;
  }

  void _incrementQuantity() {
    final product = ref.read(productDetailProvider(widget.productId)).valueOrNull;
    final maxQuantity = _effectiveQuantity(product!);
    if (maxQuantity != null && _quantity >= maxQuantity) return;
    setState(() => _quantity++);
  }

  void _decrementQuantity() {
    if (_quantity > 1) {
      setState(() => _quantity--);
    }
  }

  Future<void> _addToCart() async {
    HapticFeedback.mediumImpact();
    final product = ref.read(productDetailProvider(widget.productId)).valueOrNull;
    if (product == null) return;

    // Gap #1: Validate variant selection before adding to cart
    if (product.hasVariants && product.variants.isNotEmpty && _selectedVariantId == null) {
      AppFeedback.showWarning(context, 'Selecione uma variante antes de continuar');
      return;
    }

    setState(() => _isAddingToCart = true);

    final selectedVariant = product.variants.firstWhereOrNull((v) => v.id == _selectedVariantId);
    await ref.read(cartProvider.notifier).addToCart(
      product,
      quantity: _quantity,
      variant: selectedVariant?.name,
      variantId: _selectedVariantId,
    );

    if (mounted) {
      setState(() => _isAddingToCart = false);

      final cartError = ref.read(cartProvider).error;
      if (cartError != null) {
        AppFeedback.showError(context, cartError);
        return;
      }

      AppFeedback.showSuccess(
        context,
        '${product.name} adicionado ao carrinho',
        onTap: () => context.push(AppRouter.cart),
      );
    }
  }

  Widget _buildSellerAvatar(ThemeData theme, String initial) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
    );
  }

  Future<void> _openChat(String tenantId) async {
    final isAuth = ref.read(isAuthenticatedProvider);
    if (!isAuth) {
      context.push('${AppRouter.login}?redirect=/product/${widget.productId}');
      return;
    }
    setState(() => _isOpeningChat = true);
    try {
      final chat = await ref.read(chatsProvider.notifier).getOrCreateChat(tenantId);
      if (chat != null && mounted) {
        context.push('/chats/${chat.id}');
      } else if (mounted) {
        AppFeedback.showError(context, 'Não foi possível iniciar conversa');
      }
    } finally {
      if (mounted) setState(() => _isOpeningChat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final productAsync = ref.watch(productDetailProvider(widget.productId));

    // Watch tenant at top level — only when product is available and has a tenantId
    final product = productAsync.valueOrNull;
    final tenantAsync = product != null && product.tenantId.isNotEmpty
        ? ref.watch(tenantByIdProvider(product.tenantId))
        : null;
    final tenant = tenantAsync?.valueOrNull;

    // Fetch the owner user (displayName + photoURL) via tenant.ownerUserId
    final ownerUserId = tenant?.ownerUserId ?? '';
    final ownerUserAsync = ownerUserId.isNotEmpty
        ? ref.watch(userByIdProvider(ownerUserId))
        : null;
    final ownerUser = ownerUserAsync?.valueOrNull;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: productAsync.when(
        loading: () => const Center(child: LoadingIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Erro ao carregar produto'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(productDetailProvider(widget.productId)),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
        data: (product) {
          if (product == null) {
            return const Center(child: Text('Produto não encontrado'));
          }

          // Owner user always has a displayName; fall back to tenant name if still loading
          final sellerName = (ownerUser?.displayName.isNotEmpty == true)
              ? ownerUser!.displayName
              : (tenant?.displayName.isNotEmpty == true)
                  ? tenant!.displayName
                  : '...';
          final sellerInitial = sellerName.isNotEmpty
              ? sellerName[0].toUpperCase()
              : 'V';
          final sellerPhotoUrl = ownerUser?.photoURL ?? tenant?.logoURL;

          return CustomScrollView(
            slivers: [
              // App bar — transparent overlay on image, frosted buttons
              SliverAppBar(
                pinned: true,
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                elevation: 0,
                scrolledUnderElevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  background: IgnorePointer(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xCC000000),
                            Colors.transparent,
                          ],
                          stops: [0.0, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
                leading: Padding(
                  padding: const EdgeInsets.all(8),
                  child: _GlassIconButton(
                    onPressed: () => context.pop(),
                    icon: Icons.arrow_back_rounded,
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: _GlassIconButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        ref.read(favoriteProductIdsProvider.notifier).toggleFavorite(product.id);
                      },
                      icon: ref.watch(isProductFavoriteProvider(product.id))
                          ? Icons.favorite
                          : Icons.favorite_border,
                      iconColor: ref.watch(isProductFavoriteProvider(product.id))
                          ? AppColors.error
                          : Colors.white,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _GlassIconButton(
                      onPressed: () => context.push(AppRouter.cart),
                      icon: Icons.shopping_cart_outlined,
                    ),
                  ),
                ],
              ),

              // Image carousel with Hero transition from product card
              SliverToBoxAdapter(
                child: ImageCarousel(
                  images: product.images.map((i) => i.url).toList(),
                  height: 350,
                  heroTag: 'product_image_${product.id}',
                ),
              ),

              // Product info
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          ref.watch(categoryIdToNameProvider).maybeWhen(
                            data: (idToName) => idToName[product.categoryId] ?? product.categoryId,
                            orElse: () => product.categoryId,
                          ),
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Title
                      Text(
                        product.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Price (reacts to selected variant)
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Builder(
                          key: ValueKey('price_$_selectedVariantId'),
                          builder: (context) {
                            final effectivePrice = _effectivePrice(product);
                            final compareAt = _effectiveCompareAtPrice(product);
                            final hasDiscount = compareAt != null && compareAt > effectivePrice;
                            final discountPct = hasDiscount
                                ? (((compareAt - effectivePrice) / compareAt) * 100).round()
                                : 0;

                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (hasDiscount) ...[
                                  Text(
                                    Formatters.currency(compareAt),
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      decoration: TextDecoration.lineThrough,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  Formatters.currency(effectivePrice),
                                  style: theme.textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: hasDiscount
                                        ? theme.colorScheme.secondary
                                        : theme.colorScheme.primary,
                                  ),
                                ),
                                if (hasDiscount) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.secondary,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '-$discountPct%',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      ),

                      // Variant selector with price, stock, and sold-out state
                      if (product.hasVariants && product.variants.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(
                          'Variante',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: product.variants.map((variant) {
                            final isSelected = _selectedVariantId == variant.id;
                            final isSoldOut = variant.quantity != null && variant.quantity! <= 0;
                            final isLowStock = variant.quantity != null && variant.quantity! > 0 && variant.quantity! <= 3;
                            final hasCustomPrice = variant.price != null && variant.price! > 0 && variant.price != product.price;

                            return ChoiceChip(
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isLowStock && !isSoldOut)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 4),
                                      child: Icon(
                                        Icons.warning_amber_rounded,
                                        size: 14,
                                        color: theme.colorScheme.error,
                                      ),
                                    ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isSoldOut ? variant.name : variant.name,
                                        style: TextStyle(
                                          decoration: isSoldOut ? TextDecoration.lineThrough : null,
                                          color: isSoldOut ? theme.colorScheme.onSurfaceVariant : null,
                                        ),
                                      ),
                                      if (isSoldOut)
                                        Text(
                                          'Esgotado',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: theme.colorScheme.error,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        )
                                      else if (hasCustomPrice)
                                        Text(
                                          Formatters.currency(variant.price!),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isSelected
                                                ? theme.colorScheme.primary
                                                : theme.colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              selected: isSelected,
                              onSelected: isSoldOut
                                  ? null
                                  : (selected) {
                                      HapticFeedback.selectionClick();
                                      setState(() {
                                        _selectedVariantId = selected ? variant.id : null;
                                        _quantity = 1;
                                      });
                                    },
                              selectedColor: theme.colorScheme.primaryContainer,
                            );
                          }).toList(),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Quantity selector (uses variant stock when selected)
                      Builder(
                        builder: (context) {
                          final effectiveQty = _effectiveQuantity(product);
                          return Row(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Quantidade',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (effectiveQty != null)
                                    Text(
                                      '$effectiveQty disponíve${effectiveQty == 1 ? 'l' : 'is'}',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: effectiveQty <= 3
                                            ? theme.colorScheme.error
                                            : theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                ],
                              ),
                              const Spacer(),
                              Container(
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    IconButton(
                                      onPressed: _decrementQuantity,
                                      icon: const Icon(Icons.remove),
                                      iconSize: 20,
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      child: Text(
                                        _quantity.toString(),
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: (effectiveQty != null && _quantity >= effectiveQty)
                                          ? null
                                          : _incrementQuantity,
                                      icon: const Icon(Icons.add),
                                      iconSize: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),

                      // Description
                      Text(
                        'Descrição',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isDescriptionExpanded
                            ? product.description
                            : product.description.length > 300
                                ? '${product.description.substring(0, 300)}...'
                                : product.description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (product.description.length > 300)
                        GestureDetector(
                          onTap: () => setState(() => _isDescriptionExpanded = !_isDescriptionExpanded),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _isDescriptionExpanded ? 'Ver menos' : 'Ver mais',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                      // Tags
                      if (product.tags.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: product.tags.map((tag) {
                            return GestureDetector(
                              onTap: () {
                                ref.read(productFiltersProvider.notifier).state =
                                    ProductFilters(tags: [tag]);
                                context.push(AppRouter.search);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '#$tag',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],

                      // Product location
                      if (product.location?.city != null) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              [
                                product.location!.city,
                                if (product.location!.state != null) product.location!.state,
                              ].whereType<String>().join(' - '),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),

                      // WhatsApp seller button
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: (tenantAsync != null && tenant?.whatsapp != null && tenant!.whatsapp!.isNotEmpty)
                            ? Column(
                                key: const ValueKey('whatsapp_btn'),
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  WhatsAppButton(
                                    phoneNumber: tenant.whatsapp!,
                                    message: 'Olá! Tenho interesse no produto: ${product.name} - ${Formatters.currency(product.price)}',
                                    label: 'Chamar vendedor no WhatsApp',
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              )
                            : const SizedBox.shrink(key: ValueKey('whatsapp_empty')),
                      ),

                      // Seller info
                      Text(
                        'Vendedor',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: product.tenantId.isEmpty
                            ? null
                            : () {
                                context.push('/seller-profile/${product.tenantId}');
                              },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              if (sellerPhotoUrl != null && sellerPhotoUrl.isNotEmpty)
                                ClipOval(
                                  child: Image.network(
                                    sellerPhotoUrl,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => _buildSellerAvatar(
                                      theme, sellerInitial,
                                    ),
                                  ),
                                )
                              else
                                _buildSellerAvatar(theme, sellerInitial),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Seller name + verified badge
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            sellerName,
                                            style: theme.textTheme.bodyLarge?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (tenant?.isVerified == true) ...[
                                          const SizedBox(width: 4),
                                          Icon(
                                            Icons.verified,
                                            size: 16,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    // Rating + sales + location
                                    Row(
                                      children: [
                                        if (tenant != null && tenant.rating > 0) ...[
                                          Icon(
                                            Icons.star,
                                            size: 14,
                                            color: AppColors.ratingDark,
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            tenant.rating.toStringAsFixed(1),
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        if (tenant != null &&
                                            tenant.marketplace != null &&
                                            tenant.marketplace!.totalSales > 0) ...[
                                          Icon(
                                            Icons.shopping_bag_outlined,
                                            size: 13,
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            '${tenant.marketplace!.totalSales} vendas',

                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: theme.colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        if (tenant != null &&
                                            tenant.address != null &&
                                            tenant.address!.city.isNotEmpty) ...[
                                          Icon(
                                            Icons.location_on_outlined,
                                            size: 13,
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                          const SizedBox(width: 2),
                                          Flexible(
                                            child: Text(
                                              '${tenant.address!.city} - ${tenant.address!.state}',
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: theme.colorScheme.onSurfaceVariant,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Ver perfil do vendedor',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right),
                            ],
                          ),
                        ),
                      ),

                      // Reviews section
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 16),
                      _ProductReviewsSection(productId: product.id),

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

      // Bottom bar: Comprar + Chat (< R$500) or WhatsApp/Chat (>= R$500)
      bottomNavigationBar: productAsync.when(
        loading: () => null,
        error: (_, __) => null,
        data: (product) {
          if (product == null) return null;

          final isHighValue = _effectivePrice(product) >= 500;
          final hasWhatsApp = tenant?.whatsapp != null && tenant!.whatsapp!.isNotEmpty;

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
                  color: Colors.black.withAlpha(15),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Info banner for high-value products
                if (isHighValue)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Produto acima de R\$ 500 — negocie diretamente com o vendedor',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                if (!isHighValue)
                  // Standard layout: Comprar + Chat
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: FilledButton.icon(
                          onPressed: (product.quantity != null && product.quantity! <= 0) || _isAddingToCart
                              ? null
                              : _addToCart,
                          icon: _isAddingToCart
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.shopping_bag_outlined, size: 20),
                          label: Text(
                            product.quantity != null && product.quantity! <= 0
                                ? 'Sem estoque'
                                : 'Comprar',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: OutlinedButton.icon(
                          onPressed: _isOpeningChat ? null : () => _openChat(product.tenantId),
                          icon: _isOpeningChat
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.chat_bubble_outline, size: 20),
                          label: Text(
                            _isOpeningChat ? 'Abrindo...' : 'Chat',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(
                              color: theme.colorScheme.outline.withAlpha(80),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  // High-value layout: WhatsApp + Chat (or Chat only)
                  Row(
                    children: [
                      if (hasWhatsApp) ...[
                        Expanded(
                          flex: 3,
                          child: FilledButton.icon(
                            onPressed: () => launchWhatsApp(
                              phoneNumber: tenant.whatsapp!,
                              message: 'Olá! Tenho interesse no produto: ${product.name} - ${Formatters.currency(_effectivePrice(product))}',
                              context: context,
                            ),
                            icon: const Icon(LucideIcons.messageCircle, size: 20),
                            label: const Text(
                              'WhatsApp',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF25D366),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        flex: hasWhatsApp ? 2 : 1,
                        child: OutlinedButton.icon(
                          onPressed: _isOpeningChat ? null : () => _openChat(product.tenantId),
                          icon: _isOpeningChat
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.chat_bubble_outline, size: 20),
                          label: Text(
                            _isOpeningChat ? 'Abrindo...' : 'Chat',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(
                              color: theme.colorScheme.outline.withAlpha(80),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                if (!isHighValue && product.quantity != null && product.quantity! <= 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Este produto esta indisponivel no momento',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
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

// ============================================================================
// Product Reviews Section
// ============================================================================

class _ProductReviewsSection extends ConsumerWidget {
  final String productId;

  const _ProductReviewsSection({required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final reviewsAsync = ref.watch(productReviewsProvider(productId));

    final reviews = reviewsAsync.valueOrNull ?? [];
    final hasReviews = reviews.isNotEmpty;
    final avg = hasReviews
        ? reviews.fold(0.0, (sum, r) => sum + r.rating) / reviews.length
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Text(
              'Avaliações',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            if (hasReviews)
              TextButton(
                onPressed: () => showReviewsBottomSheet(
                  context,
                  targetLabel: '',
                  reviews: reviews,
                  averageRating: avg,
                ),
                child: const Text('Ver todas'),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Summary button
        ReviewsSummaryButton(
          averageRating: double.parse(avg.toStringAsFixed(1)),
          totalReviews: reviews.length,
          onTap: hasReviews
              ? () => showReviewsBottomSheet(
                    context,
                    targetLabel: '',
                    reviews: reviews,
                    averageRating: avg,
                  )
              : null,
        ),

        // Stars preview + first 2 reviews
        if (hasReviews) ...[
          const SizedBox(height: 14),
          ...reviews.take(2).toList().asMap().entries.map((e) {
            return ReviewTile(review: e.value, index: e.key);
          }),
        ] else ...[
          const SizedBox(height: 12),
          reviewsAsync.isLoading
              ? const ShimmerBox(width: double.infinity, height: 80)
              : Text(
                  'Seja o primeiro a avaliar este produto!',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
        ],
      ],
    );
  }
}

/// Frosted glass icon button for the transparent AppBar
class _GlassIconButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final Color iconColor;

  const _GlassIconButton({
    required this.onPressed,
    required this.icon,
    this.iconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Colors.black.withAlpha(100),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withAlpha(40),
              width: 0.5,
            ),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
      ),
    );
  }
}
