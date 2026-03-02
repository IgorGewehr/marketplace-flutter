import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../providers/products_provider.dart';

/// Search filters bottom sheet
class SearchFiltersSheet extends ConsumerStatefulWidget {
  const SearchFiltersSheet({super.key});

  @override
  ConsumerState<SearchFiltersSheet> createState() => _SearchFiltersSheetState();
}

class _SearchFiltersSheetState extends ConsumerState<SearchFiltersSheet> {
  late String _selectedCategory;
  double? _minPrice;
  double? _maxPrice;
  String _sortBy = 'recent';
  final _tagController = TextEditingController();
  final _minController = TextEditingController();
  final _maxController = TextEditingController();
  List<String> _tags = [];

  static const _maxPresets = [
    (label: 'R\$ 500', value: 500.0),
    (label: 'R\$ 1k', value: 1000.0),
    (label: 'R\$ 5k', value: 5000.0),
    (label: 'R\$ 50k', value: 50000.0),
    (label: 'R\$ 200k', value: 200000.0),
    (label: 'R\$ 500k', value: 500000.0),
    (label: 'R\$ 1M', value: 1000000.0),
    (label: 'R\$ 5M', value: 5000000.0),
  ];

  @override
  void initState() {
    super.initState();
    final filters = ref.read(productFiltersProvider);
    final categoryId = filters.category;
    if (categoryId != null) {
      final idToName = ref.read(categoryIdToNameProvider).valueOrNull ?? {};
      _selectedCategory = idToName[categoryId] ?? 'Todos';
    } else {
      _selectedCategory = 'Todos';
    }
    _minPrice = filters.minPrice;
    _maxPrice = filters.maxPrice;
    _minController.text = filters.minPrice != null ? filters.minPrice!.toInt().toString() : '';
    _maxController.text = filters.maxPrice != null ? filters.maxPrice!.toInt().toString() : '';
    _sortBy = filters.sortBy;
    _tags = List.from(filters.tags ?? []);
  }

  @override
  void dispose() {
    _tagController.dispose();
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    final currentFilters = ref.read(productFiltersProvider);
    final nameToId = ref.read(categoryNameToIdProvider).valueOrNull ?? {};
    final categoryId = _selectedCategory == 'Todos'
        ? null
        : nameToId[_selectedCategory] ?? _selectedCategory;

    ref.read(productFiltersProvider.notifier).state = ProductFilters(
      query: currentFilters.query,
      category: categoryId,
      minPrice: _minPrice,
      maxPrice: _maxPrice,
      sortBy: _sortBy,
      page: 1,
      limit: currentFilters.limit,
      tags: _tags.isNotEmpty ? _tags : null,
      followedOnly: currentFilters.followedOnly,
    );
    Navigator.pop(context);
  }

  void _clearFilters() {
    setState(() {
      _selectedCategory = 'Todos';
      _minPrice = null;
      _maxPrice = null;
      _minController.clear();
      _maxController.clear();
      _sortBy = 'recent';
      _tags = [];
      _tagController.clear();
    });
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _tagController.clear();
      });
    }
  }

  void _setMaxPreset(double value) {
    setState(() {
      _maxPrice = value;
      _maxController.text = value.toInt().toString();
    });
  }

  void _onMinChanged(String val) {
    final digits = val.replaceAll(RegExp(r'[^\d]'), '');
    _minController.value = _minController.value.copyWith(text: digits);
    setState(() {
      _minPrice = digits.isEmpty ? null : double.tryParse(digits);
    });
  }

  void _onMaxChanged(String val) {
    final digits = val.replaceAll(RegExp(r'[^\d]'), '');
    _maxController.value = _maxController.value.copyWith(text: digits);
    setState(() {
      _maxPrice = digits.isEmpty ? null : double.tryParse(digits);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.outline.withAlpha(50),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filtros',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: _clearFilters,
                  child: const Text('Limpar tudo'),
                ),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 0.5),

          // Scrollable content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Category ───────────────────────────────────────────
                  Text(
                    'Categoria',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  categoriesAsync.when(
                    loading: () => const CircularProgressIndicator(),
                    error: (e, _) => const Text('Erro ao carregar categorias'),
                    data: (categories) => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categories.map((category) {
                        final isSelected = category == _selectedCategory;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedCategory = category);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : theme.colorScheme.outline.withAlpha(60),
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Text(
                              category,
                              style: TextStyle(
                                color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                                fontWeight:
                                    isSelected ? FontWeight.w600 : FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ─── Price range ─────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Faixa de preço',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_minPrice != null || _maxPrice != null)
                        TextButton(
                          onPressed: () => setState(() {
                            _minPrice = null;
                            _maxPrice = null;
                            _minController.clear();
                            _maxController.clear();
                          }),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                          ),
                          child: const Text('Limpar'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Quick max presets
                  SizedBox(
                    height: 34,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _maxPresets.length,
                      separatorBuilder: (context, _) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final preset = _maxPresets[i];
                        final isActive = _maxPrice == preset.value;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            if (isActive) {
                              setState(() {
                                _maxPrice = null;
                                _maxController.clear();
                              });
                            } else {
                              _setMaxPreset(preset.value);
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: isActive ? AppColors.primary : Colors.transparent,
                              borderRadius: BorderRadius.circular(17),
                              border: Border.all(
                                color: isActive
                                    ? AppColors.primary
                                    : theme.colorScheme.outline.withAlpha(60),
                              ),
                            ),
                            child: Text(
                              preset.label,
                              style: TextStyle(
                                color: isActive ? Colors.white : theme.colorScheme.onSurface,
                                fontSize: 12,
                                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Min / Max text fields
                  Row(
                    children: [
                      Expanded(
                        child: _PriceTextField(
                          controller: _minController,
                          label: 'Mínimo',
                          onChanged: _onMinChanged,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          '–',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _PriceTextField(
                          controller: _maxController,
                          label: 'Máximo',
                          onChanged: _onMaxChanged,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // ─── Tags ────────────────────────────────────────────────
                  Text(
                    'Tags',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _tagController,
                          decoration: InputDecoration(
                            hintText: 'Filtrar por tag',
                            isDense: true,
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: _addTag,
                            ),
                          ),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _addTag(),
                        ),
                      ),
                    ],
                  ),
                  if (_tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _tags
                          .map((tag) => Chip(
                                label: Text('#$tag'),
                                deleteIcon: const Icon(Icons.close, size: 16),
                                onDeleted: () => setState(() => _tags.remove(tag)),
                                visualDensity: VisualDensity.compact,
                                backgroundColor: AppColors.primary.withAlpha(20),
                                side: BorderSide(color: AppColors.primary.withAlpha(60)),
                                labelStyle: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                ),
                              ))
                          .toList(),
                    ),
                  ],

                  const SizedBox(height: 28),

                  // ─── Sort ────────────────────────────────────────────────
                  Text(
                    'Ordenar por',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildSortChip('recent', 'Mais recentes'),
                      _buildSortChip('price_asc', 'Menor preço'),
                      _buildSortChip('price_desc', 'Maior preço'),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Apply button
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              12 + MediaQuery.of(context).padding.bottom,
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _applyFilters,
                child: const Text('Aplicar filtros'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortChip(String value, String label) {
    final isSelected = _sortBy == value;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _sortBy = value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : Theme.of(context).colorScheme.outline.withAlpha(60),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _PriceTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final ValueChanged<String> onChanged;

  const _PriceTextField({
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixText: 'R\$ ',
        prefixStyle: TextStyle(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}
