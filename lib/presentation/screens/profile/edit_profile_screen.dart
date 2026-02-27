import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/image_upload_service.dart';
import '../../providers/auth_providers.dart';
import '../../providers/core_providers.dart';
import '../../widgets/shared/app_feedback.dart';

/// Edit profile screen
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _cpfController;
  bool _isLoading = false;
  bool _hasUnsavedChanges = false;
  // Guard against populating controllers from stale/refreshing data
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _cpfController = TextEditingController();

    // Only populate immediately if we have confirmed fresh (non-loading) data.
    // If the provider is loading/refreshing (e.g. after ref.invalidate from a
    // previous save), we skip here and let the ref.listen in build() populate
    // controllers once the fresh data arrives — avoiding stale CPF values.
    final asyncUser = ref.read(currentUserProvider);
    if (!asyncUser.isLoading) {
      final user = asyncUser.valueOrNull;
      if (user != null) {
        _hasInitialized = true;
        _nameController.text = user.displayName;
        _phoneController.text = user.phone ?? '';
        _cpfController.text = user.cpfCnpj ?? '';
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cpfController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.updateProfile(
        displayName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        cpfCnpj: _cpfController.text.trim(),
      );
      // Refresh user data
      ref.invalidate(currentUserProvider);

      if (mounted) {
        setState(() => _hasUnsavedChanges = false);
        AppFeedback.showSuccess(context, 'Perfil atualizado com sucesso');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.showError(context, 'Erro ao atualizar perfil. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAvatar() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeria'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Câmera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image == null) return;

      setState(() => _isLoading = true);

      final user = ref.read(currentUserProvider).valueOrNull;
      if (user == null) return;

      final url = await imageUploadServiceProvider.uploadProfileImage(
        File(image.path),
        user.id,
      );
      await ref.read(authRepositoryProvider).updateProfile(photoURL: url);
      ref.invalidate(currentUserProvider);

      if (mounted) {
        AppFeedback.showSuccess(context, 'Foto de perfil atualizada!');
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.showError(context, 'Erro ao selecionar imagem');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    // Populate controllers when fresh data first becomes available.
    // This handles the case where the provider was refreshing (loading) when
    // initState ran — e.g. immediately after saving the profile and returning.
    ref.listen<AsyncValue<UserModel?>>(currentUserProvider, (_, next) {
      if (_hasInitialized || next.isLoading) return;
      next.whenData((user) {
        if (user != null) {
          _hasInitialized = true;
          _nameController.text = user.displayName;
          _phoneController.text = user.phone ?? '';
          _cpfController.text = user.cpfCnpj ?? '';
        }
      });
    });

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
          title: const Text('Editar Perfil'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        body: userAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(child: Text('Erro ao carregar perfil')),
          data: (user) {
            if (user == null) {
              return const Center(child: Text('Usuário não encontrado'));
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Avatar section
                    Center(
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primary,
                                width: 3,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 56,
                              backgroundColor: AppColors.border,
                              backgroundImage: user.photoURL != null
                                  ? NetworkImage(user.photoURL!)
                                  : null,
                              child: user.photoURL == null
                                  ? Text(
                                      user.displayName.isNotEmpty
                                          ? user.displayName[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        fontSize: 40,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textSecondary,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Material(
                              color: AppColors.primary,
                              shape: const CircleBorder(),
                              child: InkWell(
                                onTap: _pickAvatar,
                                customBorder: const CircleBorder(),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  child: const Icon(
                                    Icons.camera_alt_rounded,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Form fields
                    _buildTextField(
                      label: 'Nome completo',
                      controller: _nameController,
                      icon: Icons.person_outline,
                      onChanged: (_) {
                        if (!_hasUnsavedChanges) setState(() => _hasUnsavedChanges = true);
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Digite seu nome';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    _buildTextField(
                      label: 'E-mail',
                      initialValue: user.email,
                      icon: Icons.email_outlined,
                      enabled: false,
                    ),
                    const SizedBox(height: 16),

                    _buildTextField(
                      label: 'Telefone',
                      controller: _phoneController,
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      onChanged: (_) {
                        if (!_hasUnsavedChanges) setState(() => _hasUnsavedChanges = true);
                      },
                    ),
                    const SizedBox(height: 16),

                    _buildTextField(
                      label: 'CPF/CNPJ',
                      controller: _cpfController,
                      icon: Icons.badge_outlined,
                      keyboardType: TextInputType.number,
                      onChanged: (_) {
                        if (!_hasUnsavedChanges) setState(() => _hasUnsavedChanges = true);
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) return null;
                        final digits = value.replaceAll(RegExp(r'\D'), '');
                        if (digits.length != 11 && digits.length != 14) {
                          return 'CPF deve ter 11 dígitos ou CNPJ 14 dígitos';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 32),

                    // Save button
                    FilledButton(
                      onPressed: _isLoading ? null : _handleSave,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                              'Salvar alterações',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    TextEditingController? controller,
    String? initialValue,
    required IconData icon,
    bool enabled = true,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        initialValue: controller == null ? initialValue : null,
        enabled: enabled,
        keyboardType: keyboardType,
        validator: validator,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: enabled ? theme.colorScheme.surface : AppColors.background,
        ),
      ),
    );
  }
}
