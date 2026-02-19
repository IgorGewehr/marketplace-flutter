import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';

/// Wallet balance card with prominent display
class WalletBalanceCard extends StatelessWidget {
  final double availableBalance;
  final double pendingBalance;
  final double blockedBalance;
  final VoidCallback? onWithdraw;
  final bool isLoading;

  const WalletBalanceCard({
    super.key,
    required this.availableBalance,
    this.pendingBalance = 0,
    this.blockedBalance = 0,
    this.onWithdraw,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.secondary.withAlpha(40),
                AppColors.secondary.withAlpha(15),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.secondary.withAlpha(60),
              width: 1.5,
            ),
          ),
          child: isLoading ? _buildLoadingState() : _buildContent(context),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.secondary.withAlpha(30),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: AppColors.secondary,
                size: 28,
              ),
            ),
            const Spacer(),
            if (onWithdraw != null && availableBalance > 0)
              ElevatedButton.icon(
                onPressed: onWithdraw,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.pix, size: 18),
                label: const Text(
                  'Sacar',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        
        // Label
        const Text(
          'Saldo disponível',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        
        // Available balance
        Text(
          _formatPrice(availableBalance),
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        
        // Additional balances
        if (pendingBalance > 0 || blockedBalance > 0) ...[
          const SizedBox(height: 16),
          const Divider(color: AppColors.divider),
          const SizedBox(height: 12),
          Row(
            children: [
              if (pendingBalance > 0)
                Expanded(
                  child: _BalanceItem(
                    label: 'Pendente',
                    value: pendingBalance,
                    icon: Icons.schedule,
                    color: AppColors.warning,
                  ),
                ),
              if (pendingBalance > 0 && blockedBalance > 0)
                const SizedBox(width: 16),
              if (blockedBalance > 0)
                Expanded(
                  child: _BalanceItem(
                    label: 'Bloqueado',
                    value: blockedBalance,
                    icon: Icons.lock_outline,
                    color: AppColors.error,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildLoadingState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            const Spacer(),
            Container(
              width: 100,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          width: 120,
          height: 14,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 180,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }

  String _formatPrice(double price) {
    return Formatters.currency(price);
  }
}

class _BalanceItem extends StatelessWidget {
  final String label;
  final double value;
  final IconData icon;
  final Color color;

  const _BalanceItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textHint,
              ),
            ),
            Text(
              Formatters.currency(value),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
