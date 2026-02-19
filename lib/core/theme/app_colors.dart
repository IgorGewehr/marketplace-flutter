import 'package:flutter/material.dart';

/// App Color Palette for Compre Aqui
/// Designed for accessibility with focus on 40+ users
class AppColors {
  AppColors._();

  // === Primary Colors ===
  static const Color primary = Color(0xFF007BFF);
  static const Color primaryLight = Color(0xFF4DA3FF);
  static const Color primaryDark = Color(0xFF0056B3);

  // === Secondary Colors ===
  static const Color secondary = Color(0xFF00C853);
  static const Color secondaryLight = Color(0xFF5EFC82);
  static const Color secondaryDark = Color(0xFF009624);

  // === Seller Accent Colors ===
  static const Color sellerAccent = Color(0xFF6C5CE7);
  static const Color sellerAccentLight = Color(0xFF9D8DF1);
  static const Color sellerAccentDark = Color(0xFF4834D4);

  // === Background Colors ===
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F3F5);

  // === Text Colors ===
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFFBDBDBD);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnSecondary = Color(0xFFFFFFFF);

  // === Status Colors ===
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFE53935);
  static const Color info = Color(0xFF2196F3);

  // === Order Status Colors ===
  static const Color statusPending = Color(0xFFFFA726);
  static const Color statusConfirmed = Color(0xFF42A5F5);
  static const Color statusPreparing = Color(0xFFAB47BC);
  static const Color statusReady = Color(0xFF26A69A);
  static const Color statusShipped = Color(0xFF5C6BC0);
  static const Color statusDelivered = Color(0xFF66BB6A);
  static const Color statusCancelled = Color(0xFFEF5350);

  // === Divider & Border Colors ===
  static const Color divider = Color(0xFFE0E0E0);
  static const Color border = Color(0xFFDEE2E6);
  static const Color borderLight = Color(0xFFF1F3F5);

  // === Shadow Colors ===
  static const Color shadow = Color(0x1A000000);
  static const Color shadowLight = Color(0x0D000000);

  // === Glass Effect Colors ===
  static const Color glassBackground = Color(0xB3FFFFFF);
  static const Color glassBorder = Color(0x33FFFFFF);

  // === Gradient Definitions ===
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [secondary, secondaryDark],
  );

  static const LinearGradient sellerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [sellerAccent, sellerAccentDark],
  );

  // === Dark Mode Colors ===
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkSurfaceVariant = Color(0xFF2C2C2C);
  static const Color darkTextPrimary = Color(0xFFE0E0E0);
  static const Color darkTextSecondary = Color(0xFF9E9E9E);
  static const Color darkBorder = Color(0xFF3A3A3A);
  static const Color darkDivider = Color(0xFF333333);

  // === Color Scheme ===
  static ColorScheme get lightColorScheme => const ColorScheme.light(
        primary: primary,
        onPrimary: textOnPrimary,
        primaryContainer: primaryLight,
        secondary: secondary,
        onSecondary: textOnSecondary,
        secondaryContainer: secondaryLight,
        surface: surface,
        onSurface: textPrimary,
        error: error,
        onError: textOnPrimary,
        outline: border,
        shadow: shadow,
      );

  static ColorScheme get darkColorScheme => const ColorScheme.dark(
        primary: primaryLight,
        onPrimary: Color(0xFF002D6E),
        primaryContainer: primaryDark,
        secondary: secondaryLight,
        onSecondary: Color(0xFF003919),
        secondaryContainer: secondaryDark,
        surface: darkSurface,
        onSurface: darkTextPrimary,
        error: Color(0xFFFF8A80),
        onError: Color(0xFF690005),
        outline: darkBorder,
        shadow: Color(0x40000000),
      );
}
