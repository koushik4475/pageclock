import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppThemeId {
  defaultDark,
  defaultLight,
  special1,
}

extension AppThemeIdExtension on AppThemeId {
  String get displayName {
    switch (this) {
      case AppThemeId.defaultDark:
        return 'Default Dark';
      case AppThemeId.defaultLight:
        return 'Default Light';
      case AppThemeId.special1:
        return 'special1 (Pastel Waves & Cream)';
    }
  }

  String get description {
    switch (this) {
      case AppThemeId.defaultDark:
        return 'Sleek Vercel & Apple deep obsidian aesthetic';
      case AppThemeId.defaultLight:
        return 'Clean minimalist light layout';
      case AppThemeId.special1:
        return 'Warm cream, soft rose ring, butter yellow & sky blue waves';
    }
  }
}

import '../settings/app_settings.dart';

/// Global theme selection provider backed directly by persisted settings
final appThemeIdProvider = Provider<AppThemeId>((ref) {
  final settings = ref.watch(settingsProvider);
  switch (settings.themeId) {
    case 'default_light':
      return AppThemeId.defaultLight;
    case 'special1':
      return AppThemeId.special1;
    case 'default_dark':
    default:
      return AppThemeId.defaultDark;
  }
});

/// Derived ThemeMode from the selected theme
final themeModeProvider = Provider<ThemeMode>((ref) {
  final themeId = ref.watch(appThemeIdProvider);
  switch (themeId) {
    case AppThemeId.defaultLight:
    case AppThemeId.special1:
      return ThemeMode.light;
    case AppThemeId.defaultDark:
      return ThemeMode.dark;
  }
});

/// Palette for the special1 theme as shown in the reference image
class Special1Palette {
  static const Color background = Color(0xFFFFF8F3);
  static const Color cardBackground = Colors.white;
  static const Color primaryText = Color(0xFF40223A);
  static const Color secondaryText = Color(0xFF785D72);
  static const Color accentRose = Color(0xFFF9A8BD);
  static const Color accentRoseDark = Color(0xFFE88A9E);
  static const Color ringTrack = Color(0xFFFDE8EF);
  static const Color soundButton = Color(0xFFBAE6FD);
  static const Color waveYellow = Color(0xFFFDE68A);
  static const Color waveBlue = Color(0xFFBAE6FD);
  static const Color inputBorder = Color(0xFFEEDCDE);
  static const Color activePill = Color(0xFFFBCFE8);
  static const Color stopButton = Color(0xFFF9A8BD);
}

/// Custom painter for the organic pastel waves in the special1 theme
class Special1WavesPainter extends CustomPainter {
  const Special1WavesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Layer 1: Pastel Butter Yellow Wave (upper wave)
    final yellowPaint = Paint()
      ..color = Special1Palette.waveYellow.withOpacity(0.9)
      ..style = PaintingStyle.fill;

    final yellowPath = Path();
    yellowPath.moveTo(0, h * 0.45);
    yellowPath.quadraticBezierTo(
      w * 0.25, h * 0.20,
      w * 0.55, h * 0.50,
    );
    yellowPath.quadraticBezierTo(
      w * 0.80, h * 0.75,
      w, h * 0.60,
    );
    yellowPath.lineTo(w, h);
    yellowPath.lineTo(0, h);
    yellowPath.close();
    canvas.drawPath(yellowPath, yellowPaint);

    // Layer 2: Pastel Sky Blue Wave (lower wave)
    final bluePaint = Paint()
      ..color = Special1Palette.waveBlue.withOpacity(0.95)
      ..style = PaintingStyle.fill;

    final bluePath = Path();
    bluePath.moveTo(0, h * 0.70);
    bluePath.quadraticBezierTo(
      w * 0.35, h * 0.55,
      w * 0.65, h * 0.82,
    );
    bluePath.quadraticBezierTo(
      w * 0.85, h * 0.95,
      w, h * 0.88,
    );
    bluePath.lineTo(w, h);
    bluePath.lineTo(0, h);
    bluePath.close();
    canvas.drawPath(bluePath, bluePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
