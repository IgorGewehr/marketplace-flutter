import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../providers/products_provider.dart';

/// Search filters bottom sheet
class SearchFiltersSheet extends ConsumerStatefulWidget {
  const SearchFiltersSheet({super.key});

  @override
  ConsumerState<SearchFiltersSheet> createState() => _SearchFiltersSheetState();
}

class _SearchFiltersSheetState extends ConsumerState<SearchFiltersSheet> {
  late String _selectedCategory;
  RangeValues _priceRange = const RangeValues(0, 50000);
  String _sortBy = 'recent';
  final _tagController = TextEditingController();
  List<String> _tags = [];

  @override
  void initState() {
    super.initState();
    final filters = ref.read(productFiltersProvider);
    // filters.category stores a category ID; resolve it back to a name for display
    final categoryId = filters.category;
    if (categoryId != null) {
      final idToName = ref.read(categoryIdToNameProvider).valueOrNull ?? {};
      _selectedCategory = idToName[categoryId] ?? 'Todos';
    } else {
      _selectedCategory = 'Todos';
    }
    _priceRange = RangeValues(
      filters.minPrice ?? 0,
      filters.maxPrice ?? 50000,
    );
    _sortBy = filters.sortBy;
    _tags = List.from(filters.tags ?? []);
  }

  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    final currentFilters = ref.read(productFiltersProvider);
    final nameToId = ref.read(categoryNameToIdProvider).valueOrNull ?? {};
    final categoryId = _selectedCategory == 'Todos'
        ? null
        : nameToId[_selectedCategory] ?? _selectedCategory;
    ref.read(productFiltersProvider.notifier).state = currentFilters.copyWith(
      category: categoryId,
      minPrice: _priceRange.start > 0 ? _priceRange.start : null,
      maxPrice: _priceRange.end < 50000 ? _priceRange.end : null,
      sortBy: _sortBy,
      tags: _tags.isNotEmpty ? _tags : null,
      page: 1, // Reset to first page
    );
    Navigator.pop(context);
  }

  void _clearFilters() {
    setState(() {
      _selectedCategory = 'Todos';
      _priceRange = const RangeValues(0, 50000);
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
                  child: const Text('Limpar'),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Scrollable content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category filter
                  Text(
                    'Categoria',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  categoriesAsync.when(
                    loading: () => const CircularProgressIndicator(),
                    error: (_, __) => const Text('Erro ao carregar categorias'),
                    data: (categories) => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categories.map((category) {
                        final isSelected = category == _selectedCategory;
                        return FilterChip(
                          label: Text(category),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() => _selectedCategory = category);
                          },
                          selectedColor: theme.colorScheme.primaryContainer,
                          checkmarkColor: theme.colorScheme.primary,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface,
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Price range filter
                  Text(
                    'Faixa de preço',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        Formatters.currency(_priceRange.start),
                        style: theme.textTheme.bodyMedium,
                      ),
                      Text(
                        _priceRange.end >= 50000
                            ? 'R\$ 50.000+'
                            : Formatters.currency(_priceRange.end),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  RangeSlider(
                    values: _priceRange,
                    min: 0,
                    max: 50000,
                    divisions: 100,
                    labels: RangeLabels(
                      Formatters.currency(_priceRange.start),
                      Formatters.currency(_priceRange.end),
                    ),
                    onChanged: (values) {
                      setState(() => _priceRange = values);
                    },
                  ),

                  const SizedBox(height: 24),

                  // Tag filter
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
                      children: _tags.map((tag) => Chip(
                        label: Text('#$tag'),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () => setState(() => _tags.remove(tag)),
                        visualDensity: VisualDensity.compact,
                      )).toList(),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Sort by filter
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
    final theme = Theme.of(context);
    final isSelected = _sortBy == value;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _sortBy = value);
      },
      selectedColor: theme.colorScheme.primaryContainer,
      checkmarkColor: theme.colorScheme.primary,
    );
  }
}
