import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/services/image_upload_service.dart';
import '../../providers/auth_providers.dart';
import '../../providers/core_providers.dart';
import '../../providers/tenant_provider.dart';
import '../../widgets/shared/app_feedback.dart';

/// Screen for editing the seller's store profile: logo, cover, name, description.
class SellerEditProfileScreen extends ConsumerStatefulWidget {
  const SellerEditProfileScreen({super.key});

  @override
  ConsumerState<SellerEditProfileScreen> createState() =>
      _SellerEditProfileScreenState();
}

class _SellerEditProfileScreenState
    extends ConsumerState<SellerEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  File? _pendingLogo;
  File? _pendingCover;
  bool _isSaving = false;
  bool _isInitialized = false;

  String? _tenantId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  void _init() {
    final user = ref.read(currentUserProvider).valueOrNull;
    _tenantId = user?.tenantId;
    if (_tenantId == null) return;
    final tenant = ref.read(tenantByIdProvider(_tenantId!)).valueOrNull;
    if (tenant != null && !_isInitialized) {
      _isInitialized = true;
      _nameController.text = tenant.displayName;
      _descriptionController.text = tenant.description ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // ─── Image Picking ────────────────────────────────────────────────────────

  Future<void> _pickImage({required bool isCover}) async {
    final source = await _showSourceDialog(
      label: isCover ? 'capa da loja' : 'logo da loja',
    );
    if (source == null) return;

    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: source,
      maxWidth: isCover ? 1920 : 512,
      maxHeight: isCover ? 640 : 512,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() {
      if (isCover) {
        _pendingCover = File(picked.path);
      } else {
        _pendingLogo = File(picked.path);
      }
    });
  }

  Future<ImageSource?> _showSourceDialog({required String label}) {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Escolher $label',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Galeria de fotos'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Câmera'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Save ─────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_tenantId == null) return;

    setState(() => _isSaving = true);
    try {
      String? newLogoUrl;
      String? newCoverUrl;

      // Upload pending images first
      if (_pendingLogo != null) {
        newLogoUrl = await imageUploadServiceProvider.uploadTenantImage(
          _pendingLogo!,
          _tenantId!,
          isCover: false,
        );
      }
      if (_pendingCover != null) {
        newCoverUrl = await imageUploadServiceProvider.uploadTenantImage(
          _pendingCover!,
          _tenantId!,
          isCover: true,
        );
      }

      final name = _nameController.text.trim();
      final description = _descriptionController.text.trim();

      // Only send fields that changed
      await ref.read(tenantRepositoryProvider).updateProfile(
            name: name.isNotEmpty ? name : null,
            description: description,
            logoUrl: newLogoUrl,
            coverUrl: newCoverUrl,
          );

      // Refresh tenant data everywhere
      ref.invalidate(tenantByIdProvider(_tenantId!));

      if (mounted) {
        AppFeedback.showSuccess(context, 'Perfil da loja atualizado!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        AppFeedback.showError(
            context, 'Erro ao salvar. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final tenantId = user?.tenantId;
    final tenantAsync =
        tenantId != null ? ref.watch(tenantByIdProvider(tenantId)) : null;
    final tenant = tenantAsync?.valueOrNull;

    // Pre-fill form on first load
    if (tenant != null && !_isInitialized) {
      _isInitialized = true;
      _nameController.text = tenant.displayName;
      _descriptionController.text = tenant.description ?? '';
    }

    final theme = Theme.of(context);
    final coverHeight = 180.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Perfil da Loja'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Salvar',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Cover + Logo header ──────────────────────────────────────
              Stack(
                clipBehavior: Clip.none,
                children: [
                  // Cover image
                  GestureDetector(
                    onTap: () => _pickImage(isCover: true),
                    child: SizedBox(
                      width: double.infinity,
                      height: coverHeight,
                      child: _pendingCover != null
                          ? Image.file(
                              _pendingCover!,
                              fit: BoxFit.cover,
                            )
                          : tenant?.coverURL != null
                              ? CachedNetworkImage(
                                  imageUrl: tenant!.coverURL!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: coverHeight,
                                  placeholder: (_, __) => _CoverPlaceholder(
                                    height: coverHeight,
                                  ),
                                  errorWidget: (_, __, ___) =>
                                      _CoverPlaceholder(
                                    height: coverHeight,
                                  ),
                                )
                              : _CoverPlaceholder(height: coverHeight),
                    ),
                  ),

                  // Cover edit button overlay
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: _EditImageButton(
                      onTap: () => _pickImage(isCover: true),
                      label: 'Editar capa',
                    ),
                  ),

                  // Logo — overlaps bottom of cover
                  Positioned(
                    bottom: -52.0,
                    left: 20,
                    child: GestureDetector(
                      onTap: () => _pickImage(isCover: false),
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.colorScheme.surface,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(30),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 44,
                              backgroundColor:
                                  theme.colorScheme.primaryContainer,
                              backgroundImage: _pendingLogo != null
                                  ? FileImage(_pendingLogo!) as ImageProvider
                                  : tenant?.logoURL != null
                                      ? CachedNetworkImageProvider(
                                          tenant!.logoURL!)
                                      : null,
                              child: (_pendingLogo == null &&
                                      tenant?.logoURL == null)
                                  ? Text(
                                      (tenant?.displayName.isNotEmpty == true)
                                          ? tenant!.displayName[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          // Edit badge
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.colorScheme.surface,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Spacing for logo overflow
              const SizedBox(height: 64),

              // ── Form fields ─────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Informações da Loja',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Store name
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Nome da loja',
                        prefixIcon: const Icon(Icons.storefront_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Informe o nome da loja';
                        }
                        if (v.trim().length < 2) {
                          return 'Nome muito curto';
                        }
                        return null;
                      },
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: 16),

                    // Description
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Descrição da loja (opcional)',
                        hintText:
                            'Conte um pouco sobre seus produtos e diferenciais...',
                        prefixIcon: const Icon(Icons.description_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 4,
                      maxLength: 500,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: 8),

                    // Tips
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            theme.colorScheme.primaryContainer.withAlpha(60),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Logo quadrado ou redondo (512×512px). Capa em formato retangular (1920×640px).',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isSaving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_outlined, size: 20),
                        label: Text(
                          _isSaving ? 'Salvando...' : 'Salvar alterações',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: MediaQuery.of(context).padding.bottom + 24,
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

// ─── Helper Widgets ──────────────────────────────────────────────────────────

class _CoverPlaceholder extends StatelessWidget {
  final double height;
  const _CoverPlaceholder({required this.height});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      height: height,
      color: AppColors.primary.withAlpha(180),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.image_outlined,
            size: 40,
            color: Colors.white.withAlpha(180),
          ),
          const SizedBox(height: 8),
          Text(
            'Toque para adicionar uma capa',
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withAlpha(200),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditImageButton extends StatelessWidget {
  final VoidCallback onTap;
  final String label;

  const _EditImageButton({required this.onTap, required this.label});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(160),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.camera_alt_outlined,
              color: Colors.white,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
