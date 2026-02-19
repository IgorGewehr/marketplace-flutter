import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Order action buttons based on current status
class OrderActions extends StatelessWidget {
  final String currentStatus;
  final bool isLoading;
  final VoidCallback? onAccept;
  final VoidCallback? onStartPreparing;
  final VoidCallback? onMarkReady;
  final VoidCallback? onShip;
  final VoidCallback? onChat;

  const OrderActions({
    super.key,
    required this.currentStatus,
    this.isLoading = false,
    this.onAccept,
    this.onStartPreparing,
    this.onMarkReady,
    this.onShip,
    this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Main action button
        ..._buildActionButtons(),
        const SizedBox(height: 12),
        // Chat button
        if (onChat != null)
          OutlinedButton.icon(
            onPressed: isLoading ? null : onChat,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.sellerAccent,
              side: const BorderSide(color: AppColors.sellerAccent),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.chat_bubble_outline, size: 20),
            label: const Text(
              'Chat com comprador',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }

  List<Widget> _buildActionButtons() {
    switch (currentStatus) {
      case 'pending':
        return [
          _ActionButton(
            label: 'Aceitar Pedido',
            icon: Icons.check_circle_outline,
            color: AppColors.secondary,
            onPressed: isLoading ? null : onAccept,
            isLoading: isLoading,
          ),
        ];
      case 'confirmed':
        return [
          _ActionButton(
            label: 'Iniciar Preparo',
            icon: Icons.inventory_2_outlined,
            color: AppColors.statusPreparing,
            onPressed: isLoading ? null : onStartPreparing,
            isLoading: isLoading,
          ),
        ];
      case 'preparing':
        return [
          _ActionButton(
            label: 'Marcar Pronto',
            icon: Icons.done_all,
            color: AppColors.statusReady,
            onPressed: isLoading ? null : onMarkReady,
            isLoading: isLoading,
          ),
        ];
      case 'ready':
        return [
          _ActionButton(
            label: 'Enviar Pedido',
            icon: Icons.local_shipping_outlined,
            color: AppColors.statusShipped,
            onPressed: isLoading ? null : onShip,
            isLoading: isLoading,
          ),
        ];
      case 'shipped':
        return [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.statusShipped.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.local_shipping, color: AppColors.statusShipped),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Pedido enviado. Aguardando entrega.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ];
      case 'delivered':
        return [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.secondary.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.secondary),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Pedido entregue com sucesso!',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ];
      case 'cancelled':
        return [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.error.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.cancel, color: AppColors.error),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Pedido cancelado.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ];
      default:
        return [];
    }
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
  final bool isLoading;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 0,
      ),
      icon: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : Icon(icon, size: 22),
      label: Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
