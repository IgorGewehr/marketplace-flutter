import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/auth_providers.dart';
import '../../providers/core_providers.dart';
import '../../widgets/profile/profile_menu_item.dart';
import '../../widgets/shared/app_feedback.dart';

/// Settings screen
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Configurações'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Notifications
            ProfileMenuSection(
              title: 'NOTIFICAÇÕES',
              items: [
                ProfileMenuItem(
                  icon: Icons.notifications_outlined,
                  label: 'Preferências de Notificação',
                  subtitle: 'Gerencie seus alertas',
                  onTap: () => context.push(AppRouter.notificationSettings),
                ),
              ],
            )
                .animate()
                .fadeIn(duration: 350.ms)
                .slideY(begin: 0.1, curve: Curves.easeOut),

            // Privacy & Security
            ProfileMenuSection(
              title: 'PRIVACIDADE E SEGURANÇA',
              items: [
                ProfileMenuItem(
                  icon: Icons.lock_outline_rounded,
                  label: 'Alterar Senha',
                  onTap: () => _showChangePasswordDialog(context, ref),
                ),
                ProfileMenuItem(
                  icon: Icons.security_rounded,
                  label: 'Autenticação em Dois Fatores',
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Em breve',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondary,
                      ),
                    ),
                  ),
                  showChevron: false,
                ),
                // Gap #25: Use StateProvider instead of markNeedsBuild hack
                ProfileMenuItem(
                  icon: Icons.fingerprint_rounded,
                  label: 'Biometria',
                  subtitle: 'Use impressão digital ou Face ID',
                  trailing: Switch(
                    value: ref.watch(biometricEnabledProvider),
                    onChanged: (value) {
                      ref.read(localStorageProvider).setBool('biometric_enabled', value);
                      ref.read(biometricEnabledProvider.notifier).state = value;
                      AppFeedback.showInfo(
                        context,
                        value ? 'Biometria ativada' : 'Biometria desativada',
                        duration: const Duration(seconds: 1),
                      );
                    },
                  ),
                  showChevron: false,
                ),
              ],
            )
                .animate()
                .fadeIn(delay: 100.ms, duration: 350.ms)
                .slideY(begin: 0.1, curve: Curves.easeOut),

            // Support
            ProfileMenuSection(
              title: 'SUPORTE',
              items: [
                ProfileMenuItem(
                  icon: Icons.help_outline_rounded,
                  label: 'Central de Ajuda',
                  onTap: () => _openUrl(context, AppConstants.helpUrl),
                ),
                ProfileMenuItem(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Fale Conosco',
                  onTap: () => _openWhatsApp(context),
                ),
                ProfileMenuItem(
                  icon: Icons.bug_report_outlined,
                  label: 'Reportar um Problema',
                  onTap: () => _openUrl(context, 'mailto:${AppConstants.supportEmail}?subject=Bug Report'),
                ),
              ],
            )
                .animate()
                .fadeIn(delay: 200.ms, duration: 350.ms)
                .slideY(begin: 0.1, curve: Curves.easeOut),

            // Legal
            ProfileMenuSection(
              title: 'LEGAL',
              items: [
                ProfileMenuItem(
                  icon: Icons.description_outlined,
                  label: 'Termos de Uso',
                  onTap: () => _openUrl(context, AppConstants.termsUrl),
                ),
                ProfileMenuItem(
                  icon: Icons.privacy_tip_outlined,
                  label: 'Política de Privacidade',
                  onTap: () => _openUrl(context, AppConstants.privacyUrl),
                ),
                ProfileMenuItem(
                  icon: Icons.cookie_outlined,
                  label: 'Política de Cookies',
                  onTap: () => _openUrl(context, AppConstants.cookiesUrl),
                ),
              ],
            )
                .animate()
                .fadeIn(delay: 300.ms, duration: 350.ms)
                .slideY(begin: 0.1, curve: Curves.easeOut),

            // Danger zone
            ProfileMenuSection(
              title: 'CONTA',
              items: [
                ProfileMenuItem(
                  icon: Icons.delete_outline_rounded,
                  label: 'Excluir Conta',
                  subtitle: 'Esta ação é irreversível',
                  isDestructive: true,
                  showChevron: false,
                  onTap: () => _showDeleteAccountDialog(context, ref),
                ),
              ],
            )
                .animate()
                .fadeIn(delay: 400.ms, duration: 350.ms)
                .slideY(begin: 0.1, curve: Curves.easeOut),

            // Version info
            const SizedBox(height: 16),
            Column(
              children: [
                const Text(
                  'Compre Aqui v1.0.0 (build 1)',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textHint,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '© 2024 Compre Aqui. Todos os direitos reservados.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            )
                .animate()
                .fadeIn(delay: 500.ms, duration: 350.ms),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      AppFeedback.showError(context, 'Não foi possível abrir o link');
    }
  }

  Future<void> _openWhatsApp(BuildContext context) async {
    final uri = Uri.parse('https://wa.me/${AppConstants.supportWhatsAppPhone}?text=Olá, preciso de ajuda com o Compre Aqui');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      AppFeedback.showError(context, 'WhatsApp não disponível');
    }
  }

  void _showChangePasswordDialog(BuildContext context, WidgetRef ref) {
    final user = ref.read(currentUserProvider).valueOrNull;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alterar senha'),
        content: Text(
          'Enviaremos um email para ${user?.email ?? 'seu email cadastrado'} '
          'com instruções para redefinir sua senha.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              if (user?.email != null) {
                await ref.read(authNotifierProvider.notifier).resetPassword(
                  email: user!.email,
                );
                if (context.mounted) {
                  AppFeedback.showSuccess(context, 'Email de redefinição de senha enviado');
                }
              }
            },
            child: const Text('Enviar email'),
          ),
        ],
      ),
    );
  }

  // Gap #12: Validate the "EXCLUIR" confirmation word
  void _showDeleteAccountDialog(BuildContext context, WidgetRef ref) {
    final confirmController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final isConfirmed = confirmController.text.trim().toUpperCase() == 'EXCLUIR';
          return AlertDialog(
            title: const Text('Excluir conta'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Esta ação é permanente e não pode ser desfeita. '
                  'Todos os seus dados serão excluídos.\n\n'
                  'Digite "EXCLUIR" para confirmar.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmController,
                  onChanged: (_) => setDialogState(() {}),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'EXCLUIR',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: isConfirmed
                    ? () async {
                        Navigator.pop(dialogContext);
                        final success = await ref
                            .read(authNotifierProvider.notifier)
                            .deleteAccount();
                        if (context.mounted) {
                          if (success) {
                            context.go(AppRouter.login);
                            AppFeedback.showSuccess(
                              context,
                              'Conta excluída com sucesso.',
                            );
                          } else {
                            AppFeedback.showError(
                              context,
                              'Não foi possível excluir a conta. Tente novamente.',
                            );
                          }
                        }
                      }
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error,
                ),
                child: const Text('Excluir minha conta'),
              ),
            ],
          );
        },
      ),
    );
  }
}
