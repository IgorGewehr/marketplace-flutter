import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../providers/notifications_provider.dart';
import '../../widgets/profile/profile_menu_item.dart';

/// Notification settings screen
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(notificationSettingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notificações'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Escolha quais notificações você deseja receber',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ),

            // Push notifications section
            ProfileMenuSection(
              title: 'NOTIFICAÇÕES PUSH',
              items: [
                ProfileMenuItem(
                  icon: Icons.shopping_bag_outlined,
                  label: 'Pedidos',
                  subtitle: 'Atualizações sobre seus pedidos',
                  trailing: Switch(
                    value: settings.ordersEnabled,
                    onChanged: (value) {
                      ref.read(notificationSettingsProvider.notifier).toggleOrders(value);
                    },
                    activeColor: AppColors.primary,
                  ),
                  showChevron: false,
                ),
                ProfileMenuItem(
                  icon: Icons.chat_bubble_outline,
                  label: 'Mensagens',
                  subtitle: 'Novas mensagens no chat',
                  trailing: Switch(
                    value: settings.chatEnabled,
                    onChanged: (value) {
                      ref.read(notificationSettingsProvider.notifier).toggleChat(value);
                    },
                    activeColor: AppColors.primary,
                  ),
                  showChevron: false,
                ),
                ProfileMenuItem(
                  icon: Icons.local_offer_outlined,
                  label: 'Promoções',
                  subtitle: 'Ofertas e descontos especiais',
                  trailing: Switch(
                    value: settings.promotionsEnabled,
                    onChanged: (value) {
                      ref.read(notificationSettingsProvider.notifier).togglePromotions(value);
                    },
                    activeColor: AppColors.primary,
                  ),
                  showChevron: false,
                ),
                ProfileMenuItem(
                  icon: Icons.payments_outlined,
                  label: 'Pagamentos',
                  subtitle: 'Confirmações e alertas financeiros',
                  trailing: Switch(
                    value: settings.paymentsEnabled,
                    onChanged: (value) {
                      ref.read(notificationSettingsProvider.notifier).togglePayments(value);
                    },
                    activeColor: AppColors.primary,
                  ),
                  showChevron: false,
                ),
              ],
            ),

            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Você pode desativar notificações push a qualquer momento nas configurações do seu dispositivo.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textHint,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
