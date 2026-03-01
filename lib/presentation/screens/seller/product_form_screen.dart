import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/product_model.dart';
import '../../../data/services/image_upload_service.dart';
import '../../providers/auth_providers.dart';
import '../../providers/mercadopago_provider.dart';
import '../../providers/my_products_provider.dart';
import '../../providers/products_provider.dart';
import '../../widgets/seller/photo_picker_grid.dart';
import '../../widgets/seller/variant_manager.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../widgets/shared/app_feedback.dart';

/// Product form screen for creating/editing products - Simplified for marketplace
class ProductFormScreen extends ConsumerStatefulWidget {
  final String? productId;
  /// When provided, pre-fills all fields from this product (used for duplication).
  /// The form will treat this as a new product (no productId), with status set to draft.
  final ProductModel? initialProduct;

  const ProductFormScreen({super.key, this.productId, this.initialProduct});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _tagController = TextEditingController();

  bool _isLoading = false;
  bool _isActive = true;
  String? _selectedCategory;
  List<String> _tags = [];
  List<String> _existingImageUrls = [];
  List<String> _originalImageUrls = [];
  List<File> _newImageFiles = [];
  List<ProductVariant> _variants = [];
  bool _hasVariants = false;
  bool _isOnDemand = false;
  bool _hasUnsavedChanges = false;
  bool _isPopulating = false;

  // Scroll + validation highlight
  final _scrollController = ScrollController();
  final _photosKey = GlobalKey();
  final _infoKey = GlobalKey();
  final _priceKey = GlobalKey();
  final _categoryKey = GlobalKey();
  int? _highlightedSection;

  // Upload progress
  bool _isUploadingImages = false;
  int _uploadedImages = 0;
  int _totalImagesToUpload = 0;

  bool get _isEditing => widget.productId != null;

