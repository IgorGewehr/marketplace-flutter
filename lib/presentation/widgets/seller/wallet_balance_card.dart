import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';

/// Wallet balance card — informative only (no withdrawal action)
class WalletBalanceCard extends StatelessWidget {
  final double availableBalance;
  final double pendingBalance;
  final double blockedBalance;
  final bool isLoading;

  const WalletBalanceCard({
    super.key,
    required this.availableBalance,
    this.pendingBalance = 0,
    this.blockedBalance = 0,
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
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header icon
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
        const SizedBox(height: 24),

        // Label
        Text(
          'Total ganho',
          style: AppTextStyles.balanceSmall.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),

        // Total balance (released + held) — animates from 0 on first render
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: availableBalance + pendingBalance),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOut,
          builder: (context, animatedValue, _) {
            return Text(
              _formatPrice(animatedValue),
              style: AppTextStyles.balanceLarge.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            );
          },
        ),

        // Additional balances breakdown
        if (pendingBalance > 0 || blockedBalance > 0) ...[
          const SizedBox(height: 16),
          const Divider(color: AppColors.divider),
          const SizedBox(height: 12),
          Row(
            children: [
              if (availableBalance > 0)
                Expanded(
                  child: _BalanceItem(
                    label: 'Liberado',
                    value: availableBalance,
                    icon: Icons.check_circle_outline,
                    color: AppColors.secondary,
                  ),
                ),
              if (availableBalance > 0 && pendingBalance > 0)
                const SizedBox(width: 16),
              if (pendingBalance > 0)
                Expanded(
                  child: _BalanceItem(
                    label: 'Aguardando entrega',
                    value: pendingBalance,
                    icon: Icons.schedule,
                    color: AppColors.warning,
                  ),
                ),
            ],
          ),
          if (blockedBalance > 0) ...[
            const SizedBox(height: 12),
            const Divider(color: AppColors.divider),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.lock_outline, color: AppColors.balanceBlocked, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Saldo bloqueado',
                        style: AppTextStyles.statSubtitle.copyWith(
                          color: AppColors.textHint,
                        ),
                      ),
                      Text(
                        Formatters.currency(blockedBalance),
                        style: AppTextStyles.balanceSmall.copyWith(
                          color: AppColors.balanceBlocked,
                        ),
                      ),
                    ],
                  ),
                ),
                Tooltip(
                  message: 'Disputas ou reembolsos em processamento',
                  child: Icon(
                    Icons.info_outline,
                    size: 14,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Disputas ou reembolsos em processamento',
              style: AppTextStyles.badge.copyWith(
                color: AppColors.balanceBlocked,
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildLoadingState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(14),
          ),
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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.statSubtitle.copyWith(
                  color: AppColors.textHint,
                ),
              ),
              Text(
                Formatters.currency(value),
                style: AppTextStyles.balanceSmall.copyWith(
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
