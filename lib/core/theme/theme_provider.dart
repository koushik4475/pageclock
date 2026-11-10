import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../settings/app_settings.dart';

enum AppThemeId {
  defaultDark,
  defaultLight,
  special1,
  midnightAurora,
  oceanMist,
  lavenderHaze,
  forestGrove,
  sunsetEmber,
  roseQuartz,
  nordicFrost,
  solarCitrus,
}

extension AppThemeIdExtension on AppThemeId {
  String get storageId {
    switch (this) {
      case AppThemeId.defaultDark: return 'default_dark';
      case AppThemeId.defaultLight: return 'default_light';
      case AppThemeId.special1: return 'special1';
      case AppThemeId.midnightAurora: return 'midnight_aurora';
      case AppThemeId.oceanMist: return 'ocean_mist';
      case AppThemeId.lavenderHaze: return 'lavender_haze';
      case AppThemeId.forestGrove: return 'forest_grove';
      case AppThemeId.sunsetEmber: return 'sunset_ember';
      case AppThemeId.roseQuartz: return 'rose_quartz';
      case AppThemeId.nordicFrost: return 'nordic_frost';
      case AppThemeId.solarCitrus: return 'solar_citrus';
    }
  }

  String get displayName {
    switch (this) {
      case AppThemeId.defaultDark: return 'Obsidian';
      case AppThemeId.defaultLight: return 'Porcelain';
      case AppThemeId.special1: return 'Pastel Waves';
      case AppThemeId.midnightAurora: return 'Midnight Aurora';
      case AppThemeId.oceanMist: return 'Ocean Mist';
      case AppThemeId.lavenderHaze: return 'Lavender Haze';
      case AppThemeId.forestGrove: return 'Forest Grove';
      case AppThemeId.sunsetEmber: return 'Sunset Ember';
      case AppThemeId.roseQuartz: return 'Rose Quartz';
      case AppThemeId.nordicFrost: return 'Nordic Frost';
      case AppThemeId.solarCitrus: return 'Solar Citrus';
    }
  }

  String get description {
    switch (this) {
      case AppThemeId.defaultDark: return 'Quiet obsidian with a vivid indigo glow';
      case AppThemeId.defaultLight: return 'Crisp white surfaces and refined slate';
      case AppThemeId.special1: return 'Cream, rose, butter yellow and sky blue';
      case AppThemeId.midnightAurora: return 'Deep teal with luminous mint and ice';
      case AppThemeId.oceanMist: return 'Breezy coastal blue with sea-glass accents';
      case AppThemeId.lavenderHaze: return 'Soft lilac surfaces with a rich violet accent';
      case AppThemeId.forestGrove: return 'A calm woodland palette with fresh sage';
      case AppThemeId.sunsetEmber: return 'Warm ember, coral and berry on plum';
      case AppThemeId.roseQuartz: return 'Blush surfaces with elegant rose accents';
      case AppThemeId.nordicFrost: return 'Cool porcelain, fjord blue and soft lilac';
      case AppThemeId.solarCitrus: return 'Warm ivory with golden citrus highlights';
    }
  }

  ThemePalette get palette => themePalettes[this]!;

  static AppThemeId fromStorage(String? value) {
    for (final id in AppThemeId.values) {
      // Accept the original enum names as well as stable storage IDs.
      if (id.storageId == value || id.name == value) return id;
    }
    return AppThemeId.defaultDark;
  }
}

class ThemePalette {
  final Color background;
  final Color surface;
  final Color primary;
  final Color onPrimary;
  final Color secondary;
  final Color tertiary;
  final Color text;
  final Color textMuted;
  final Color outline;
  final Color ringTrack;
  final bool isDark;
  final List<Color> previewColors;

  const ThemePalette({
    required this.background,
    required this.surface,
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.tertiary,
    required this.text,
    required this.textMuted,
    required this.outline,
    required this.ringTrack,
    required this.isDark,
    required this.previewColors,
  });
}

