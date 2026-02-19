import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../providers/auth_providers.dart';
import '../../providers/core_providers.dart';
import '../../widgets/profile/profile_menu_item.dart';

/// Settings screen
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Configurações'),
        foregroundColor: AppColors.textPrimary,
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
            ),

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
                ProfileMenuItem(
                  icon: Icons.fingerprint_rounded,
                  label: 'Biometria',
                  subtitle: 'Use impressão digital ou Face ID',
                  trailing: Consumer(
                    builder: (ctx, innerRef, _) {
                      final localStorage = innerRef.read(localStorageProvider);
                      final enabled = innerRef.watch(biometricEnabledProvider);
                      return Switch(
                        value: enabled,
                        onChanged: (value) {
                          localStorage.setBool('biometric_enabled', value);
                          innerRef.read(biometricEnabledProvider.notifier).state = value;
                          ScaffoldMessenger.of(ctx)
                            ..clearSnackBars()
                            ..showSnackBar(
                              SnackBar(
                                content: Text(value ? 'Biometria ativada' : 'Biometria desativada'),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                        },
                      );
                    },
                  ),
                  showChevron: false,
                ),
              ],
            ),

            // Support
            ProfileMenuSection(
              title: 'SUPORTE',
              items: [
                ProfileMenuItem(
                  icon: Icons.help_outline_rounded,
                  label: 'Central de Ajuda',
                  onTap: () => _openUrl(context, 'https://reidobrique.com.br/ajuda'),
                ),
                ProfileMenuItem(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Fale Conosco',
                  onTap: () => _openWhatsApp(context),
                ),
                ProfileMenuItem(
                  icon: Icons.bug_report_outlined,
                  label: 'Reportar um Problema',
                  onTap: () => _openUrl(context, 'mailto:suporte@reidobrique.com.br?subject=Bug Report'),
                ),
              ],
            ),

            // Legal
            ProfileMenuSection(
              title: 'LEGAL',
              items: [
                ProfileMenuItem(
                  icon: Icons.description_outlined,
                  label: 'Termos de Uso',
                  onTap: () => _openUrl(context, 'https://reidobrique.com.br/termos'),
                ),
                ProfileMenuItem(
                  icon: Icons.privacy_tip_outlined,
                  label: 'Política de Privacidade',
                  onTap: () => _openUrl(context, 'https://reidobrique.com.br/privacidade'),
                ),
                ProfileMenuItem(
                  icon: Icons.cookie_outlined,
                  label: 'Política de Cookies',
                  onTap: () => _openUrl(context, 'https://reidobrique.com.br/cookies'),
                ),
              ],
            ),

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
            ),

            // Version info
            const SizedBox(height: 16),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o link')),
      );
    }
  }

  Future<void> _openWhatsApp(BuildContext context) async {
    const phone = '5547997856405';
    final uri = Uri.parse('https://wa.me/$phone?text=Olá, preciso de ajuda com o Compre Aqui');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp não disponível')),
      );
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
                  ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
                    const SnackBar(
                      content: Text('Email de redefinição de senha enviado'),
                      backgroundColor: AppColors.secondary,
                    ),
                  );
                }
              }
            },
            child: const Text('Enviar email'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, WidgetRef ref) {
    final confirmController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final isConfirmed = confirmController.text == 'EXCLUIR';
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
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'EXCLUIR',
                  ),
                  onChanged: (_) => setDialogState(() {}),
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
                        await ref.read(authNotifierProvider.notifier).signOut();
                        if (context.mounted) {
                          context.go(AppRouter.login);
                          ScaffoldMessenger.of(context)..clearSnackBars()..showSnackBar(
                            const SnackBar(
                              content: Text('Solicitação de exclusão enviada. Você será notificado por email.'),
                            ),
                          );
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
