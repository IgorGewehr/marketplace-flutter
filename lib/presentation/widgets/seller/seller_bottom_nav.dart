import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../providers/seller_orders_provider.dart';

/// Floating bottom navigation for seller mode with glass effect
class SellerBottomNav extends ConsumerWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback? onFabPressed;

  const SellerBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.onFabPressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newOrdersCount = ref.watch(newOrdersCountProvider);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Positioned(
      left: 16,
      right: 16,
      bottom: 16 + bottomPadding,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(230),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppColors.sellerAccent.withAlpha(30),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.sellerAccent.withAlpha(20),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _SellerNavItem(
                  icon: Icons.dashboard_rounded,
                  label: 'Início',
                  isSelected: currentIndex == 0,
                  onTap: () => onTap(0),
                ),
                _SellerNavItem(
                  icon: Icons.inventory_2_outlined,
                  label: 'Produtos',
                  isSelected: currentIndex == 1,
                  onTap: () => onTap(1),
                ),
                // Center FAB
                _SellerCenterFab(onPressed: onFabPressed),
                _SellerNavItem(
                  icon: Icons.receipt_long_outlined,
                  label: 'Pedidos',
                  isSelected: currentIndex == 2,
                  onTap: () => onTap(2),
                  badgeCount: newOrdersCount,
                ),
                _SellerNavItem(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Carteira',
                  isSelected: currentIndex == 3,
                  onTap: () => onTap(3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SellerNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int badgeCount;

  const _SellerNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? AppColors.sellerAccent
        : AppColors.textSecondary;

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedScale(
                  scale: isSelected ? 1.12 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  child: Icon(
                    icon,
                    color: color,
                    size: 26,
                  ),
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.sellerAccent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(minWidth: 18),
                      child: Text(
                        badgeCount > 99 ? '99+' : badgeCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SellerCenterFab extends StatefulWidget {
  final VoidCallback? onPressed;

  const _SellerCenterFab({this.onPressed});

  @override
  State<_SellerCenterFab> createState() => _SellerCenterFabState();
}

class _SellerCenterFabState extends State<_SellerCenterFab> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        HapticFeedback.mediumImpact();
        widget.onPressed?.call();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.88 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeInOut,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: AppColors.sellerGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.sellerAccent.withAlpha(_isPressed ? 40 : 80),
                blurRadius: _isPressed ? 6 : 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.add_rounded,
            color: Colors.white,
            size: 32,
          ),
        ),
      ),
    );
  }
}
