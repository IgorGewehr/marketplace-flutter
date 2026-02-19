import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/utils/validators.dart';
import '../../providers/auth_providers.dart';
import '../../widgets/auth/auth_button.dart';
import '../../widgets/auth/auth_text_field.dart';
import '../../widgets/auth/cpf_cnpj_field.dart';
import '../../widgets/auth/phone_field.dart';

/// Complete Profile Screen - Required for first-time users
class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _cpfCnpjController = TextEditingController();
  final _phoneController = TextEditingController();
  DateTime? _birthDate;

  @override
  void initState() {
    super.initState();
    // Pre-fill name if available from Firebase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final firebaseUser = ref.read(currentFirebaseUserProvider);
      if (firebaseUser?.displayName != null) {
        _nameController.text = firebaseUser!.displayName!;
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cpfCnpjController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Informe sua data de nascimento'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final success = await ref.read(authNotifierProvider.notifier).completeProfile(
          fullName: _nameController.text.trim(),
          phone: _phoneController.text.replaceAll(RegExp(r'\D'), ''),
          cpfCnpj: _cpfCnpjController.text.replaceAll(RegExp(r'\D'), ''),
          birthDate: _birthDate,
        );

    if (success && mounted) {
      context.go(AppRouter.home);
    }
  }

  static const _months = [
    'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
    'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
  ];

  void _selectBirthDate() {
    final now = DateTime.now();
    final maxYear = now.year - 18;
    final minYear = now.year - 100;

    final initial = _birthDate ?? DateTime(maxYear, now.month, now.day);
    var selectedDay = initial.day;
    var selectedMonth = initial.month;
    var selectedYear = initial.year;

    int daysInMonth(int month, int year) {
      return DateTime(year, month + 1, 0).day;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final maxDays = daysInMonth(selectedMonth, selectedYear);
            if (selectedDay > maxDays) {
              selectedDay = maxDays;
            }

            return Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle bar
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant.withAlpha(60),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text(
                              'Cancelar',
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Text(
                            'Data de nascimento',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              final clamped = selectedDay.clamp(1, maxDays);
                              setState(() {
                                _birthDate = DateTime(selectedYear, selectedMonth, clamped);
                              });
                              Navigator.pop(ctx);
                            },
                            child: Text(
                              'Confirmar',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Pickers
                    SizedBox(
                      height: 220,
                      child: Row(
                        children: [
                          // Day
                          Expanded(
                            flex: 2,
                            child: CupertinoPicker(
                              scrollController: FixedExtentScrollController(
                                initialItem: selectedDay - 1,
                              ),
                              itemExtent: 42,
                              diameterRatio: 1.2,
                              selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
                                background: theme.colorScheme.primary.withAlpha(20),
                              ),
                              onSelectedItemChanged: (i) {
                                setModalState(() => selectedDay = i + 1);
                              },
                              children: List.generate(maxDays, (i) {
                                return Center(
                                  child: Text(
                                    '${i + 1}',
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                );
                              }),
                            ),
                          ),

                          // Month
                          Expanded(
                            flex: 4,
                            child: CupertinoPicker(
                              scrollController: FixedExtentScrollController(
                                initialItem: selectedMonth - 1,
                              ),
                              itemExtent: 42,
                              diameterRatio: 1.2,
                              selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
                                background: theme.colorScheme.primary.withAlpha(20),
                              ),
                              onSelectedItemChanged: (i) {
                                setModalState(() => selectedMonth = i + 1);
                              },
                              children: _months.map((m) {
                                return Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                      child: Text(m, style: const TextStyle(fontSize: 20)),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),

                          // Year
                          Expanded(
                            flex: 3,
                            child: CupertinoPicker(
                              scrollController: FixedExtentScrollController(
                                initialItem: maxYear - selectedYear,
                              ),
                              itemExtent: 42,
                              diameterRatio: 1.2,
                              selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
                                background: theme.colorScheme.primary.withAlpha(20),
                              ),
                              onSelectedItemChanged: (i) {
                                setModalState(() => selectedYear = maxYear - i);
                              },
                              children: List.generate(maxYear - minYear + 1, (i) {
                                return Center(
                                  child: Text(
                                    '${maxYear - i}',
                                    style: const TextStyle(fontSize: 20),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 16 + MediaQuery.of(ctx).padding.bottom.clamp(0, 34)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),

              // Progress indicator
              SizedBox(
                height: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: 0.5,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Header
              Text(
                'Complete seu perfil',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Precisamos de algumas informações para você poder comprar',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 40),

              // Form
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Name
                    AuthTextField(
                      controller: _nameController,
                      label: 'Nome completo',
                      hint: 'Como aparece no documento',
                      prefixIcon: Icons.person_outline,
                      keyboardType: TextInputType.name,
                      textInputAction: TextInputAction.next,
                      validator: Validators.validateName,
                      enabled: !isLoading,
                    ),

                    const SizedBox(height: 20),

                    // CPF/CNPJ
                    CpfCnpjField(
                      controller: _cpfCnpjController,
                      enabled: !isLoading,
                      textInputAction: TextInputAction.next,
                    ),

                    const SizedBox(height: 20),

                    // Birth Date
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 8),
                          child: Text(
                            'Data de nascimento',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: isLoading ? null : _selectBirthDate,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 18,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: theme.colorScheme.outline.withAlpha((255 * 0.3).round()),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_outlined,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _birthDate != null
                                      ? _formatDate(_birthDate!)
                                      : 'Selecionar data',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: _birthDate != null
                                        ? theme.colorScheme.onSurface
                                        : theme.colorScheme.onSurfaceVariant,
                                    fontWeight: _birthDate != null
                                        ? FontWeight.w500
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Phone
                    PhoneField(
                      controller: _phoneController,
                      enabled: !isLoading,
                      textInputAction: TextInputAction.done,
                    ),

                    const SizedBox(height: 32),

                    // Error message
                    if (authState.hasError)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.error.withAlpha((255 * 0.1).round()),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.error.withAlpha((255 * 0.3).round()),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: theme.colorScheme.error,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                getAuthErrorMessage(authState.error!),
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Submit button
                    AuthButton(
                      text: 'Continuar',
                      onPressed: isLoading ? null : _handleSubmit,
                      isLoading: isLoading,
                    ),

                    const SizedBox(height: 16),

                    // Skip button (just browse without completing profile)
                    TextButton(
                      onPressed: isLoading
                          ? null
                          : () {
                              if (mounted) context.go(AppRouter.home);
                            },
                      child: Text(
                        'Completar depois',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
