import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/service_model.dart';
import '../../../domain/repositories/service_repository.dart';
import '../../providers/my_services_provider.dart';
import '../../widgets/seller/photo_picker_grid.dart';

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
  bool _isActive = true;
  bool _isAvailable = true;
  bool _isRemote = false;
  bool _isOnSite = true;
  bool _acceptsQuote = true;
  bool _instantBooking = false;

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

  Future<void> _saveService() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate at least one photo
    if (_existingImageUrls.isEmpty && _newImageFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Adicione pelo menos 1 foto do serviço'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Validate service delivery method
    if (!_isRemote && !_isOnSite) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione pelo menos um tipo de atendimento'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

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
            );

      if (_isEditing) {
        await ref.read(myServicesProvider.notifier).updateService(
              widget.serviceId!,
              request as UpdateServiceRequest,
            );
      } else {
        await ref.read(myServicesProvider.notifier).createService(
              request as CreateServiceRequest,
            );
      }

      // Upload new images if any
      if (_newImageFiles.isNotEmpty && widget.serviceId != null) {
        final paths = _newImageFiles.map((f) => f.path).toList();
        await ref.read(myServicesProvider.notifier).uploadImages(
              widget.serviceId!,
              paths,
            );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Serviço atualizado!' : 'Serviço criado!'),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          _isEditing ? 'Editar Serviço' : 'Novo Serviço',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveService,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Salvar',
                    style: TextStyle(
                      color: AppColors.sellerAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Photo Picker
            PhotoPickerGrid(
              initialUrls: _existingImageUrls,
              newFiles: _newImageFiles,
              onFilesChanged: (files) => setState(() => _newImageFiles = files),
              onUrlsChanged: (urls) => setState(() => _existingImageUrls = urls),
            ),
            const SizedBox(height: 24),

            // Basic Information Section
            _SectionHeader(title: 'Informações Básicas'),
            const SizedBox(height: 16),

            // Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nome do serviço *',
                hintText: 'Ex: Desenvolvimento de Sites',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Informe o nome do serviço';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Short Description
            TextFormField(
              controller: _shortDescriptionController,
              decoration: const InputDecoration(
                labelText: 'Descrição curta',
                hintText: 'Breve resumo do serviço',
              ),
              maxLines: 2,
              maxLength: 150,
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descrição completa *',
                hintText: 'Descreva seu serviço detalhadamente...',
                alignLabelWithHint: true,
              ),
              maxLines: 6,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Informe a descrição';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Category
            DropdownButtonFormField<String>(
              value: _selectedCategory.isEmpty ? null : _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Categoria *',
              ),
              items: const [
                DropdownMenuItem(value: 'reformas', child: Text('Reformas e Reparos')),
                DropdownMenuItem(value: 'beleza', child: Text('Beleza e Estética')),
                DropdownMenuItem(value: 'saude', child: Text('Saúde e Bem-estar')),
                DropdownMenuItem(value: 'educacao', child: Text('Educação e Aulas')),
                DropdownMenuItem(value: 'tecnologia', child: Text('Tecnologia e TI')),
                DropdownMenuItem(value: 'consultoria', child: Text('Consultoria e Negócios')),
                DropdownMenuItem(value: 'eventos', child: Text('Eventos e Festas')),
                DropdownMenuItem(value: 'limpeza', child: Text('Limpeza e Conservação')),
                DropdownMenuItem(value: 'transporte', child: Text('Transporte e Logística')),
                DropdownMenuItem(value: 'pet', child: Text('Pet Services')),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Selecione uma categoria';
                }
                return null;
              },
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedCategory = value);
                }
              },
            ),
            const SizedBox(height: 24),

            // Pricing Section
            _SectionHeader(title: 'Precificação'),
            const SizedBox(height: 16),

            // Pricing Type
            DropdownButtonFormField<String>(
              value: _pricingType,
              decoration: const InputDecoration(
                labelText: 'Tipo de precificação *',
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
                  setState(() => _pricingType = value);
                }
              },
            ),
            const SizedBox(height: 16),

            // Base Price
            TextFormField(
              controller: _basePriceController,
              decoration: InputDecoration(
                labelText: 'Preço base *',
                prefixText: 'R\$ ',
                hintText: _pricingType == 'hourly' ? 'Valor por hora' : 'Valor inicial',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
            const SizedBox(height: 16),

            // Price range (for project-based)
            if (_pricingType == 'project') ...[
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
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            const SizedBox(height: 24),

            // Service Delivery Section
            _SectionHeader(title: 'Tipo de Atendimento'),
            const SizedBox(height: 16),

            CheckboxListTile(
              value: _isRemote,
              onChanged: (value) => setState(() => _isRemote = value ?? false),
              title: const Text('Atendimento remoto'),
              subtitle: const Text('Trabalho pode ser feito à distância'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            CheckboxListTile(
              value: _isOnSite,
              onChanged: (value) => setState(() => _isOnSite = value ?? false),
              title: const Text('Atendimento presencial'),
              subtitle: const Text('Atende no local do cliente'),
              controlAffinity: ListTileControlAffinity.leading,
            ),

            const SizedBox(height: 24),

            // Additional Info Section
            _SectionHeader(title: 'Informações Adicionais'),
            const SizedBox(height: 16),

            // Experience
            TextFormField(
              controller: _experienceController,
              decoration: const InputDecoration(
                labelText: 'Experiência',
                hintText: 'Ex: 5 anos de experiência',
              ),
            ),
            const SizedBox(height: 16),

            // Lists Section (Requirements, Includes, Certifications)
            _ListField(
              title: 'Requisitos',
              items: _requirements,
              onAdd: () => _showAddItemDialog(
                'Adicionar Requisito',
                (item) => setState(() => _requirements.add(item)),
              ),
              onRemove: (index) => setState(() => _requirements.removeAt(index)),
            ),
            const SizedBox(height: 16),

            _ListField(
              title: 'O que está incluso',
              items: _includes,
              onAdd: () => _showAddItemDialog(
                'Adicionar Item Incluso',
                (item) => setState(() => _includes.add(item)),
              ),
              onRemove: (index) => setState(() => _includes.removeAt(index)),
            ),
            const SizedBox(height: 16),

            _ListField(
              title: 'Certificações',
              items: _certifications,
              onAdd: () => _showAddItemDialog(
                'Adicionar Certificação',
                (item) => setState(() => _certifications.add(item)),
              ),
              onRemove: (index) => setState(() => _certifications.removeAt(index)),
            ),

            const SizedBox(height: 24),

            // Booking Options
            _SectionHeader(title: 'Opções de Agendamento'),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Aceita orçamentos',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Clientes podem solicitar orçamento',
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
                        onChanged: (value) => setState(() => _acceptsQuote = value),
                        activeColor: AppColors.sellerAccent,
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Agendamento instantâneo',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Clientes podem agendar diretamente',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textHint,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _instantBooking,
                        onChanged: (value) => setState(() => _instantBooking = value),
                        activeColor: AppColors.sellerAccent,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Active and Available toggles
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ativo no marketplace',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Serviço visível para clientes',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isActive,
                    onChanged: (value) => setState(() => _isActive = value),
                    activeColor: AppColors.secondary,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
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

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
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
