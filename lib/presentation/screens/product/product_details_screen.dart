import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/tenant_model.dart';
import '../../providers/auth_providers.dart';
import '../../providers/cart_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/products_provider.dart';
import '../../providers/tenant_provider.dart';
import '../../widgets/products/image_carousel.dart';
import '../../widgets/shared/loading_overlay.dart';
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
  bool _isBuyingNow = false;
  String? _selectedVariantId;

  void _incrementQuantity() {
    final product = ref.read(productDetailProvider(widget.productId)).valueOrNull;
    final maxQuantity = product?.quantity;
    if (maxQuantity != null && _quantity >= maxQuantity) return;
    setState(() => _quantity++);
  }

  void _decrementQuantity() {
    if (_quantity > 1) {
      setState(() => _quantity--);
    }
  }

  Future<void> _addToCart() async {
    final product = ref.read(productDetailProvider(widget.productId)).valueOrNull;
    if (product == null) return;

    if (product.hasVariants && product.variants.isNotEmpty && _selectedVariantId == null) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(content: Text('Selecione uma variante antes de continuar')),
        );
      return;
    }

    setState(() => _isAddingToCart = true);

    await ref.read(cartProvider.notifier).addToCart(product, quantity: _quantity, variant: _selectedVariantId);

    if (mounted) {
      setState(() => _isAddingToCart = false);

      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text('${product.name} adicionado ao carrinho'),
            action: SnackBarAction(
              label: 'Ver carrinho',
              onPressed: () => context.push(AppRouter.cart),
            ),
          ),
        );
    }
  }

  void _buyNow() async {
    if (_isBuyingNow || _isAddingToCart) return;

    final isAuth = ref.read(isAuthenticatedProvider);

    if (!isAuth) {
      context.push('${AppRouter.login}?redirect=${AppRouter.checkout}');
      return;
    }

    setState(() => _isBuyingNow = true);
    await _addToCart();
    if (mounted) {
      setState(() => _isBuyingNow = false);
      context.push(AppRouter.checkout);
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

  Widget _buildBottomBarActions({
    required ThemeData theme,
    required bool isLoading,
    required bool hasPaymentMethods,
    required TenantModel? tenant,
    required String productName,
    required double productPrice,
  }) {
    if (isLoading) {
      return Expanded(
        child: OutlinedButton(
          onPressed: null,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (hasPaymentMethods) {
      return Expanded(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isAddingToCart ? null : _addToCart,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _isAddingToCart
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_shopping_cart, size: 18),
                          SizedBox(width: 6),
                          Text('Carrinho'),
                        ],
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: (_isBuyingNow || _isAddingToCart) ? null : _buyNow,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: theme.colorScheme.secondary,
                ),
                child: _isBuyingNow
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Comprar agora'),
              ),
            ),
          ],
        ),
      );
    }

    // No payment methods — show WhatsApp if available
    final whatsapp = tenant?.whatsapp;
    if (whatsapp != null && whatsapp.isNotEmpty) {
      return Expanded(
        child: WhatsAppButton(
          phoneNumber: whatsapp,
          message:
              'Olá! Tenho interesse no produto: $productName - ${Formatters.currency(productPrice)}',
          label: 'WhatsApp',
        ),
      );
    }

    // Fallback: empty spacer
    return const Spacer();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final productAsync = ref.watch(productDetailProvider(widget.productId));

    // Watch tenant at top level — only when product is available
    final product = productAsync.valueOrNull;
    final tenantAsync = product != null
        ? ref.watch(tenantByIdProvider(product.tenantId))
        : null;
    final tenant = tenantAsync?.valueOrNull;

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

          final sellerName = tenant?.displayName ?? 'Vendedor';
          final sellerInitial = sellerName.isNotEmpty
              ? sellerName[0].toUpperCase()
              : 'V';
          final hasLogo = tenant?.logoURL != null && tenant!.logoURL!.isNotEmpty;

          return CustomScrollView(
            slivers: [
              // App bar
              SliverAppBar(
                pinned: true,
                backgroundColor: theme.colorScheme.surface,
                leading: IconButton(
                  onPressed: () => context.pop(),
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(230),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back),
                  ),
                ),
                actions: [
                  IconButton(
                    onPressed: () {
                      ref.read(favoriteProductIdsProvider.notifier).toggleFavorite(product.id);
                    },
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(230),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        ref.watch(isProductFavoriteProvider(product.id))
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: ref.watch(isProductFavoriteProvider(product.id))
                            ? Colors.red
                            : null,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      final shareText =
                          '${product.name} - ${Formatters.currency(product.price)}\n'
                          'Confira no Compre Aqui!';
                      Clipboard.setData(ClipboardData(text: shareText));
                      ScaffoldMessenger.of(context)
                        ..clearSnackBars()
                        ..showSnackBar(
                          const SnackBar(
                            content: Text('Link copiado para a área de transferência'),
                          ),
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
                  images: product.images.map((i) => i.url).toList(),
                  height: 350,
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
                          product.categoryId,
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

                      // Price
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (product.hasDiscount && product.compareAtPrice != null) ...[
                            Text(
                              Formatters.currency(product.compareAtPrice!),
                              style: theme.textTheme.bodyLarge?.copyWith(
                                decoration: TextDecoration.lineThrough,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Text(
                            Formatters.currency(product.price),
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: product.hasDiscount
                                  ? theme.colorScheme.secondary
                                  : theme.colorScheme.primary,
                            ),
                          ),
                          if (product.hasDiscount) ...[
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
                                '-${product.discountPercentage}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),

                      // Variant selector
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
                            return ChoiceChip(
                              label: Text(variant.name),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedVariantId = selected ? variant.id : null;
                                });
                              },
                              selectedColor: theme.colorScheme.primaryContainer,
                            );
                          }).toList(),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Quantity selector
                      Row(
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
                              if (product.quantity != null)
                                Text(
                                  '${product.quantity} disponíve${product.quantity == 1 ? 'l' : 'is'}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: product.quantity! <= 3
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
                                  onPressed: (product.quantity != null && _quantity >= product.quantity!)
                                      ? null
                                      : _incrementQuantity,
                                  icon: const Icon(Icons.add),
                                  iconSize: 20,
                                ),
                              ],
                            ),
                          ),
                        ],
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
                        product.description,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),

                      // Tags
                      if (product.tags.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: product.tags.map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '#$tag',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
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

                      // Seller info
                      Text(
                        'Vendedor',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () async {
                          final isAuth = ref.read(isAuthenticatedProvider);
                          if (!isAuth) {
                            context.push('${AppRouter.login}?redirect=/product/${product.id}');
                            return;
                          }
                          final chat = await ref.read(chatsProvider.notifier).getOrCreateChat(product.tenantId);
                          if (chat != null && context.mounted) {
                            context.push('/chats/${chat.id}');
                          }
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
                              if (hasLogo)
                                ClipOval(
                                  child: Image.network(
                                    tenant!.logoURL!,
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
                                            color: Colors.amber.shade700,
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
                                      'Conversar com vendedor',
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
      bottomNavigationBar: productAsync.when(
        loading: () => null,
        error: (_, __) => null,
        data: (product) {
          if (product == null) return null;

          final hasPaymentMethods =
              tenant?.marketplace?.paymentMethods.isNotEmpty ?? false;
          final isTenantLoading = tenantAsync?.isLoading ?? true;

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
                // Chat with seller (always visible)
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: theme.colorScheme.outline.withAlpha(50),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    onPressed: () async {
                      final isAuth = ref.read(isAuthenticatedProvider);
                      if (!isAuth) {
                        context.push('${AppRouter.login}?redirect=/product/${product.id}');
                        return;
                      }
                      final chat = await ref.read(chatsProvider.notifier).getOrCreateChat(product.tenantId);
                      if (chat != null && context.mounted) {
                        context.push('/chats/${chat.id}');
                      }
                    },
                    icon: const Icon(Icons.chat_bubble_outline),
                    tooltip: 'Conversar com vendedor',
                  ),
                ),
                const SizedBox(width: 12),
                _buildBottomBarActions(
                  theme: theme,
                  isLoading: isTenantLoading,
                  hasPaymentMethods: hasPaymentMethods,
                  tenant: tenant,
                  productName: product.name,
                  productPrice: product.price,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
