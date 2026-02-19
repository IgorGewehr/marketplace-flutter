import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/product_model.dart';
import '../../../data/services/image_upload_service.dart';
import '../../providers/auth_providers.dart';
import '../../providers/my_products_provider.dart';
import '../../providers/products_provider.dart';
import '../../widgets/seller/photo_picker_grid.dart';
import '../../widgets/seller/variant_manager.dart';

/// Product form screen for creating/editing products - Simplified for marketplace
class ProductFormScreen extends ConsumerStatefulWidget {
  final String? productId;

  const ProductFormScreen({super.key, this.productId});

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
  List<File> _newImageFiles = [];
  List<ProductVariant> _variants = [];
  bool _hasVariants = false;

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
    if (_isEditing) {
      _loadProduct();
    }
  }

  void _onFieldChanged() {
    setState(() {});
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
    _nameController.text = product.name;
    _descriptionController.text = product.description;
    _priceController.text = product.price.toStringAsFixed(2);
    _quantityController.text = product.quantity?.toString() ?? '';
    _isActive = product.status == 'active';
    _selectedCategory = product.categoryId;
    _tags = List.from(product.tags);
    _existingImageUrls = product.images.map((i) => i.url).toList();
    _variants = List.from(product.variants);
    _hasVariants = product.hasVariants;

    // Validate category after frame so categoriesProvider is loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _validateSelectedCategory();
    });
  }

  void _validateSelectedCategory() {
    final categories = ref.read(categoriesProvider).valueOrNull ?? [];
    final filtered = categories.where((c) => c != 'Todos').toList();
    if (_selectedCategory != null && !filtered.contains(_selectedCategory)) {
      setState(() => _selectedCategory = null);
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_onFieldChanged);
    _descriptionController.removeListener(_onFieldChanged);
    _priceController.removeListener(_onFieldChanged);
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate at least one photo
    if (_existingImageUrls.isEmpty && _newImageFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Adicione pelo menos 1 foto do produto'),
          backgroundColor: AppColors.error,
        ),
      );
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

      // Upload new images to Firebase Storage
      if (_newImageFiles.isNotEmpty) {
        final productId = widget.productId ?? const Uuid().v4();
        final uploadService = imageUploadServiceProvider;

        final uploadedUrls = await uploadService.uploadProductImages(
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

      final images = allImageUrls.asMap().entries.map((entry) {
        return ProductImage(
          id: 'img_${entry.key}',
          url: entry.value,
          order: entry.key,
        );
      }).toList();

      final product = ProductModel(
        id: widget.productId ?? const Uuid().v4(),
        tenantId: ref.read(currentUserProvider).valueOrNull?.tenantId ?? '',
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        sku: null,
        barcode: null,
        categoryId: _selectedCategory ?? 'Outros',
        price: double.parse(_priceController.text.replaceAll(',', '.')),
        costPrice: null,
        compareAtPrice: null,
        quantity: _quantityController.text.isNotEmpty
            ? int.parse(_quantityController.text)
            : null,
        trackInventory: true,
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(_isEditing ? 'Produto atualizado!' : 'Produto criado!'),
            backgroundColor: AppColors.secondary,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: AppColors.error,
          ),
        );
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
      });
    }
  }

  void _removeTag(String tag) {
    setState(() => _tags.remove(tag));
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final progress = _filledSections / _totalRequiredSections;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.sellerAccent,
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
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                    value: _totalImagesToUpload > 0
                        ? _uploadedImages / _totalImagesToUpload
                        : null,
                  ),
                ),
              ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withAlpha(50),
                color: Colors.white,
                minHeight: 4,
              ),
            ),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Section 1: Photos
            _SectionCard(
              icon: Icons.camera_alt_outlined,
              title: 'Fotos',
              subtitle: 'Adicione até 5 fotos do produto',
              child: PhotoPickerGrid(
                initialUrls: _existingImageUrls,
                newFiles: _newImageFiles,
                onFilesChanged: (files) =>
                    setState(() => _newImageFiles = files),
                onUrlsChanged: (urls) =>
                    setState(() => _existingImageUrls = urls),
              ),
            ),
            const SizedBox(height: 16),

            // Section 2: Product info
            _SectionCard(
              icon: Icons.info_outline,
              title: 'Informações',
              subtitle: 'Nome e descrição do produto',
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
              icon: Icons.attach_money,
              title: 'Preço e Estoque',
              subtitle: 'Defina o valor e a quantidade disponível',
              child: Column(
                children: [
                  TextFormField(
                    controller: _priceController,
                    decoration: const InputDecoration(
                      labelText: 'Preço *',
                      prefixText: 'R\$ ',
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Informe o preço';
                      }
                      final price =
                          double.tryParse(value.replaceAll(',', '.'));
                      if (price == null || price <= 0) {
                        return 'Preço inválido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _quantityController,
                    decoration: const InputDecoration(
                      labelText: 'Quantidade em estoque',
                      suffixText: 'unidades',
                      prefixIcon: Icon(Icons.inventory_2_outlined),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Section 4: Category
            _SectionCard(
              icon: Icons.category_outlined,
              title: 'Categoria',
              subtitle: 'Escolha a categoria do produto',
              child: categoriesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) =>
                    const Text('Erro ao carregar categorias'),
                data: (categories) {
                  final filtered =
                      categories.where((c) => c != 'Todos').toList();
                  return DropdownButtonFormField<String>(
                    value: _selectedCategory != null &&
                            filtered.contains(_selectedCategory)
                        ? _selectedCategory
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Categoria *',
                      prefixIcon: Icon(Icons.category_outlined),
                    ),
                    items: filtered
                        .map((cat) => DropdownMenuItem(
                              value: cat,
                              child: Text(cat),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() => _selectedCategory = value);
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
                                label: Text(tag),
                                deleteIcon:
                                    const Icon(Icons.close, size: 18),
                                onDeleted: () => _removeTag(tag),
                                backgroundColor: AppColors.sellerAccent
                                    .withAlpha((255 * 0.1).round()),
                                side: BorderSide(
                                  color: AppColors.sellerAccent
                                      .withAlpha((255 * 0.3).round()),
                                ),
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
                        setState(() => _isActive = value),
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
    );
  }
}

/// Reusable card section with icon, title and subtitle
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.sellerAccent.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: AppColors.sellerAccent,
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
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textHint,
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
  }
}