const Map<AppThemeId, ThemePalette> themePalettes = {
  AppThemeId.defaultDark: ThemePalette(
    background: Color(0xFF09090F),
    surface: Color(0xFF15151F),
    primary: Color(0xFF796BFF),
    onPrimary: Color(0xFF100D32),
    secondary: Color(0xFF38BDF8),
    tertiary: Color(0xFF34D399),
    text: Color(0xFFF7F7FC),
    textMuted: Color(0xFFA6A6B8),
    outline: Color(0xFF303041),
    ringTrack: Color(0xFF29263F),
    isDark: true,
    previewColors: [Color(0xFF09090F), Color(0xFF796BFF), Color(0xFF38BDF8), Color(0xFF34D399)],
  ),
  AppThemeId.defaultLight: ThemePalette(
    background: Color(0xFFF7F8FC),
    surface: Colors.white,
    primary: Color(0xFF4F46C8),
    onPrimary: Colors.white,
    secondary: Color(0xFF087E9B),
    tertiary: Color(0xFFB83280),
    text: Color(0xFF171827),
    textMuted: Color(0xFF65677A),
    outline: Color(0xFFDDE0EC),
    ringTrack: Color(0xFFE8E8F5),
    isDark: false,
    previewColors: [Color(0xFFF7F8FC), Color(0xFF4F46C8), Color(0xFF087E9B), Color(0xFFB83280)],
  ),
  AppThemeId.special1: ThemePalette(
    background: Color(0xFFFFF8F3),
    surface: Colors.white,
    primary: Color(0xFFE88A9E),
    onPrimary: Color(0xFF40223A),
    secondary: Color(0xFFBAE6FD),
    tertiary: Color(0xFFFDE68A),
    text: Color(0xFF40223A),
    textMuted: Color(0xFF785D72),
    outline: Color(0xFFEEDCDE),
    ringTrack: Color(0xFFFDE8EF),
    isDark: false,
    previewColors: [Color(0xFFFFF8F3), Color(0xFFE88A9E), Color(0xFFFDE68A), Color(0xFFBAE6FD)],
  ),
  AppThemeId.midnightAurora: ThemePalette(
    background: Color(0xFF07191B),
    surface: Color(0xFF102629),
    primary: Color(0xFF6EE7B7),
    onPrimary: Color(0xFF07362D),
    secondary: Color(0xFF67E8F9),
    tertiary: Color(0xFFC4B5FD),
    text: Color(0xFFE9FFFA),
    textMuted: Color(0xFF9DBDB8),
    outline: Color(0xFF29474A),
    ringTrack: Color(0xFF1C4644),
    isDark: true,
    previewColors: [Color(0xFF07191B), Color(0xFF6EE7B7), Color(0xFF67E8F9), Color(0xFFC4B5FD)],
  ),
  AppThemeId.oceanMist: ThemePalette(
    background: Color(0xFFEFF8FB),
    surface: Colors.white,
    primary: Color(0xFF0E7490),
    onPrimary: Colors.white,
    secondary: Color(0xFF38A9D6),
    tertiary: Color(0xFF0F9D8A),
    text: Color(0xFF123044),
    textMuted: Color(0xFF587789),
    outline: Color(0xFFCDE4EC),
    ringTrack: Color(0xFFD9EEF4),
    isDark: false,
    previewColors: [Color(0xFFEFF8FB), Color(0xFF0E7490), Color(0xFF38A9D6), Color(0xFF0F9D8A)],
  ),
  AppThemeId.lavenderHaze: ThemePalette(
    background: Color(0xFFF6F2FF),
    surface: Colors.white,
    primary: Color(0xFF6546A5),
    onPrimary: Colors.white,
    secondary: Color(0xFF9875D6),
    tertiary: Color(0xFFD66F9A),
    text: Color(0xFF2B2140),
    textMuted: Color(0xFF75698C),
    outline: Color(0xFFE4DAF4),
    ringTrack: Color(0xFFECE4FA),
    isDark: false,
    previewColors: [Color(0xFFF6F2FF), Color(0xFF6546A5), Color(0xFF9875D6), Color(0xFFD66F9A)],
  ),
  AppThemeId.forestGrove: ThemePalette(
    background: Color(0xFF101A14),
    surface: Color(0xFF1A2A20),
    primary: Color(0xFF9ACD78),
    onPrimary: Color(0xFF1A321B),
    secondary: Color(0xFFD2B48C),
    tertiary: Color(0xFF65C5B5),
    text: Color(0xFFF0F7EE),
    textMuted: Color(0xFFACBDA9),
    outline: Color(0xFF354B39),
    ringTrack: Color(0xFF2B4030),
    isDark: true,
    previewColors: [Color(0xFF101A14), Color(0xFF9ACD78), Color(0xFFD2B48C), Color(0xFF65C5B5)],
  ),
  AppThemeId.sunsetEmber: ThemePalette(
    background: Color(0xFF1B121E),
    surface: Color(0xFF2A1D30),
    primary: Color(0xFFFF9B73),
    onPrimary: Color(0xFF421E22),
    secondary: Color(0xFFF472B6),
    tertiary: Color(0xFFFBBF24),
    text: Color(0xFFFFF2EC),
    textMuted: Color(0xFFC8AEBF),
    outline: Color(0xFF50374F),
    ringTrack: Color(0xFF493045),
    isDark: true,
    previewColors: [Color(0xFF1B121E), Color(0xFFFF9B73), Color(0xFFF472B6), Color(0xFFFBBF24)],
  ),
  AppThemeId.roseQuartz: ThemePalette(
    background: Color(0xFFFFF4F6),
    surface: Colors.white,
    primary: Color(0xFFB93B6A),
    onPrimary: Colors.white,
    secondary: Color(0xFFE88DAB),
    tertiary: Color(0xFF8273B7),
    text: Color(0xFF3D2030),
    textMuted: Color(0xFF886B79),
    outline: Color(0xFFF0D2DD),
    ringTrack: Color(0xFFF8E1E9),
    isDark: false,
    previewColors: [Color(0xFFFFF4F6), Color(0xFFB93B6A), Color(0xFFE88DAB), Color(0xFF8273B7)],
  ),
  AppThemeId.nordicFrost: ThemePalette(
    background: Color(0xFFF1F5F9),
    surface: Colors.white,
    primary: Color(0xFF355C7D),
    onPrimary: Colors.white,
    secondary: Color(0xFF5E91A6),
    tertiary: Color(0xFF8A7DB7),
    text: Color(0xFF1B2B3B),
    textMuted: Color(0xFF637789),
    outline: Color(0xFFD6E1EA),
    ringTrack: Color(0xFFE1EAF1),
    isDark: false,
    previewColors: [Color(0xFFF1F5F9), Color(0xFF355C7D), Color(0xFF5E91A6), Color(0xFF8A7DB7)],
  ),
  AppThemeId.solarCitrus: ThemePalette(
    background: Color(0xFFFFFAE8),
    surface: Colors.white,
    primary: Color(0xFF855300),
    onPrimary: Colors.white,
    secondary: Color(0xFFD97706),
    tertiary: Color(0xFF659A2D),
    text: Color(0xFF33250D),
    textMuted: Color(0xFF7E6B4B),
    outline: Color(0xFFF0E1B5),
    ringTrack: Color(0xFFF5EAC9),
    isDark: false,
    previewColors: [Color(0xFFFFFAE8), Color(0xFF855300), Color(0xFFD97706), Color(0xFF659A2D)],
  ),
};

