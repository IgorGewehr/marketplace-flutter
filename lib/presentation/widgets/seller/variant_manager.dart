import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/product_model.dart';

/// Widget for managing product variants (size, color, etc.)
class VariantManager extends StatefulWidget {
  final List<ProductVariant> initialVariants;
  final Function(List<ProductVariant>) onVariantsChanged;

  const VariantManager({
    super.key,
    required this.initialVariants,
    required this.onVariantsChanged,
  });

  @override
  State<VariantManager> createState() => _VariantManagerState();
}

class _VariantManagerState extends State<VariantManager> {
  List<ProductVariant> _variants = [];

  @override
  void initState() {
    super.initState();
    _variants = List.from(widget.initialVariants);
  }

  void _addVariant() {
    showDialog(
      context: context,
      builder: (context) => _VariantDialog(
        onSave: (variant) {
          setState(() {
            _variants.add(variant);
            widget.onVariantsChanged(_variants);
          });
        },
      ),
    );
  }

  void _editVariant(int index) {
    showDialog(
      context: context,
      builder: (context) => _VariantDialog(
        variant: _variants[index],
        onSave: (variant) {
          setState(() {
            _variants[index] = variant;
            widget.onVariantsChanged(_variants);
          });
        },
      ),
    );
  }

  void _deleteVariant(int index) {
    setState(() {
      _variants.removeAt(index);
      widget.onVariantsChanged(_variants);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _addVariant,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Adicionar variante'),
              ),
            ),
          ],
        ),
        if (_variants.isNotEmpty) ...[
          const SizedBox(height: 12),
          ..._variants.asMap().entries.map((entry) {
            final index = entry.key;
            final variant = entry.value;
            return Padding(
              padding: EdgeInsets.only(top: index > 0 ? 8 : 0),
              child: _VariantCard(
                variant: variant,
                onEdit: () => _editVariant(index),
                onDelete: () => _deleteVariant(index),
              ),
            );
          }),
        ] else ...[
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Nenhuma variante adicionada',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textHint,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _VariantCard extends StatelessWidget {
  final ProductVariant variant;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _VariantCard({
    required this.variant,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.sellerAccent.withAlpha((255 * 0.05).round()),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.sellerAccent.withAlpha((255 * 0.2).round()),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  variant.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    if (variant.price != null)
                      Text(
                        'R\$ ${variant.price!.toStringAsFixed(2)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textHint,
                        ),
                      ),
                    if (variant.quantity != null)
                      Text(
                        'Estoque: ${variant.quantity}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textHint,
                        ),
                      ),
                    if (variant.sku != null)
                      Text(
                        'SKU: ${variant.sku}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textHint,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: onEdit,
            color: AppColors.sellerAccent,
            tooltip: 'Editar variante',
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            onPressed: onDelete,
            color: AppColors.error,
            tooltip: 'Excluir variante',
          ),
        ],
      ),
    );
  }
}

class _VariantDialog extends StatefulWidget {
  final ProductVariant? variant;
  final Function(ProductVariant) onSave;

  const _VariantDialog({
    this.variant,
    required this.onSave,
  });

  @override
  State<_VariantDialog> createState() => _VariantDialogState();
}

class _VariantDialogState extends State<_VariantDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();

  bool get _isEditing => widget.variant != null;

  @override
  void initState() {
    super.initState();
    if (widget.variant != null) {
      _nameController.text = widget.variant!.name;
      _skuController.text = widget.variant!.sku ?? '';
      _priceController.text = widget.variant!.price?.toStringAsFixed(2) ?? '';
      _quantityController.text = widget.variant!.quantity?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final variant = ProductVariant(
      id: widget.variant?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      sku: _skuController.text.trim().isEmpty ? null : _skuController.text.trim(),
      price: _priceController.text.isEmpty
          ? null
          : double.parse(_priceController.text.replaceAll(',', '.')),
      quantity: _quantityController.text.isEmpty
          ? null
          : int.parse(_quantityController.text),
    );

    widget.onSave(variant);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Editar Variante' : 'Nova Variante'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Name/Description
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome da variante *',
                  hintText: 'Ex: P Azul, M Vermelho, 42',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Informe o nome';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // SKU (optional)
              TextFormField(
                controller: _skuController,
                decoration: const InputDecoration(
                  labelText: 'SKU (opcional)',
                  hintText: 'Ex: CAM-P-AZ',
                  prefixIcon: Icon(Icons.qr_code),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 16),

              // Price (optional - if different from base)
              TextFormField(
                controller: _priceController,
                decoration: const InputDecoration(
                  labelText: 'Preço diferente (opcional)',
                  hintText: 'Deixe vazio para usar preço base',
                  prefixText: 'R\$ ',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),

              // Quantity
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(
                  labelText: 'Quantidade em estoque',
                  hintText: 'Quantidade desta variante',
                  suffixText: 'unidades',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(_isEditing ? 'Salvar' : 'Adicionar'),
        ),
      ],
    );
  }
}
