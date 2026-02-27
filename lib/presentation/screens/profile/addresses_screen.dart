import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/address_model.dart';
import '../../providers/address_provider.dart';
import '../../widgets/shared/app_feedback.dart';
import '../../widgets/shared/illustrated_empty_state.dart';
import '../../widgets/shared/shimmer_loading.dart';

/// Addresses screen backed by API
class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final addressesAsync = ref.watch(addressProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Meus Endereços'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: addressesAsync.when(
        loading: () => const ShimmerLoading(itemCount: 3, isGrid: false, height: 100),
        error: (_, __) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Erro ao carregar endereços'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.invalidate(addressProvider),
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
        data: (addresses) {
          if (addresses.isEmpty) {
            return EmptyAddressesState(
              onAdd: () => _showAddressForm(context, ref),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(addressProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: addresses.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final address = addresses[index];
                return _AddressTile(
                  address: address,
                  onTap: () => _showAddressForm(context, ref, address: address),
                  onDelete: () => _deleteAddress(context, ref, address),
                  onSetDefault: address.isDefault
                      ? null
                      : () => _setAsDefault(context, ref, address),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddressForm(context, ref),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showAddressForm(BuildContext context, WidgetRef ref, {AddressModel? address}) {
    // Capture the parent scaffold context before opening the sheet so that
    // snackbars are shown on the parent scaffold, not the ephemeral sheet context.
    final parentContext = context;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddressFormSheet(
        address: address,
        onSave: (newAddress) async {
          try {
            if (address != null) {
              await ref.read(addressProvider.notifier).updateAddress(newAddress);
            } else {
              await ref.read(addressProvider.notifier).createAddress(newAddress);
            }
            if (parentContext.mounted) {
              AppFeedback.showSuccess(parentContext, 'Endereço salvo!');
            }
          } catch (e) {
            if (parentContext.mounted) {
              AppFeedback.showError(parentContext, 'Erro ao salvar endereço. Tente novamente.');
            }
          }
        },
      ),
    );
  }

  void _deleteAddress(BuildContext context, WidgetRef ref, AddressModel address) async {
    final confirmed = await AppFeedback.showConfirmation(
      context,
      title: 'Excluir endereço',
      message: 'Tem certeza que deseja excluir este endereço?',
      isDangerous: true,
    );

    if (confirmed) {
      try {
        await ref.read(addressProvider.notifier).deleteAddress(address.id!);
        if (context.mounted) {
          AppFeedback.showSuccess(context, 'Endereço excluído');
        }
      } catch (e) {
        if (context.mounted) {
          AppFeedback.showError(context, 'Erro ao excluir endereço. Tente novamente.');
        }
      }
    }
  }

  void _setAsDefault(BuildContext context, WidgetRef ref, AddressModel address) async {
    try {
      await ref.read(addressProvider.notifier).setDefault(address.id!);
      if (context.mounted) {
        AppFeedback.showSuccess(context, 'Endereço padrão atualizado');
      }
    } catch (e) {
      if (context.mounted) {
        AppFeedback.showError(context, 'Erro ao atualizar endereço padrão. Tente novamente.');
      }
    }
  }
}

class _AddressTile extends StatelessWidget {
  final AddressModel address;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onSetDefault;

  const _AddressTile({
    required this.address,
    this.onTap,
    this.onDelete,
    this.onSetDefault,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: address.isDefault
            ? Border.all(color: AppColors.primary, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      address.label?.toLowerCase() == 'trabalho'
                          ? Icons.business_rounded
                          : Icons.home_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      address.label ?? 'Endereço',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (address.isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Padrão',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: AppColors.textHint),
                      onSelected: (value) {
                        if (value == 'default') onSetDefault?.call();
                        if (value == 'delete') onDelete?.call();
                      },
                      itemBuilder: (context) => [
                        if (!address.isDefault)
                          const PopupMenuItem(
                            value: 'default',
                            child: Text('Definir como padrão'),
                          ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Excluir', style: TextStyle(color: AppColors.error)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${address.street}, ${address.number}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (address.complement != null && address.complement!.isNotEmpty)
                  Text(
                    address.complement!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  '${address.neighborhood} - ${address.city}/${address.state}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  'CEP: ${address.zipCode}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddressFormSheet extends StatefulWidget {
  final AddressModel? address;
  final Future<void> Function(AddressModel) onSave;

  const _AddressFormSheet({this.address, required this.onSave});

  @override
  State<_AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends State<_AddressFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _labelController;
  late TextEditingController _zipController;
  late TextEditingController _streetController;
  late TextEditingController _numberController;
  late TextEditingController _complementController;
  late TextEditingController _neighborhoodController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  bool _isLoading = false;
  bool _isLoadingCep = false;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.address?.label);
    _zipController = TextEditingController(text: widget.address?.zipCode);
    _streetController = TextEditingController(text: widget.address?.street);
    _numberController = TextEditingController(text: widget.address?.number);
    _complementController = TextEditingController(text: widget.address?.complement);
    _neighborhoodController = TextEditingController(text: widget.address?.neighborhood);
    _cityController = TextEditingController(text: widget.address?.city);
    _stateController = TextEditingController(text: widget.address?.state);
    _zipController.addListener(_onCepChanged);
  }

  // Gap #10: Auto-fill address via ViaCEP
  void _onCepChanged() {
    final cep = _zipController.text.replaceAll(RegExp(r'\D'), '');
    if (cep.length == 8) {
      _lookupCep(cep);
    }
  }

  Future<void> _lookupCep(String cep) async {
    setState(() => _isLoadingCep = true);
    try {
      final response = await Dio().get('https://viacep.com.br/ws/$cep/json/');
      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        if (data['erro'] != true && mounted) {
          setState(() {
            _streetController.text = data['logradouro'] ?? '';
            _neighborhoodController.text = data['bairro'] ?? '';
            _cityController.text = data['localidade'] ?? '';
            _stateController.text = data['uf'] ?? '';
          });
        }
      }
    } catch (_) {
      // Silent fail — user can fill manually
    } finally {
      if (mounted) setState(() => _isLoadingCep = false);
    }
  }

  @override
  void dispose() {
    _zipController.removeListener(_onCepChanged);
    _labelController.dispose();
    _zipController.dispose();
    _streetController.dispose();
    _numberController.dispose();
    _complementController.dispose();
    _neighborhoodController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final newAddress = AddressModel(
      id: widget.address?.id,
      label: _labelController.text,
      street: _streetController.text,
      number: _numberController.text,
      complement: _complementController.text.isNotEmpty ? _complementController.text : null,
      neighborhood: _neighborhoodController.text,
      city: _cityController.text,
      state: _stateController.text,
      zipCode: _zipController.text,
      isDefault: widget.address?.isDefault ?? false,
    );

    await widget.onSave(newAddress);
    if (mounted) {
      setState(() => _isLoading = false);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Gap #10: Respect keyboard viewInsets so button isn't hidden
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  widget.address != null ? 'Editar Endereço' : 'Novo Endereço',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _labelController,
                      decoration: const InputDecoration(
                        labelText: 'Apelido (ex: Casa, Trabalho)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _zipController,
                      decoration: InputDecoration(
                        labelText: 'CEP',
                        border: const OutlineInputBorder(),
                        suffixIcon: _isLoadingCep
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : null,
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(8),
                      ],
                      validator: (v) => v?.isEmpty == true ? 'Informe o CEP' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _streetController,
                      decoration: const InputDecoration(
                        labelText: 'Rua',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v?.isEmpty == true ? 'Informe a rua' : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _numberController,
                            decoration: const InputDecoration(
                              labelText: 'Número',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => v?.isEmpty == true ? 'Número' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _complementController,
                            decoration: const InputDecoration(
                              labelText: 'Complemento',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _neighborhoodController,
                      decoration: const InputDecoration(
                        labelText: 'Bairro',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v?.isEmpty == true ? 'Informe o bairro' : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _cityController,
                            decoration: const InputDecoration(
                              labelText: 'Cidade',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => v?.isEmpty == true ? 'Cidade' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: TextFormField(
                            controller: _stateController,
                            decoration: const InputDecoration(
                              labelText: 'UF',
                              border: OutlineInputBorder(),
                            ),
                            validator: (v) => v?.isEmpty == true ? 'UF' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isLoading ? null : _handleSave,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Salvar Endereço',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }
}