final appThemeIdProvider = Provider<AppThemeId>((ref) {
  final settings = ref.watch(settingsProvider);
  return AppThemeIdExtension.fromStorage(settings.themeId);
});

final themeModeProvider = Provider<ThemeMode>((ref) {
  final themeId = ref.watch(appThemeIdProvider);
  return themeId.palette.isDark ? ThemeMode.dark : ThemeMode.light;
});

ThemeData appThemeDataFor(AppThemeId id) {
  final palette = id.palette;
  final scheme = palette.isDark
      ? ColorScheme.dark(
          primary: palette.primary,
          onPrimary: palette.onPrimary,
          secondary: palette.secondary,
          onSecondary: palette.isDark ? const Color(0xFF10242A) : Colors.white,
          tertiary: palette.tertiary,
          onTertiary: palette.isDark ? const Color(0xFF1B2030) : Colors.white,
          surface: palette.surface,
          onSurface: palette.text,
          onSurfaceVariant: palette.textMuted,
          outline: palette.outline,
          error: const Color(0xFFFF6B6B),
          onError: const Color(0xFF2B1010),
        )
      : ColorScheme.light(
          primary: palette.primary,
          onPrimary: palette.onPrimary,
          secondary: palette.secondary,
          onSecondary: Colors.white,
          tertiary: palette.tertiary,
          onTertiary: Colors.white,
          surface: palette.surface,
          onSurface: palette.text,
          onSurfaceVariant: palette.textMuted,
          outline: palette.outline,
          error: const Color(0xFFB42318),
          onError: Colors.white,
        );

  return ThemeData(
    useMaterial3: true,
    brightness: palette.isDark ? Brightness.dark : Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: palette.background,
    canvasColor: palette.background,
    cardColor: palette.surface,
    dividerColor: palette.outline.withOpacity(0.65),
    appBarTheme: AppBarTheme(
      backgroundColor: palette.background,
      foregroundColor: palette.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: palette.text,
        fontSize: 21,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: palette.surface,
      selectedItemColor: palette.primary,
      unselectedItemColor: palette.textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surface,
      hintStyle: TextStyle(color: palette.textMuted),
      labelStyle: TextStyle(color: palette.textMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: palette.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: palette.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: palette.primary, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: palette.primary,
        foregroundColor: palette.onPrimary,
        minimumSize: const Size(44, 46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: palette.surface,
      contentTextStyle: TextStyle(color: palette.text),
      behavior: SnackBarBehavior.floating,
    ),
    fontFamily: 'Inter',
  );
}

/// Palette for the signature cream-and-pastel wave theme.
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

/// Signature organic waves used by the Pastel Waves theme.
class Special1WavesPainter extends CustomPainter {
  const Special1WavesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final yellowPaint = Paint()
      ..color = Special1Palette.waveYellow.withOpacity(0.9)
      ..style = PaintingStyle.fill;
    final yellowPath = Path()
      ..moveTo(0, h * 0.45)
      ..quadraticBezierTo(w * 0.25, h * 0.20, w * 0.55, h * 0.50)
      ..quadraticBezierTo(w * 0.80, h * 0.75, w, h * 0.60)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(yellowPath, yellowPaint);

    final bluePaint = Paint()
      ..color = Special1Palette.waveBlue.withOpacity(0.95)
      ..style = PaintingStyle.fill;
    final bluePath = Path()
      ..moveTo(0, h * 0.70)
      ..quadraticBezierTo(w * 0.35, h * 0.55, w * 0.65, h * 0.82)
      ..quadraticBezierTo(w * 0.85, h * 0.95, w, h * 0.88)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(bluePath, bluePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
