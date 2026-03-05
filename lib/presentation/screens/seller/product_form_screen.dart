import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/router/app_router.dart';
import '../../../core/constants/marketplace_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/product_model.dart';
import '../../../data/services/image_upload_service.dart';
import '../../providers/auth_providers.dart';
import '../../providers/mercadopago_provider.dart';
import '../../providers/my_products_provider.dart';
import '../../providers/products_provider.dart';
import '../../providers/subscription_provider.dart';
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

  // Shipping fields
  String _shippingPolicy = ShippingPolicies.delivery;
  final _weightController = TextEditingController();
  final _widthController = TextEditingController();
  final _heightController = TextEditingController();
  final _lengthController = TextEditingController();
  bool _isPerishable = false;

  // Rental fields
  String _productType = 'product'; // 'product' or 'rental'
  String _rentalType = 'imovel'; // imovel, equipamento, veiculo, outro
  String _rentalPeriod = 'mensal'; // diario, semanal, mensal, anual
  final _depositController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _neighborhoodController = TextEditingController();
  final _zipCodeController = TextEditingController();
  // Imóvel-specific
  String? _propertyType;
  final _bedroomsController = TextEditingController();
  final _bathroomsController = TextEditingController();
  final _areaController = TextEditingController();
  bool _furnished = false;
  bool _petsAllowed = false;
  // Veículo-specific
  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();

  bool get _isRental => _productType == 'rental';

  // Job fields
  String _listingType = 'product'; // 'product' or 'job'
  final _companyNameController = TextEditingController();
  final _salaryController = TextEditingController();
  bool _salaryNegotiable = false;
  String? _selectedJobType;
  String? _selectedWorkMode;
  List<String> _requirements = [];
  List<String> _benefits = [];
  final _requirementController = TextEditingController();
  final _benefitController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _contactPhoneController = TextEditingController();

  bool get _isJobListing => _listingType == 'job';

  String get _announcementType {
    if (_isJobListing) return 'job';
    return _productType;
  }

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
    _shippingPolicy = product.shippingPolicy;
    if (product.weight != null) _weightController.text = product.weight!.toString();
    if (product.dimensions != null) {
      _widthController.text = product.dimensions!.width.toString();
      _heightController.text = product.dimensions!.height.toString();
      _lengthController.text = product.dimensions!.length.toString();
    }
    _isPerishable = product.isPerishable;
    _productType = product.productType;
    if (product.rentalInfo != null) {
      _rentalType = product.rentalInfo!.rentalType;
      _rentalPeriod = product.rentalInfo!.rentalPeriod;
      if (product.rentalInfo!.deposit != null) {
        _depositController.text = _BrlCurrencyFormatter.format(product.rentalInfo!.deposit!);
      }
      _propertyType = product.rentalInfo!.propertyType;
      if (product.rentalInfo!.bedrooms != null) _bedroomsController.text = product.rentalInfo!.bedrooms.toString();
      if (product.rentalInfo!.bathrooms != null) _bathroomsController.text = product.rentalInfo!.bathrooms.toString();
      if (product.rentalInfo!.area != null) _areaController.text = product.rentalInfo!.area.toString();
      _furnished = product.rentalInfo!.furnished ?? false;
      _petsAllowed = product.rentalInfo!.petsAllowed ?? false;
      if (product.rentalInfo!.brand != null) _brandController.text = product.rentalInfo!.brand!;
      if (product.rentalInfo!.model != null) _modelController.text = product.rentalInfo!.model!;
      if (product.rentalInfo!.year != null) _yearController.text = product.rentalInfo!.year.toString();
    }
    if (product.location != null) {
      if (product.location!.city != null) _cityController.text = product.location!.city!;
      if (product.location!.state != null) _stateController.text = product.location!.state!;
      if (product.location!.neighborhood != null) _neighborhoodController.text = product.location!.neighborhood!;
      if (product.location!.zipCode != null) _zipCodeController.text = product.location!.zipCode!;
    }
    // Job fields
    _listingType = product.listingType;
    if (product.companyName != null) _companyNameController.text = product.companyName!;
    if (product.salary != null) _salaryController.text = product.salary!;
    _salaryNegotiable = product.salaryNegotiable;
    _selectedJobType = product.jobType;
    _selectedWorkMode = product.workMode;
    _requirements = List.from(product.requirements);
    _benefits = List.from(product.benefits);
    if (product.contactEmail != null) _contactEmailController.text = product.contactEmail!;
    if (product.contactPhone != null) _contactPhoneController.text = product.contactPhone!;
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
    _weightController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    _lengthController.dispose();
    _depositController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _neighborhoodController.dispose();
    _zipCodeController.dispose();
    _bedroomsController.dispose();
    _bathroomsController.dispose();
    _areaController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _companyNameController.dispose();
    _salaryController.dispose();
    _requirementController.dispose();
    _benefitController.dispose();
    _contactEmailController.dispose();
    _contactPhoneController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  int? _findFirstInvalidSection() {
    if (_isJobListing) {
      // Job: photos are optional, validate info + category
      final name = _nameController.text.trim();
      final desc = _descriptionController.text.trim();
      if (name.isEmpty || name.length < 3 || desc.isEmpty || desc.length < 10) {
        return 1;
      }
      if (_selectedCategory == null || _selectedCategory!.isEmpty) return 3;
      // Require at least one contact method
      if (_contactEmailController.text.trim().isEmpty && _contactPhoneController.text.trim().isEmpty) {
        return 1;
      }
      return null;
    }
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
    // Validate at least one photo first (top of form) — skip for jobs
    if (!_isJobListing && _existingImageUrls.isEmpty && _newImageFiles.isEmpty) {
      _highlightError(0);
      AppFeedback.showWarning(context, 'Adicione pelo menos 1 foto do produto');
      return;
    }

    // Job-specific validation: require at least one contact method
    if (_isJobListing) {
      if (_contactEmailController.text.trim().isEmpty && _contactPhoneController.text.trim().isEmpty) {
        AppFeedback.showWarning(context, 'Informe ao menos um contato (email ou telefone)');
        return;
      }
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

      // Validate that we have at least one image after upload (skip for jobs)
      if (!_isJobListing && allImageUrls.isEmpty) {
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

      // Parse shipping dimensions
      final hasWeight = _weightController.text.isNotEmpty;
      final hasDimensions = _widthController.text.isNotEmpty ||
          _heightController.text.isNotEmpty ||
          _lengthController.text.isNotEmpty;

      // Build rental info if this is a rental
      RentalInfo? rentalInfo;
      if (_isRental) {
        rentalInfo = RentalInfo(
          rentalType: _rentalType,
          rentalPeriod: _rentalPeriod,
          deposit: _depositController.text.isNotEmpty
              ? double.tryParse(_depositController.text.replaceAll('.', '').replaceAll(',', '.'))
              : null,
          isAvailable: true,
          propertyType: _rentalType == 'imovel' ? _propertyType : null,
          bedrooms: _rentalType == 'imovel' && _bedroomsController.text.isNotEmpty
              ? int.tryParse(_bedroomsController.text)
              : null,
          bathrooms: _rentalType == 'imovel' && _bathroomsController.text.isNotEmpty
              ? int.tryParse(_bathroomsController.text)
              : null,
          area: _rentalType == 'imovel' && _areaController.text.isNotEmpty
              ? double.tryParse(_areaController.text)
              : null,
          furnished: _rentalType == 'imovel' ? _furnished : null,
          petsAllowed: _rentalType == 'imovel' ? _petsAllowed : null,
          brand: _rentalType == 'veiculo' && _brandController.text.isNotEmpty
              ? _brandController.text.trim()
              : null,
          model: _rentalType == 'veiculo' && _modelController.text.isNotEmpty
              ? _modelController.text.trim()
              : null,
          year: _rentalType == 'veiculo' && _yearController.text.isNotEmpty
              ? int.tryParse(_yearController.text)
              : null,
        );
      }

      // Build location (required for rentals, optional for products)
      ProductLocation? location;
      if (_cityController.text.isNotEmpty || _stateController.text.isNotEmpty) {
        location = ProductLocation(
          city: _cityController.text.trim().isNotEmpty ? _cityController.text.trim() : null,
          state: _stateController.text.trim().isNotEmpty ? _stateController.text.trim() : null,
          neighborhood: _neighborhoodController.text.trim().isNotEmpty ? _neighborhoodController.text.trim() : null,
          zipCode: _zipCodeController.text.trim().isNotEmpty ? _zipCodeController.text.trim() : null,
        );
      }

      final skipInventory = _isRental || _isJobListing;

      final product = ProductModel(
        id: productId,
        tenantId: ref.read(currentUserProvider).valueOrNull?.tenantId ?? '',
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        sku: null,
        barcode: null,
        categoryId: _selectedCategory!,
        price: _isJobListing ? 0 : double.parse(_priceController.text.replaceAll('.', '').replaceAll(',', '.')),
        costPrice: null,
        compareAtPrice: null,
        quantity: skipInventory ? 0 : (_isOnDemand ? 0 : (_quantityController.text.isNotEmpty ? int.parse(_quantityController.text) : 0)),
        trackInventory: skipInventory ? false : !_isOnDemand,
        status: _isActive ? 'active' : 'draft',
        visibility: 'marketplace',
        images: images,
        tags: _tags,
        hasVariants: skipInventory ? false : _hasVariants,
        variants: skipInventory ? [] : _variants,
        weight: hasWeight ? double.tryParse(_weightController.text) : null,
        dimensions: hasDimensions
            ? ProductDimensions(
                width: double.tryParse(_widthController.text) ?? 0,
                height: double.tryParse(_heightController.text) ?? 0,
                length: double.tryParse(_lengthController.text) ?? 0,
              )
            : null,
        isPerishable: _isPerishable,
        shippingPolicy: skipInventory ? 'pickup_only' : _shippingPolicy,
        productType: _productType,
        rentalInfo: rentalInfo,
        location: location,
        listingType: _listingType,
        companyName: _isJobListing ? _companyNameController.text.trim() : null,
        salary: _isJobListing ? (_salaryNegotiable ? null : _salaryController.text.trim()) : null,
        salaryNegotiable: _isJobListing ? _salaryNegotiable : false,
        jobType: _isJobListing ? _selectedJobType : null,
        workMode: _isJobListing ? _selectedWorkMode : null,
        requirements: _isJobListing ? _requirements : [],
        benefits: _isJobListing ? _benefits : [],
        contactEmail: _isJobListing ? (_contactEmailController.text.trim().isNotEmpty ? _contactEmailController.text.trim() : null) : null,
        contactPhone: _isJobListing ? (_contactPhoneController.text.trim().isNotEmpty ? _contactPhoneController.text.trim() : null) : null,
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
        AppFeedback.showSuccess(context, _isEditing
            ? (_isJobListing ? 'Vaga atualizada!' : 'Produto atualizado!')
            : (_isJobListing ? 'Vaga criada!' : 'Produto criado!'));
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
    final canCreateRentals = ref.watch(canCreateRentalsProvider);
    final canCreateJobs = ref.watch(canCreateJobsProvider);
    final canCreateServices = ref.watch(canCreateServicesProvider);
    final hasLockedTypes = !canCreateRentals || !canCreateJobs || !canCreateServices;

    // B3: Gate - require MP connection for new products (skip for jobs)
    final isMpConnected = ref.watch(isMpConnectedProvider);
    if (!isMpConnected && !_isEditing && !_isJobListing) {
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
              _isJobListing
                  ? Icons.work_outlined
                  : (_isEditing ? Icons.edit_outlined : Icons.add_box_outlined),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              _isJobListing
                  ? (_isEditing ? 'Editar Vaga' : 'Nova Vaga')
                  : (_isEditing ? 'Editar Produto' : 'Novo Produto'),
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
            // Section 0: Product Type selector
            if (!_isEditing)
              _SectionCard(
                icon: Icons.dashboard_outlined,
                title: 'Tipo de Anúncio',
                subtitle: 'Produto, aluguel, serviço ou vaga de emprego',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SegmentedButton<String>(
                      segments: [
                        const ButtonSegment(
                          value: 'product',
                          label: Text('Produto'),
                          icon: Icon(Icons.shopping_bag_outlined, size: 18),
                        ),
                        ButtonSegment(
                          value: 'rental',
                          label: const Text('Aluguel'),
                          icon: Icon(
                            canCreateRentals ? Icons.vpn_key_rounded : Icons.lock_outlined,
                            size: 18,
                          ),
                          enabled: canCreateRentals,
                        ),
                        ButtonSegment(
                          value: 'service',
                          label: const Text('Serviço'),
                          icon: Icon(
                            canCreateServices ? Icons.handyman_outlined : Icons.lock_outlined,
                            size: 18,
                          ),
                          enabled: canCreateServices,
                        ),
                        ButtonSegment(
                          value: 'job',
                          label: const Text('Vaga'),
                          icon: Icon(
                            canCreateJobs ? Icons.work_outlined : Icons.lock_outlined,
                            size: 18,
                          ),
                          enabled: canCreateJobs,
                        ),
                      ],
                      selected: {_announcementType},
                      onSelectionChanged: (value) {
                        final type = value.first;
                        if (type == 'rental' && !canCreateRentals) return;
                        if (type == 'job' && !canCreateJobs) return;
                        if (type == 'service') {
                          if (!canCreateServices) return;
                          context.push(AppRouter.sellerServiceNew);
                          return;
                        }
                        setState(() {
                          if (type == 'job') {
                            _listingType = 'job';
                            _productType = 'product';
                          } else {
                            _listingType = 'product';
                            _productType = type;
                          }
                          _hasUnsavedChanges = true;
                        });
                      },
                    ),
                    if (hasLockedTypes) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: AppColors.primary.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Atualize seu plano para desbloquear alugueis, serviços e vagas de emprego.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_isRental) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Tipo de aluguel',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _rentalType,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.category_outlined),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'imovel', child: Text('Imóvel')),
                          DropdownMenuItem(value: 'equipamento', child: Text('Equipamento')),
                          DropdownMenuItem(value: 'veiculo', child: Text('Veículo')),
                          DropdownMenuItem(value: 'outro', child: Text('Outro')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _rentalType = value;
                              _hasUnsavedChanges = true;
                            });
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
            if (!_isEditing) const SizedBox(height: 16),

            // Section 1: Photos
            _SectionCard(
              key: _photosKey,
              icon: Icons.camera_alt_outlined,
              title: _isJobListing ? 'Logo / Imagem (opcional)' : 'Fotos',
              subtitle: _isJobListing
                  ? 'Adicione a logo ou imagem da empresa'
                  : 'Adicione até 5 fotos do produto',
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

            // Section 2: Product info (or Job info)
            _SectionCard(
              key: _infoKey,
              icon: _isJobListing ? Icons.business_outlined : Icons.info_outline,
              title: _isJobListing ? 'Informações da Vaga' : 'Informações',
              subtitle: _isJobListing
                  ? 'Empresa, título e descrição da vaga'
                  : 'Nome e descrição do produto',
              hasError: _highlightedSection == 1,
              child: Column(
                children: [
                  if (_isJobListing) ...[
                    TextFormField(
                      controller: _companyNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nome da empresa *',
                        hintText: 'Ex: Tech Solutions Ltda',
                        prefixIcon: Icon(Icons.business),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (!_isJobListing) return null;
                        if (value == null || value.trim().isEmpty) {
                          return 'Informe o nome da empresa';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: _isJobListing ? 'Título da vaga *' : 'Nome do produto *',
                      hintText: _isJobListing
                          ? 'Ex: Desenvolvedor Flutter Pleno'
                          : 'Ex: Camiseta Premium Algodão',
                      prefixIcon: Icon(_isJobListing ? Icons.work_outline : Icons.label_outline),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return _isJobListing ? 'Informe o título da vaga' : 'Informe o nome do produto';
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
                    decoration: InputDecoration(
                      labelText: _isJobListing ? 'Descrição da vaga *' : 'Descrição *',
                      hintText: _isJobListing
                          ? 'Descreva as responsabilidades, atividades, diferenciais...'
                          : 'Descreva as características, materiais, tamanhos...',
                      prefixIcon: const Icon(Icons.description_outlined),
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

            // Section 3: Price & quantity (hidden for jobs, adapted for rentals)
            if (!_isJobListing)
            _SectionCard(
              key: _priceKey,
              icon: Icons.attach_money,
              title: _isRental ? 'Valor do Aluguel' : 'Preço e Estoque',
              subtitle: _isRental
                  ? 'Defina o valor e período do aluguel'
                  : 'Defina o valor e a quantidade disponível',
              hasError: _highlightedSection == 2,
              child: Column(
                children: [
                  TextFormField(
                    controller: _priceController,
                    decoration: InputDecoration(
                      labelText: _isRental ? 'Valor do aluguel *' : 'Preço *',
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
                  // Rental-specific: period selector + deposit
                  if (_isRental) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Período',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'diario', label: Text('Diário')),
                        ButtonSegment(value: 'semanal', label: Text('Semanal')),
                        ButtonSegment(value: 'mensal', label: Text('Mensal')),
                        ButtonSegment(value: 'anual', label: Text('Anual')),
                      ],
                      selected: {_rentalPeriod},
                      onSelectionChanged: (value) {
                        setState(() {
                          _rentalPeriod = value.first;
                          _hasUnsavedChanges = true;
                        });
                      },
                      style: SegmentedButton.styleFrom(
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _depositController,
                      decoration: const InputDecoration(
                        labelText: 'Caução (opcional)',
                        prefixText: 'R\$ ',
                        prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                        hintText: 'Valor de garantia',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        _BrlCurrencyFormatter(),
                      ],
                    ),
                  ],
                  // Product-specific: stock controls
                  if (!_isRental) ...[
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
                          if (_isOnDemand || _isRental) return null;
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
                ],
              ),
            ),
            if (!_isJobListing) const SizedBox(height: 16),

            // ── Job-specific sections ──
            if (_isJobListing) ...[
              const SizedBox(height: 16),
              // Salary
              _SectionCard(
                icon: Icons.attach_money,
                title: 'Salário',
                subtitle: 'Informe a faixa salarial da vaga',
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'A combinar',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: const Text(
                        'Salário será negociado com o candidato',
                        style: TextStyle(fontSize: 12, color: AppColors.textHint),
                      ),
                      value: _salaryNegotiable,
                      activeColor: AppColors.sellerAccent,
                      onChanged: (value) {
                        setState(() {
                          _salaryNegotiable = value;
                          if (value) _salaryController.clear();
                          _hasUnsavedChanges = true;
                        });
                      },
                    ),
                    if (!_salaryNegotiable) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _salaryController,
                        decoration: const InputDecoration(
                          labelText: 'Salário',
                          hintText: 'Ex: R\$ 3.000 a R\$ 5.000',
                          prefixIcon: Icon(Icons.payments_outlined),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Job Type & Work Mode
              _SectionCard(
                icon: Icons.badge_outlined,
                title: 'Tipo e Modalidade',
                subtitle: 'Regime de contratação e local de trabalho',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tipo de vaga',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedJobType,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.work_outline),
                        hintText: 'Selecione o tipo',
                      ),
                      items: JobTypes.labels.entries
                          .map((e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedJobType = value;
                          _hasUnsavedChanges = true;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Modalidade de trabalho',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedWorkMode,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.location_on_outlined),
                        hintText: 'Selecione a modalidade',
                      ),
                      items: WorkModes.labels.entries
                          .map((e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedWorkMode = value;
                          _hasUnsavedChanges = true;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Requirements
              _SectionCard(
                icon: Icons.checklist_outlined,
                title: 'Requisitos',
                subtitle: 'Liste os requisitos para a vaga',
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _requirementController,
                            decoration: InputDecoration(
                              hintText: 'Ex: Experiência com Flutter',
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                color: AppColors.sellerAccent,
                                onPressed: () {
                                  final text = _requirementController.text.trim();
                                  if (text.isNotEmpty && !_requirements.contains(text)) {
                                    setState(() {
                                      _requirements.add(text);
                                      _requirementController.clear();
                                      _hasUnsavedChanges = true;
                                    });
                                  }
                                },
                              ),
                            ),
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) {
                              final text = _requirementController.text.trim();
                              if (text.isNotEmpty && !_requirements.contains(text)) {
                                setState(() {
                                  _requirements.add(text);
                                  _requirementController.clear();
                                  _hasUnsavedChanges = true;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    if (_requirements.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _requirements
                              .map((req) => Chip(
                                    label: Text(req, style: const TextStyle(fontSize: 13)),
                                    deleteIcon: const Icon(Icons.close, size: 18),
                                    onDeleted: () {
                                      setState(() {
                                        _requirements.remove(req);
                                        _hasUnsavedChanges = true;
                                      });
                                    },
                                    backgroundColor: AppColors.primary.withAlpha(20),
                                    side: BorderSide.none,
                                  ))
                              .toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Benefits
              _SectionCard(
                icon: Icons.card_giftcard_outlined,
                title: 'Benefícios',
                subtitle: 'Liste os benefícios oferecidos',
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _benefitController,
                            decoration: InputDecoration(
                              hintText: 'Ex: Vale refeição, Plano de saúde',
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                color: AppColors.sellerAccent,
                                onPressed: () {
                                  final text = _benefitController.text.trim();
                                  if (text.isNotEmpty && !_benefits.contains(text)) {
                                    setState(() {
                                      _benefits.add(text);
                                      _benefitController.clear();
                                      _hasUnsavedChanges = true;
                                    });
                                  }
                                },
                              ),
                            ),
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) {
                              final text = _benefitController.text.trim();
                              if (text.isNotEmpty && !_benefits.contains(text)) {
                                setState(() {
                                  _benefits.add(text);
                                  _benefitController.clear();
                                  _hasUnsavedChanges = true;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    if (_benefits.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _benefits
                              .map((ben) => Chip(
                                    label: Text(ben, style: const TextStyle(fontSize: 13)),
                                    deleteIcon: const Icon(Icons.close, size: 18),
                                    onDeleted: () {
                                      setState(() {
                                        _benefits.remove(ben);
                                        _hasUnsavedChanges = true;
                                      });
                                    },
                                    backgroundColor: AppColors.secondary.withAlpha(20),
                                    side: BorderSide.none,
                                  ))
                              .toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Contact
              _SectionCard(
                icon: Icons.contact_mail_outlined,
                title: 'Contato',
                subtitle: 'Informe ao menos um meio de contato',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _contactEmailController,
                      decoration: const InputDecoration(
                        labelText: 'Email de contato',
                        hintText: 'rh@empresa.com',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _contactPhoneController,
                      decoration: const InputDecoration(
                        labelText: 'Telefone / WhatsApp',
                        hintText: '(11) 99999-9999',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Section: Rental Location (required for rentals)
            if (_isRental)
              _SectionCard(
                icon: Icons.location_on_outlined,
                title: 'Localização',
                subtitle: 'Informe a localização do imóvel/item',
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _cityController,
                            decoration: const InputDecoration(
                              labelText: 'Cidade *',
                              prefixIcon: Icon(Icons.location_city),
                            ),
                            validator: (value) {
                              if (_isRental && (value == null || value.trim().isEmpty)) {
                                return 'Informe a cidade';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _stateController,
                            decoration: const InputDecoration(
                              labelText: 'UF *',
                            ),
                            textCapitalization: TextCapitalization.characters,
                            maxLength: 2,
                            validator: (value) {
                              if (_isRental && (value == null || value.trim().isEmpty)) {
                                return 'UF';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _neighborhoodController,
                      decoration: const InputDecoration(
                        labelText: 'Bairro (opcional)',
                        prefixIcon: Icon(Icons.map_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _zipCodeController,
                      decoration: const InputDecoration(
                        labelText: 'CEP (opcional)',
                        prefixIcon: Icon(Icons.pin_drop_outlined),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      maxLength: 8,
                    ),
                  ],
                ),
              ),
            if (_isRental) const SizedBox(height: 16),

            // Section: Rental Details (conditional on rental type)
            if (_isRental && _rentalType == 'imovel')
              _SectionCard(
                icon: Icons.home_outlined,
                title: 'Detalhes do Imóvel',
                subtitle: 'Informações específicas do imóvel',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _propertyType,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de imóvel',
                        prefixIcon: Icon(Icons.home_work_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'apartamento', child: Text('Apartamento')),
                        DropdownMenuItem(value: 'casa', child: Text('Casa')),
                        DropdownMenuItem(value: 'sala_comercial', child: Text('Sala Comercial')),
                        DropdownMenuItem(value: 'terreno', child: Text('Terreno')),
                        DropdownMenuItem(value: 'kitnet', child: Text('Kitnet')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _propertyType = value;
                          _hasUnsavedChanges = true;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _bedroomsController,
                            decoration: const InputDecoration(
                              labelText: 'Quartos',
                              prefixIcon: Icon(Icons.bed_outlined),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _bathroomsController,
                            decoration: const InputDecoration(
                              labelText: 'Banheiros',
                              prefixIcon: Icon(Icons.bathtub_outlined),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _areaController,
                      decoration: const InputDecoration(
                        labelText: 'Área (m²)',
                        prefixIcon: Icon(Icons.square_foot),
                        suffixText: 'm²',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Mobiliado', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      value: _furnished,
                      activeColor: AppColors.sellerAccent,
                      onChanged: (v) => setState(() { _furnished = v; _hasUnsavedChanges = true; }),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Aceita pets', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      value: _petsAllowed,
                      activeColor: AppColors.sellerAccent,
                      onChanged: (v) => setState(() { _petsAllowed = v; _hasUnsavedChanges = true; }),
                    ),
                  ],
                ),
              ),
            if (_isRental && _rentalType == 'imovel') const SizedBox(height: 16),

            if (_isRental && _rentalType == 'veiculo')
              _SectionCard(
                icon: Icons.directions_car,
                title: 'Detalhes do Veículo',
                subtitle: 'Informações do veículo',
                child: Column(
                  children: [
                    TextFormField(
                      controller: _brandController,
                      decoration: const InputDecoration(
                        labelText: 'Marca',
                        prefixIcon: Icon(Icons.branding_watermark_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _modelController,
                      decoration: const InputDecoration(
                        labelText: 'Modelo',
                        prefixIcon: Icon(Icons.label_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _yearController,
                      decoration: const InputDecoration(
                        labelText: 'Ano',
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      maxLength: 4,
                    ),
                  ],
                ),
              ),
            if (_isRental && _rentalType == 'veiculo') const SizedBox(height: 16),

            // Section: Shipping (hidden for rentals and jobs)
            if (!_isRental && !_isJobListing)
            _SectionCard(
              icon: Icons.local_shipping_outlined,
              title: 'Envio',
              subtitle: 'Configure a política de entrega do produto',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Shipping policy
                  Text(
                    'Política de frete',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: ShippingPolicies.delivery,
                        label: Text(ShippingPolicies.labels[ShippingPolicies.delivery]!),
                        icon: const Icon(Icons.local_shipping_outlined, size: 18),
                      ),
                      ButtonSegment(
                        value: ShippingPolicies.pickupOnly,
                        label: Text(ShippingPolicies.labels[ShippingPolicies.pickupOnly]!),
                        icon: const Icon(Icons.store_outlined, size: 18),
                      ),
                      ButtonSegment(
                        value: ShippingPolicies.sellerArranges,
                        label: Text(ShippingPolicies.labels[ShippingPolicies.sellerArranges]!),
                        icon: const Icon(Icons.handshake_outlined, size: 18),
                      ),
                    ],
                    selected: {_shippingPolicy},
                    onSelectionChanged: (value) {
                      setState(() {
                        _shippingPolicy = value.first;
                        _hasUnsavedChanges = true;
                      });
                    },
                    style: SegmentedButton.styleFrom(
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                  // Weight, dimensions, perishable — only shown for delivery policy
                  if (_shippingPolicy == ShippingPolicies.delivery) ...[
                    const SizedBox(height: 16),

                    // Weight
                    TextFormField(
                      controller: _weightController,
                      decoration: const InputDecoration(
                        labelText: 'Peso (opcional)',
                        suffixText: 'kg',
                        prefixIcon: Icon(Icons.scale_outlined),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Dimensions
                    Text(
                      'Dimensões (opcional)',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textHint,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _widthController,
                            decoration: const InputDecoration(
                              labelText: 'Larg.',
                              suffixText: 'cm',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _heightController,
                            decoration: const InputDecoration(
                              labelText: 'Alt.',
                              suffixText: 'cm',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _lengthController,
                            decoration: const InputDecoration(
                              labelText: 'Comp.',
                              suffixText: 'cm',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Perishable toggle
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Produto perecível',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      subtitle: const Text(
                        'Requer entrega rápida e cuidados especiais',
                        style: TextStyle(fontSize: 12, color: AppColors.textHint),
                      ),
                      value: _isPerishable,
                      activeColor: AppColors.sellerAccent,
                      onChanged: (value) {
                        setState(() {
                          _isPerishable = value;
                          _hasUnsavedChanges = true;
                        });
                      },
                    ),
                  ],
                ],
              ),
            ),
            if (!_isRental && !_isJobListing) const SizedBox(height: 16),

            // Section 4: Category
            _SectionCard(
              key: _categoryKey,
              icon: Icons.category_outlined,
              title: 'Categoria',
              subtitle: _isJobListing ? 'Escolha a categoria da vaga' : 'Escolha a categoria do produto',
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
            if (!_isRental && !_isJobListing) const SizedBox(height: 16),

            // Section 6: Variants (hidden for rentals and jobs)
            if (!_isRental && !_isJobListing)
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
                              ? (_isJobListing ? 'Vaga visível para candidatos' : 'Produto visível para compradores')
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
                  _isEditing
                      ? 'Salvar alterações'
                      : (_isJobListing ? 'Publicar vaga' : 'Publicar produto'),
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