  /// Calculate how many sections are filled (out of 4 required)
  int get _filledSections {
    int count = 0;
    if (_existingImageUrls.isNotEmpty || _newImageFiles.isNotEmpty) count++;
    if (_nameController.text.trim().length >= 3 &&
        _descriptionController.text.trim().length >= 10) count++;
    if (_priceController.text.isNotEmpty) count++;
    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) count++;
    return count;
  }

  static const _totalRequiredSections = 4;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onFieldChanged);
    _descriptionController.addListener(_onFieldChanged);
    _priceController.addListener(_onFieldChanged);
    _quantityController.addListener(_onFieldChanged);
    if (_isEditing) {
      _loadProduct();
    } else if (widget.initialProduct != null) {
      // Pre-fill from initialProduct (duplication) — set status to draft
      final source = widget.initialProduct!;
      _populateFields(source.copyWith(status: 'draft'));
      // Duplicate starts as draft (not published)
      _isActive = false;
    }
  }

  void _onFieldChanged() {
    if (_isPopulating) return;
    setState(() {
      _hasUnsavedChanges = true;
      if (_highlightedSection != null) _highlightedSection = null;
    });
  }

  void _loadProduct() {
    final products = ref.read(myProductsProvider).valueOrNull ?? [];
    final product = products.where((p) => p.id == widget.productId).firstOrNull;
    if (product != null) {
      _populateFields(product);
    } else {
      // Fallback: product not in myProducts (e.g. deep link), fetch via detail provider
      final detail = ref.read(productDetailProvider(widget.productId!)).valueOrNull;
      if (detail != null) {
        _populateFields(detail);
      }
    }
  }

  void _populateFields(ProductModel product) {
    _isPopulating = true;
    _nameController.text = product.name;
    _descriptionController.text = product.description;
    _priceController.text = _BrlCurrencyFormatter.format(product.price);
    _isOnDemand = !product.trackInventory;
    _quantityController.text = _isOnDemand ? '' : (product.quantity > 0 ? product.quantity.toString() : '');
    _isActive = product.status == 'active';
    _selectedCategory = product.categoryId;
    _tags = List.from(product.tags);
    _existingImageUrls = product.images.map((i) => i.url).toList();
    _originalImageUrls = List.from(_existingImageUrls);
    _variants = List.from(product.variants);
    _hasVariants = product.hasVariants;
    _isPopulating = false;

    // Validate category after frame so categoriesProvider is loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _validateSelectedCategory();
    });
  }

  void _validateSelectedCategory() {
    final models = ref.read(categoryModelsProvider).valueOrNull ?? [];
    final validIds = models.map((c) => c.id).toSet();
    if (_selectedCategory != null && !validIds.contains(_selectedCategory)) {
      setState(() => _selectedCategory = null);
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_onFieldChanged);
    _descriptionController.removeListener(_onFieldChanged);
    _priceController.removeListener(_onFieldChanged);
    _quantityController.removeListener(_onFieldChanged);
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _tagController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  int? _findFirstInvalidSection() {
    if (_existingImageUrls.isEmpty && _newImageFiles.isEmpty) return 0;
    final name = _nameController.text.trim();
    final desc = _descriptionController.text.trim();
    if (name.isEmpty || name.length < 3 || desc.isEmpty || desc.length < 10) {
      return 1;
    }
    final priceText = _priceController.text;
    if (priceText.isEmpty) return 2;
    final price =
        double.tryParse(priceText.replaceAll('.', '').replaceAll(',', '.'));
    if (price == null || price <= 0) return 2;
    if (_selectedCategory == null || _selectedCategory!.isEmpty) return 3;
    return null;
  }

  GlobalKey? _keyForSection(int index) {
    return switch (index) {
      0 => _photosKey,
      1 => _infoKey,
      2 => _priceKey,
      3 => _categoryKey,
      _ => null,
    };
  }

  void _scrollToSection(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.1,
      );
    }
  }

  void _highlightError(int sectionIndex) {
    setState(() => _highlightedSection = sectionIndex);
    final key = _keyForSection(sectionIndex);
    if (key != null) _scrollToSection(key);
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _highlightedSection = null);
    });
  }

  Future<void> _saveProduct() async {
    // Validate at least one photo first (top of form)
    if (_existingImageUrls.isEmpty && _newImageFiles.isEmpty) {
      _highlightError(0);
      AppFeedback.showWarning(context, 'Adicione pelo menos 1 foto do produto');
      return;
    }

    if (!_formKey.currentState!.validate()) {
      final sectionIndex = _findFirstInvalidSection();
      if (sectionIndex != null) {
        _highlightError(sectionIndex);
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _isUploadingImages = _newImageFiles.isNotEmpty;
      _uploadedImages = 0;
      _totalImagesToUpload = _newImageFiles.length;
    });

    try {
      final allImageUrls = [..._existingImageUrls];

      // Determine the product id once — reuse for both upload path and model
      final productId = widget.productId ?? const Uuid().v4();

      // Upload new images to Firebase Storage
      if (_newImageFiles.isNotEmpty) {
        final uploadedUrls = await imageUploadServiceProvider.uploadProductImages(
          _newImageFiles,
          productId,
          onProgress: (current, total) {
            setState(() {
              _uploadedImages = current;
              _totalImagesToUpload = total;
            });
          },
        );

        allImageUrls.addAll(uploadedUrls);
      }

      setState(() => _isUploadingImages = false);

      // Validate that we have at least one image after upload
      if (allImageUrls.isEmpty) {
        if (mounted) {
          AppFeedback.showError(context, 'Não foi possível enviar as fotos. Tente novamente.');
        }
        setState(() => _isLoading = false);
        return;
      }

      final images = allImageUrls.asMap().entries.map((entry) {
        return ProductImage(
          id: 'img_${entry.key}',
          url: entry.value,
          order: entry.key,
        );
      }).toList();

      final product = ProductModel(
        id: productId,
        tenantId: ref.read(currentUserProvider).valueOrNull?.tenantId ?? '',
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        sku: null,
        barcode: null,
        categoryId: _selectedCategory!,
        price: double.parse(_priceController.text.replaceAll('.', '').replaceAll(',', '.')),
        costPrice: null,
        compareAtPrice: null,
        quantity: _isOnDemand ? 0 : (_quantityController.text.isNotEmpty ? int.parse(_quantityController.text) : 0),
        trackInventory: !_isOnDemand,
        status: _isActive ? 'active' : 'draft',
        visibility: 'marketplace',
        images: images,
        tags: _tags,
        hasVariants: _hasVariants,
        variants: _variants,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (_isEditing) {
        await ref.read(myProductsProvider.notifier).updateProduct(product);
      } else {
        await ref.read(myProductsProvider.notifier).createProduct(product);
      }

      // Fire-and-forget cleanup of removed images from Storage
      if (_isEditing) {
        final removedUrls = _originalImageUrls
            .where((url) => !_existingImageUrls.contains(url))
            .toList();
        for (final url in removedUrls) {
          imageUploadServiceProvider.deleteProductImage(url);
        }
      }

      if (mounted) {
        _hasUnsavedChanges = false;
        AppFeedback.showSuccess(context, _isEditing ? 'Produto atualizado!' : 'Produto criado!');
        context.go(AppRouter.sellerProducts);
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().replaceAll('Exception: ', '');
        final isPermission = errorMsg.toLowerCase().contains('permission') ||
            errorMsg.toLowerCase().contains('unauthorized');
        final isNetwork = errorMsg.toLowerCase().contains('network') ||
            errorMsg.toLowerCase().contains('socket') ||
            errorMsg.toLowerCase().contains('timeout');

        String userMessage;
        if (isPermission) {
          userMessage = 'Sem permissão para salvar. Verifique se você está logado como vendedor.';
        } else if (isNetwork) {
          userMessage = 'Erro de conexão. Verifique sua internet e tente novamente.';
        } else if (errorMsg.contains('foto') || errorMsg.contains('imagem') || errorMsg.contains('upload')) {
          userMessage = errorMsg;
        } else {
          userMessage = 'Erro ao salvar o produto. Tente novamente.';
        }
        AppFeedback.showError(context, userMessage);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag) && _tags.length < 10) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
        _hasUnsavedChanges = true;
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
      _hasUnsavedChanges = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoryModelsProvider);
    final progress = _filledSections / _totalRequiredSections;

    // B3: Gate - require MP connection for new products
    final isMpConnected = ref.watch(isMpConnectedProvider);
    if (!isMpConnected && !_isEditing) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          title: const Text('Novo Produto'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.link_off,
                  size: 64,
                  color: AppColors.textHint,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Mercado Pago necessário',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Conecte seu Mercado Pago para poder publicar produtos e receber pagamentos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => context.push(AppRouter.sellerMpConnect),
                  icon: const Icon(Icons.link),
                  label: const Text('Conectar Mercado Pago'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.sellerAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldLeave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Descartar alterações?'),
            content: const Text(
                'Você tem alterações não salvas. Deseja sair sem salvar?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Continuar editando'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.error),
                child: const Text('Descartar'),
              ),
            ],
          ),
        );
        if (shouldLeave == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => context.pop(),
          ),
        title: Row(
          children: [
            Icon(
              _isEditing ? Icons.edit_outlined : Icons.add_box_outlined,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              _isEditing ? 'Editar Produto' : 'Novo Produto',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          if (_isUploadingImages)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _totalImagesToUpload > 0
                          ? 'Enviando foto ${_uploadedImages + 1} de $_totalImagesToUpload'
                          : 'Enviando fotos...',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_isUploadingImages && _totalImagesToUpload > 0 ? 24 : 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _isUploadingImages && _totalImagesToUpload > 0
                        ? _uploadedImages / _totalImagesToUpload
                        : progress,
                    backgroundColor: Colors.white.withAlpha(50),
                    color: Colors.white,
                    minHeight: 4,
                  ),
                ),
              ),
              if (_isUploadingImages && _totalImagesToUpload > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  child: Text(
                    'Enviando foto ${_uploadedImages + 1} de $_totalImagesToUpload...',
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ),
            ],
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            // Section 1: Photos
            _SectionCard(
              key: _photosKey,
              icon: Icons.camera_alt_outlined,
              title: 'Fotos',
              subtitle: 'Adicione até 5 fotos do produto',
              hasError: _highlightedSection == 0,
              child: PhotoPickerGrid(
                initialUrls: _existingImageUrls,
                newFiles: _newImageFiles,
                onFilesChanged: (files) =>
                    setState(() {
                      _newImageFiles = files;
                      _hasUnsavedChanges = true;
                    }),
                onUrlsChanged: (urls) =>
                    setState(() {
                      _existingImageUrls = urls;
                      _hasUnsavedChanges = true;
                    }),
              ),
            ),
            const SizedBox(height: 16),

            // Section 2: Product info
            _SectionCard(
              key: _infoKey,
              icon: Icons.info_outline,
              title: 'Informações',
              subtitle: 'Nome e descrição do produto',
              hasError: _highlightedSection == 1,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nome do produto *',
                      hintText: 'Ex: Camiseta Premium Algodão',
                      prefixIcon: Icon(Icons.label_outline),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Informe o nome do produto';
                      }
                      if (value.trim().length < 3) {
                        return 'Nome muito curto (mínimo 3 caracteres)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Descrição *',
                      hintText:
                          'Descreva as características, materiais, tamanhos...',
                      prefixIcon: Icon(Icons.description_outlined),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 5,
                    maxLength: 2000,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Informe a descrição';
                      }
                      if (value.trim().length < 10) {
                        return 'Descrição muito curta (mínimo 10 caracteres)';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Section 3: Price & quantity
            _SectionCard(
              key: _priceKey,
              icon: Icons.attach_money,
              title: 'Preço e Estoque',
              subtitle: 'Defina o valor e a quantidade disponível',
              hasError: _highlightedSection == 2,
              child: Column(
                children: [
                  TextFormField(
                    controller: _priceController,
                    decoration: const InputDecoration(
                      labelText: 'Preço *',
                      prefixText: 'R\$ ',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      _BrlCurrencyFormatter(),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Informe o preço';
                      }
                      final price =
                          double.tryParse(value.replaceAll('.', '').replaceAll(',', '.'));
                      if (price == null || price <= 0) {
                        return 'Preço inválido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Sob demanda',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: const Text(
                      'Sem limite de estoque — o comprador pode encomendar',
                      style: TextStyle(fontSize: 12, color: AppColors.textHint),
                    ),
                    value: _isOnDemand,
                    activeColor: AppColors.sellerAccent,
                    onChanged: (value) {
                      setState(() {
                        _isOnDemand = value;
                        if (value) _quantityController.clear();
                        _hasUnsavedChanges = true;
                      });
                    },
                  ),
                  if (!_isOnDemand) ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _quantityController,
                      decoration: const InputDecoration(
                        labelText: 'Quantidade em estoque *',
                        suffixText: 'unidades',
                        prefixIcon: Icon(Icons.inventory_2_outlined),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      validator: (value) {
                        if (_isOnDemand) return null;
                        if (value == null || value.isEmpty) {
                          return 'Informe a quantidade em estoque';
                        }
                        final qty = int.tryParse(value);
                        if (qty == null || qty < 0) {
                          return 'Quantidade inválida';
                        }
                        return null;
                      },
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Section 4: Category
            _SectionCard(
              key: _categoryKey,
              icon: Icons.category_outlined,
              title: 'Categoria',
              subtitle: 'Escolha a categoria do produto',
              hasError: _highlightedSection == 3,
              child: categoriesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) =>
                    const Text('Erro ao carregar categorias'),
                data: (categories) {
                  final validIds = categories.map((c) => c.id).toSet();
                  return DropdownButtonFormField<String>(
                    value: _selectedCategory != null &&
                            validIds.contains(_selectedCategory)
                        ? _selectedCategory
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Categoria *',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: categories
                        .map((cat) => DropdownMenuItem(
                              value: cat.id,
                              child: Text(cat.name),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value;
                        _hasUnsavedChanges = true;
                      });
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Selecione uma categoria';
                      }
                      return null;
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Section 5: Tags
            _SectionCard(
              icon: Icons.sell_outlined,
              title: 'Tags',
              subtitle: 'Adicione até 10 tags para facilitar a busca',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _tagController,
                          decoration: InputDecoration(
                            hintText: 'Ex: algodão, premium, verão',
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              color: AppColors.sellerAccent,
                              onPressed:
                                  _tags.length < 10 ? _addTag : null,
                            ),
                          ),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _addTag(),
                          enabled: _tags.length < 10,
                        ),
                      ),
                    ],
                  ),
                  if (_tags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _tags
                            .map(
                              (tag) => Chip(
                                label: Text(
                                  tag,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                deleteIcon:
                                    const Icon(Icons.close, size: 18, color: Colors.white),
                                onDeleted: () => _removeTag(tag),
                                backgroundColor: AppColors.primaryLight,
                                side: BorderSide.none,
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Section 6: Variants
            _SectionCard(
              icon: Icons.style_outlined,
              title: 'Variantes',
              subtitle: 'Tamanhos, cores ou outras opções',
              child: VariantManager(
                initialVariants: _variants,
                onVariantsChanged: (variants) {
                  setState(() {
                    _variants = variants;
                    _hasVariants = variants.isNotEmpty;
                    _hasUnsavedChanges = true;
                  });
                },
              ),
            ),
            const SizedBox(height: 16),

            // Publish toggle
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _isActive
                          ? AppColors.secondary.withAlpha(25)
                          : Colors.grey.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _isActive
                          ? Icons.visibility
                          : Icons.visibility_off_outlined,
                      color: _isActive
                          ? AppColors.secondary
                          : AppColors.textHint,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Publicar no marketplace',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _isActive
                              ? 'Produto visível para compradores'
                              : 'Salvo como rascunho',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isActive,
                    onChanged: (value) =>
                        setState(() {
                          _isActive = value;
                          _hasUnsavedChanges = true;
                        }),
                    activeColor: AppColors.secondary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Publish button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveProduct,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.sellerAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 4,
                  shadowColor: AppColors.sellerAccent.withAlpha(80),
                ),
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.rocket_launch_outlined, size: 20),
                label: Text(
                  _isEditing ? 'Salvar alterações' : 'Publicar produto',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    ),
    );
  }
}

/// Formats digits-only input as Brazilian currency (e.g., 2990 → "29,90")
class _BrlCurrencyFormatter extends TextInputFormatter {
  /// Formats a double value as a BRL string for pre-filling the field.
  static String format(double value) {
    final cents = (value * 100).round();
    return _centsToString(cents);
  }

  static String _centsToString(int cents) {
    if (cents == 0) return '';
    final str = cents.toString().padLeft(3, '0');
    final intPart = str.substring(0, str.length - 2);
    final decPart = str.substring(str.length - 2);
    final withThousands = StringBuffer();
    int count = 0;
    for (int i = intPart.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) withThousands.write('.');
      withThousands.write(intPart[i]);
      count++;
    }
    final intFormatted = withThousands.toString().split('').reversed.join();
    return '$intFormatted,$decPart';
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return newValue.copyWith(text: '');
    }
    final cents = int.parse(digits);
    final formatted = _centsToString(cents);
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Reusable card section with icon, title and subtitle
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final bool hasError;

  const _SectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = hasError ? AppColors.error : AppColors.sellerAccent;

    Widget card = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasError ? AppColors.error.withAlpha(180) : AppColors.border,
          width: hasError ? 1.5 : 1,
        ),
        boxShadow: hasError
            ? [
                BoxShadow(
                  color: AppColors.error.withAlpha(25),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: accentColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: hasError ? AppColors.error : AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Section content
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );

    if (hasError) {
      card = card
          .animate(autoPlay: true)
          .shakeX(amount: 4, duration: 400.ms, curve: Curves.easeInOut);
    }

    return card;
  }
}
