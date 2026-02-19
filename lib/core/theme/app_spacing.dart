import 'package:flutter/material.dart';

/// Design system spacing tokens for Compre Aqui
/// Use these instead of magic numbers throughout the app
class AppSpacing {
  AppSpacing._();

  // === Base Spacing Tokens ===
  static const double xxs = 2;
  static const double xs = 4;
  static const double s = 8;
  static const double sm = 12;
  static const double m = 16;
  static const double ml = 20;
  static const double l = 24;
  static const double xl = 32;
  static const double xxl = 40;
  static const double xxxl = 48;

  // === Common Padding Presets ===
  static const EdgeInsets paddingXS = EdgeInsets.all(xs);
  static const EdgeInsets paddingS = EdgeInsets.all(s);
  static const EdgeInsets paddingM = EdgeInsets.all(m);
  static const EdgeInsets paddingL = EdgeInsets.all(l);
  static const EdgeInsets paddingXL = EdgeInsets.all(xl);

  // === Horizontal Padding ===
  static const EdgeInsets paddingHorizontalS = EdgeInsets.symmetric(horizontal: s);
  static const EdgeInsets paddingHorizontalM = EdgeInsets.symmetric(horizontal: m);
  static const EdgeInsets paddingHorizontalL = EdgeInsets.symmetric(horizontal: l);

  // === Screen Padding (standard horizontal + vertical) ===
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(horizontal: m, vertical: s);

  // === Border Radius Tokens ===
  static const double radiusXS = 4;
  static const double radiusS = 8;
  static const double radiusM = 12;
  static const double radiusL = 16;
  static const double radiusXL = 20;
  static const double radiusXXL = 24;
  static const double radiusFull = 999;

  // === Common BorderRadius ===
  static final BorderRadius borderRadiusS = BorderRadius.circular(radiusS);
  static final BorderRadius borderRadiusM = BorderRadius.circular(radiusM);
  static final BorderRadius borderRadiusL = BorderRadius.circular(radiusL);
  static final BorderRadius borderRadiusXL = BorderRadius.circular(radiusXL);
  static final BorderRadius borderRadiusXXL = BorderRadius.circular(radiusXXL);
  static final BorderRadius borderRadiusFull = BorderRadius.circular(radiusFull);

  // === Animation Durations ===
  static const Duration animFast = Duration(milliseconds: 150);
  static const Duration animNormal = Duration(milliseconds: 200);
  static const Duration animSlow = Duration(milliseconds: 300);
  static const Duration animVerySlow = Duration(milliseconds: 400);

  // === Icon Sizes ===
  static const double iconXS = 14;
  static const double iconS = 16;
  static const double iconM = 20;
  static const double iconL = 24;
  static const double iconXL = 32;
  static const double iconXXL = 48;

  // === Avatar Sizes ===
  static const double avatarS = 32;
  static const double avatarM = 40;
  static const double avatarL = 48;
  static const double avatarXL = 56;

  // === Touch Target ===
  static const double touchTarget = 44;
}
