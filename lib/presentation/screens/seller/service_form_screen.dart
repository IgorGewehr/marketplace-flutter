import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/service_model.dart';
import '../../../domain/repositories/service_repository.dart';
import '../../providers/my_services_provider.dart';
import '../../providers/products_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../widgets/seller/photo_picker_grid.dart';
import '../../widgets/shared/app_feedback.dart';

/// Service form screen for creating/editing services
class ServiceFormScreen extends ConsumerStatefulWidget {
  final String? serviceId;

  const ServiceFormScreen({super.key, this.serviceId});

  @override
  ConsumerState<ServiceFormScreen> createState() => _ServiceFormScreenState();
}

class _ServiceFormScreenState extends ConsumerState<ServiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _shortDescriptionController = TextEditingController();
  final _basePriceController = TextEditingController();
  final _minPriceController = TextEditingController();
  final _maxPriceController = TextEditingController();
  final _experienceController = TextEditingController();

  bool _isLoading = false;
  bool _hasUnsavedChanges = false;
  bool _isActive = true;
  bool _isAvailable = true;
  bool _isRemote = false;
  bool _isOnSite = true;
  bool _acceptsQuote = true;
  bool _instantBooking = false;
  bool _scheduleEnabled = false;
  int _slotDurationMinutes = 60;
  int _breakBetweenMinutes = 0;
  Map<String, bool> _scheduleDays = {
    'monday': false,
    'tuesday': false,
    'wednesday': false,
    'thursday': false,
    'friday': false,
    'saturday': false,
    'sunday': false,
  };
  Map<String, String> _scheduleStart = {};
  Map<String, String> _scheduleEnd = {};

  String _selectedCategory = '';
  String _pricingType = 'fixed';
  List<String> _requirements = [];
  List<String> _includes = [];
  List<String> _certifications = [];
  List<ServiceArea> _serviceAreas = [];
  List<String> _existingImageUrls = [];
  List<File> _newImageFiles = [];

  bool get _isEditing => widget.serviceId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadService();
    }
  }

  void _loadService() {
    final services = ref.read(myServicesProvider).valueOrNull ?? [];
    final service = services.where((s) => s.id == widget.serviceId).firstOrNull;
    if (service != null) {
      _nameController.text = service.name;
      _descriptionController.text = service.description;
      _shortDescriptionController.text = service.shortDescription ?? '';
      _basePriceController.text = service.basePrice.toStringAsFixed(2);
      if (service.minPrice != null) {
        _minPriceController.text = service.minPrice!.toStringAsFixed(2);
      }
      if (service.maxPrice != null) {
        _maxPriceController.text = service.maxPrice!.toStringAsFixed(2);
      }
      _experienceController.text = service.experience ?? '';

      _isActive = service.status == 'active';
      _isAvailable = service.isAvailable;
      _isRemote = service.isRemote;
      _isOnSite = service.isOnSite;
      _acceptsQuote = service.acceptsQuote;
      _instantBooking = service.instantBooking;
      _selectedCategory = service.categoryId;
      _pricingType = service.pricingType;
      _requirements = List.from(service.requirements);
      _includes = List.from(service.includes);
      _certifications = List.from(service.certifications);
      _serviceAreas = List.from(service.serviceAreas);
      _existingImageUrls = service.images.map((i) => i.url).toList();

      // Schedule fields
      _scheduleEnabled = service.scheduleEnabled;
      _slotDurationMinutes = service.slotDurationMinutes;
      _breakBetweenMinutes = service.breakBetweenMinutes;
      for (final day in service.availableDays) {
        _scheduleDays[day] = true;
      }
      if (service.serviceHours != null) {
        for (final entry in service.serviceHours!.allDays.entries) {
          if (entry.value != null) {
            final parts = entry.value!.split('-');
            if (parts.length == 2) {
              _scheduleStart[entry.key] = parts[0];
              _scheduleEnd[entry.key] = parts[1];
            }
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _shortDescriptionController.dispose();
    _basePriceController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  Widget _buildCategoryDropdown() {
    final categoriesAsync = ref.watch(categoryModelsProvider);

    return categoriesAsync.when(
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const InputDecorator(
            decoration: InputDecoration(labelText: 'Categoria *'),
            child: LinearProgressIndicator(),
          ),
        ],
      ),
      error: (_, __) => _categoryDropdownItems(_fallbackServiceCategories()),
      data: (categories) {
        final validIds = categories.map((c) => c.id).toSet();
        final effectiveValue = _selectedCategory.isNotEmpty && validIds.contains(_selectedCategory)
            ? _selectedCategory
            : null;
        return DropdownButtonFormField<String>(
          value: effectiveValue,
          decoration: const InputDecoration(
            labelText: 'Categoria *',
          ),
          items: categories
              .map((cat) => DropdownMenuItem(
                    value: cat.id,
                    child: Text(cat.name),
                  ))
              .toList(),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Selecione uma categoria';
            }
            return null;
          },
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedCategory = value;
                _hasUnsavedChanges = true;
              });
            }
          },
        );
      },
    );
  }

  Widget _categoryDropdownItems(List<({String id, String name})> items) {
    final effectiveValue = _selectedCategory.isNotEmpty &&
            items.any((c) => c.id == _selectedCategory)
        ? _selectedCategory
        : null;
    return DropdownButtonFormField<String>(
      value: effectiveValue,
      decoration: const InputDecoration(
        labelText: 'Categoria *',
      ),
      items: items
          .map((cat) => DropdownMenuItem(
                value: cat.id,
                child: Text(cat.name),
              ))
          .toList(),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Selecione uma categoria';
        }
        return null;
      },
      onChanged: (value) {
        if (value != null) {
          setState(() {
            _selectedCategory = value;
            _hasUnsavedChanges = true;
          });
        }
      },
    );
  }

  List<({String id, String name})> _fallbackServiceCategories() {
    return const [
      (id: 'reformas', name: 'Reformas e Reparos'),
      (id: 'beleza', name: 'Beleza e Estética'),
      (id: 'saude', name: 'Saúde e Bem-estar'),
      (id: 'educacao', name: 'Educação e Aulas'),
      (id: 'tecnologia', name: 'Tecnologia e TI'),
      (id: 'consultoria', name: 'Consultoria e Negócios'),
      (id: 'eventos', name: 'Eventos e Festas'),
      (id: 'limpeza', name: 'Limpeza e Conservação'),
      (id: 'transporte', name: 'Transporte e Logística'),
      (id: 'pet', name: 'Pet Services'),
    ];
  }

  Future<void> _saveService() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate at least one photo
    if (_existingImageUrls.isEmpty && _newImageFiles.isEmpty) {
      AppFeedback.showWarning(context, 'Adicione pelo menos 1 foto do serviço');
      return;
    }

    // Validate service delivery method
    if (!_isRemote && !_isOnSite) {
      AppFeedback.showWarning(context, 'Selecione pelo menos um tipo de atendimento');
      return;
    }

    setState(() => _isLoading = true);

    // Build schedule data
    final activeDays = _scheduleDays.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
    final serviceHoursMap = <String, String>{};
    for (final day in activeDays) {
      final start = _scheduleStart[day] ?? '08:00';
      final end = _scheduleEnd[day] ?? '18:00';
      serviceHoursMap[day] = '$start-$end';
    }

    try {
      final request = _isEditing
          ? UpdateServiceRequest(
              name: _nameController.text.trim(),
              description: _descriptionController.text.trim(),
              shortDescription: _shortDescriptionController.text.trim().isEmpty
                  ? null
                  : _shortDescriptionController.text.trim(),
              categoryId: _selectedCategory,
              pricingType: _pricingType,
              basePrice: double.parse(_basePriceController.text.replaceAll(',', '.')),
              minPrice: _minPriceController.text.isEmpty
                  ? null
                  : double.parse(_minPriceController.text.replaceAll(',', '.')),
              maxPrice: _maxPriceController.text.isEmpty
                  ? null
                  : double.parse(_maxPriceController.text.replaceAll(',', '.')),
              isRemote: _isRemote,
              isOnSite: _isOnSite,
              isAvailable: _isAvailable,
              serviceAreas: _serviceAreas,
              requirements: _requirements,
              includes: _includes,
              certifications: _certifications,
              experience: _experienceController.text.trim().isEmpty
                  ? null
                  : _experienceController.text.trim(),
              status: _isActive ? 'active' : 'draft',
              acceptsQuote: _acceptsQuote,
              instantBooking: _instantBooking,
              scheduleEnabled: _scheduleEnabled,
              slotDurationMinutes: _slotDurationMinutes,
              breakBetweenMinutes: _breakBetweenMinutes,
              availableDays: activeDays,
              serviceHours: serviceHoursMap.isNotEmpty ? serviceHoursMap : null,
            )
          : CreateServiceRequest(
              name: _nameController.text.trim(),
              description: _descriptionController.text.trim(),
              shortDescription: _shortDescriptionController.text.trim().isEmpty
                  ? null
                  : _shortDescriptionController.text.trim(),
              categoryId: _selectedCategory,
              pricingType: _pricingType,
              basePrice: double.parse(_basePriceController.text.replaceAll(',', '.')),
              minPrice: _minPriceController.text.isEmpty
                  ? null
                  : double.parse(_minPriceController.text.replaceAll(',', '.')),
              maxPrice: _maxPriceController.text.isEmpty
                  ? null
                  : double.parse(_maxPriceController.text.replaceAll(',', '.')),
              isRemote: _isRemote,
              isOnSite: _isOnSite,
              serviceAreas: _serviceAreas,
              requirements: _requirements,
              includes: _includes,
              certifications: _certifications,
              experience: _experienceController.text.trim().isEmpty
                  ? null
                  : _experienceController.text.trim(),
              acceptsQuote: _acceptsQuote,
              instantBooking: _instantBooking,
              scheduleEnabled: _scheduleEnabled,
              slotDurationMinutes: _slotDurationMinutes,
              breakBetweenMinutes: _breakBetweenMinutes,
              availableDays: activeDays,
              serviceHours: serviceHoursMap.isNotEmpty ? serviceHoursMap : null,
            );

      String? targetServiceId = widget.serviceId;

      if (_isEditing) {
        await ref.read(myServicesProvider.notifier).updateService(
              widget.serviceId!,
              request as UpdateServiceRequest,
            );
      } else {
        await ref.read(myServicesProvider.notifier).createService(
              request as CreateServiceRequest,
            );
        // After creation, retrieve the new service's ID from provider state
        // (the notifier prepends the newly created service to the list)
        targetServiceId =
            ref.read(myServicesProvider).valueOrNull?.firstOrNull?.id;
      }

      // Upload new images if any
      if (_newImageFiles.isNotEmpty && targetServiceId != null) {
        final paths = _newImageFiles.map((f) => f.path).toList();
        await ref.read(myServicesProvider.notifier).uploadImages(
              targetServiceId,
              paths,
            );
      }

      if (mounted) {
        AppFeedback.showSuccess(context, 'Serviço salvo com sucesso!');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.showError(context, 'Erro ao salvar serviço. Tente novamente.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canCreateServices = ref.watch(canCreateServicesProvider);
    if (!canCreateServices && !_isEditing) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          title: const Text('Novo Serviço'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outlined,
                  size: 64,
                  color: AppColors.textSecondary.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 16),
                Text(
                  'Recurso indisponível',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Cadastro de serviços está disponível nos planos Basic e Pro. Atualize seu plano para desbloquear.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
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
            content: const Text('Você tem alterações não salvas. Deseja sair sem salvar?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Continuar editando'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
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
        elevation: 0,
        title: Row(
          children: [
            Icon(
              _isEditing ? Icons.edit_outlined : Icons.handyman_outlined,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              _isEditing ? 'Editar Serviço' : 'Novo Serviço',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: const [],
        bottom: _isLoading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(4),
                child: LinearProgressIndicator(
                  color: AppColors.primary,
                  minHeight: 4,
                ),
              )
            : null,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          children: [
            // Photo Picker
            _SectionCard(
              icon: Icons.camera_alt_outlined,
              title: 'Fotos do Serviço',
              subtitle: 'Adicione até 5 fotos do seu trabalho',
              animationIndex: 0,
              child: PhotoPickerGrid(
                initialUrls: _existingImageUrls,
                newFiles: _newImageFiles,
                onFilesChanged: (files) => setState(() {
                  _newImageFiles = files;
                  _hasUnsavedChanges = true;
                }),
                onUrlsChanged: (urls) => setState(() {
                  _existingImageUrls = urls;
                  _hasUnsavedChanges = true;
                }),
              ),
            ),
            const SizedBox(height: 16),

            _SectionCard(
              icon: Icons.info_outline,
              title: 'Informações Básicas',
              subtitle: 'Nome, descrição e categoria do serviço',
              animationIndex: 1,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nome do serviço *',
                      hintText: 'Ex: Desenvolvimento de Sites',
                      prefixIcon: Icon(Icons.handyman_outlined),
                    ),
                    onChanged: (_) => setState(() => _hasUnsavedChanges = true),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Informe o nome do serviço';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _shortDescriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Descrição curta',
                      hintText: 'Breve resumo do serviço',
                      prefixIcon: Icon(Icons.short_text),
                    ),
                    maxLines: 2,
                    maxLength: 150,
                    onChanged: (_) => setState(() => _hasUnsavedChanges = true),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Descrição completa *',
                      hintText: 'Descreva seu serviço detalhadamente...',
                      prefixIcon: Icon(Icons.description_outlined),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 6,
                    onChanged: (_) => setState(() => _hasUnsavedChanges = true),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Informe a descrição';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildCategoryDropdown(),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _SectionCard(
              icon: Icons.attach_money,
              title: 'Precificação',
              subtitle: 'Defina como você cobra pelo serviço',
              animationIndex: 2,
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _pricingType,
                    decoration: const InputDecoration(
                      labelText: 'Tipo de precificação *',
                      prefixIcon: Icon(Icons.price_change_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'hourly', child: Text('Por hora')),
                      DropdownMenuItem(value: 'project', child: Text('Por projeto')),
                      DropdownMenuItem(value: 'monthly', child: Text('Mensal')),
                      DropdownMenuItem(value: 'fixed', child: Text('Preço fixo')),
                      DropdownMenuItem(value: 'on_demand', child: Text('Sob demanda')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _pricingType = value;
                          _hasUnsavedChanges = true;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _basePriceController,
                    decoration: InputDecoration(
                      labelText: 'Preço base *',
                      prefixText: 'R\$ ',
                      prefixIcon: const Icon(Icons.attach_money),
                      hintText: _pricingType == 'hourly' ? 'Valor por hora' : 'Valor inicial',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() => _hasUnsavedChanges = true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Informe o preço';
                      }
                      final price = double.tryParse(value.replaceAll(',', '.'));
                      if (price == null || price <= 0) {
                        return 'Preço inválido';
                      }
                      return null;
                    },
                  ),
                  if (_pricingType == 'project') ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _minPriceController,
                            decoration: const InputDecoration(
                              labelText: 'Preço mínimo',
                              prefixText: 'R\$ ',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setState(() => _hasUnsavedChanges = true),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _maxPriceController,
                            decoration: const InputDecoration(
                              labelText: 'Preço máximo',
                              prefixText: 'R\$ ',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (_) => setState(() => _hasUnsavedChanges = true),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            _SectionCard(
              icon: Icons.place_outlined,
              title: 'Tipo de Atendimento',
              subtitle: 'Como você atende seus clientes',
              animationIndex: 3,
              child: Column(
                children: [
                  CheckboxListTile(
                    value: _isRemote,
                    onChanged: (value) => setState(() {
                      _isRemote = value ?? false;
                      _hasUnsavedChanges = true;
                    }),
                    title: const Text('Atendimento remoto'),
                    subtitle: const Text('Trabalho pode ser feito à distância'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.primary,
                  ),
                  CheckboxListTile(
                    value: _isOnSite,
                    onChanged: (value) => setState(() {
                      _isOnSite = value ?? false;
                      _hasUnsavedChanges = true;
                    }),
                    title: const Text('Atendimento presencial'),
                    subtitle: const Text('Atende no local do cliente'),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.primary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _SectionCard(
              icon: Icons.playlist_add_check_outlined,
              title: 'Informações Adicionais',
              subtitle: 'Experiência, requisitos e certificações',
              animationIndex: 4,
              child: Column(
                children: [
                  TextFormField(
                    controller: _experienceController,
                    decoration: const InputDecoration(
                      labelText: 'Experiência',
                      hintText: 'Ex: 5 anos de experiência',
                      prefixIcon: Icon(Icons.workspace_premium_outlined),
                    ),
                    onChanged: (_) => setState(() => _hasUnsavedChanges = true),
                  ),
                  const SizedBox(height: 20),
                  _ListField(
                    title: 'Requisitos',
                    items: _requirements,
                    onAdd: () => _showAddItemDialog(
                      'Adicionar Requisito',
                      (item) => setState(() {
                        _requirements.add(item);
                        _hasUnsavedChanges = true;
                      }),
                    ),
                    onRemove: (index) => setState(() {
                      _requirements.removeAt(index);
                      _hasUnsavedChanges = true;
                    }),
                  ),
                  const SizedBox(height: 20),
                  _ListField(
                    title: 'O que está incluso',
                    items: _includes,
                    onAdd: () => _showAddItemDialog(
                      'Adicionar Item Incluso',
                      (item) => setState(() {
                        _includes.add(item);
                        _hasUnsavedChanges = true;
                      }),
                    ),
                    onRemove: (index) => setState(() {
                      _includes.removeAt(index);
                      _hasUnsavedChanges = true;
                    }),
                  ),
                  const SizedBox(height: 20),
                  _ListField(
                    title: 'Certificações',
                    items: _certifications,
                    onAdd: () => _showAddItemDialog(
                      'Adicionar Certificação',
                      (item) => setState(() {
                        _certifications.add(item);
                        _hasUnsavedChanges = true;
                      }),
                    ),
                    onRemove: (index) => setState(() {
                      _certifications.removeAt(index);
                      _hasUnsavedChanges = true;
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Agendamento section
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.event_available_outlined,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Agendamento',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ).animate(delay: const Duration(milliseconds: 400))
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.04, end: 0, duration: 400.ms, curve: Curves.easeOutCubic),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  // Single clear toggle for online scheduling
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _scheduleEnabled
                              ? AppColors.primary.withAlpha(25)
                              : Colors.grey.withAlpha(25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _scheduleEnabled
                              ? Icons.calendar_month
                              : Icons.calendar_month_outlined,
                          color: _scheduleEnabled
                              ? AppColors.primary
                              : AppColors.textHint,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Agenda online',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _scheduleEnabled
                                  ? 'Clientes podem agendar horários diretamente pelo app. Os agendamentos aparecerão na sua aba Agenda.'
                                  : 'Desativado — clientes interessados entrarão em contato por chat ou WhatsApp para combinar horários.',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Switch(
                        value: _scheduleEnabled,
                        onChanged: (value) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _scheduleEnabled = value;
                            // When enabling online scheduling, also enable instant booking
                            if (value) {
                              _instantBooking = true;
                            }
                            _hasUnsavedChanges = true;
                          });
                        },
                        activeColor: AppColors.primary,
                      ),
                    ],
                  ),

                  if (_scheduleEnabled) ...[
                    const Divider(height: 32),

                    // Slot duration
                    DropdownButtonFormField<int>(
                      value: _slotDurationMinutes,
                      decoration: const InputDecoration(
                        labelText: 'Duração do atendimento',
                        prefixIcon: Icon(Icons.timer_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(value: 15, child: Text('15 minutos')),
                        DropdownMenuItem(value: 30, child: Text('30 minutos')),
                        DropdownMenuItem(value: 45, child: Text('45 minutos')),
                        DropdownMenuItem(value: 60, child: Text('1 hora')),
                        DropdownMenuItem(value: 90, child: Text('1h30')),
                        DropdownMenuItem(value: 120, child: Text('2 horas')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _slotDurationMinutes = value;
                            _hasUnsavedChanges = true;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Break between
                    DropdownButtonFormField<int>(
                      value: _breakBetweenMinutes,
                      decoration: const InputDecoration(
                        labelText: 'Intervalo entre atendimentos',
                        prefixIcon: Icon(Icons.coffee_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('Sem intervalo')),
                        DropdownMenuItem(value: 5, child: Text('5 minutos')),
                        DropdownMenuItem(value: 10, child: Text('10 minutos')),
                        DropdownMenuItem(value: 15, child: Text('15 minutos')),
                        DropdownMenuItem(value: 30, child: Text('30 minutos')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _breakBetweenMinutes = value;
                            _hasUnsavedChanges = true;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    // Days of the week
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Dias de atendimento',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._buildDayRows(),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Accepts quotes toggle (simple, separate)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _acceptsQuote
                          ? AppColors.info.withAlpha(25)
                          : Colors.grey.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.request_quote_outlined,
                      color: _acceptsQuote
                          ? AppColors.info
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
                          'Aceitar pedidos de orçamento',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Clientes podem solicitar um orçamento antes de contratar',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _acceptsQuote,
                    onChanged: (value) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _acceptsQuote = value;
                        _hasUnsavedChanges = true;
                      });
                    },
                    activeColor: AppColors.info,
                  ),
                ],
              ),
            ),

            // Publish toggle
            const SizedBox(height: 16),
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
                              ? 'Serviço visível para clientes'
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
                    onChanged: (value) {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _isActive = value;
                          _hasUnsavedChanges = true;
                        });
                    },
                    activeColor: AppColors.secondary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Submit button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveService,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 4,
                  shadowColor: AppColors.primary.withAlpha(80),
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
                    : Icon(_isEditing ? Icons.save_outlined : Icons.rocket_launch_outlined, size: 20),
                label: Text(
                  _isEditing
                      ? 'Salvar alterações'
                      : 'Publicar serviço',
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

  List<Widget> _buildDayRows() {
    const dayLabels = {
      'monday': 'Segunda',
      'tuesday': 'Terça',
      'wednesday': 'Quarta',
      'thursday': 'Quinta',
      'friday': 'Sexta',
      'saturday': 'Sábado',
      'sunday': 'Domingo',
    };

    return dayLabels.entries.map((entry) {
      final day = entry.key;
      final label = entry.value;
      final isActive = _scheduleDays[day] ?? false;

      return Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: isActive,
                  onChanged: (value) => setState(() {
                    _scheduleDays[day] = value ?? false;
                    if (value == true) {
                      _scheduleStart.putIfAbsent(day, () => '08:00');
                      _scheduleEnd.putIfAbsent(day, () => '18:00');
                    }
                    _hasUnsavedChanges = true;
                  }),
                  activeColor: AppColors.primary,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 72,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: isActive ? AppColors.textPrimary : AppColors.textHint,
                    fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ),
              if (isActive) ...[
                const SizedBox(width: 8),
                _TimePickerChip(
                  label: _scheduleStart[day] ?? '08:00',
                  onTap: () => _pickTime(day, isStart: true),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text('—', style: TextStyle(color: AppColors.textHint)),
                ),
                _TimePickerChip(
                  label: _scheduleEnd[day] ?? '18:00',
                  onTap: () => _pickTime(day, isStart: false),
                ),
              ],
            ],
          ),
          if (day != 'sunday') const SizedBox(height: 4),
        ],
      );
    }).toList();
  }

  Future<void> _pickTime(String day, {required bool isStart}) async {
    final current = isStart
        ? (_scheduleStart[day] ?? '08:00')
        : (_scheduleEnd[day] ?? '18:00');
    final parts = current.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 8,
      minute: int.tryParse(parts[1]) ?? 0,
    );

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final timeStr =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        if (isStart) {
          _scheduleStart[day] = timeStr;
        } else {
          _scheduleEnd[day] = timeStr;
        }
        _hasUnsavedChanges = true;
      });
    }
  }

  void _showAddItemDialog(String title, Function(String) onAdd) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Digite o item',
          ),
          autofocus: true,
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              onAdd(value.trim());
              Navigator.pop(context);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                onAdd(controller.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final bool hasError;
  final int animationIndex;

  const _SectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
    this.hasError = false,
    this.animationIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = hasError ? AppColors.error : AppColors.primary;

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
    } else {
      card = card
          .animate(delay: Duration(milliseconds: 80 * animationIndex))
          .fadeIn(duration: 400.ms)
          .slideY(begin: 0.04, end: 0, duration: 400.ms, curve: Curves.easeOutCubic);
    }

    return card;
  }
}

class _ListField extends StatelessWidget {
  final String title;
  final List<String> items;
  final VoidCallback onAdd;
  final Function(int) onRemove;

  const _ListField({
    required this.title,
    required this.items,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Adicionar'),
            ),
          ],
        ),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: Text(
                'Nenhum item adicionado',
                style: TextStyle(
                  color: AppColors.textHint,
                  fontSize: 14,
                ),
              ),
            ),
          )
        else
          ...items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Card(
              child: ListTile(
                title: Text(item),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => onRemove(index),
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _TimePickerChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TimePickerChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withAlpha(15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primary.withAlpha(40)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}
