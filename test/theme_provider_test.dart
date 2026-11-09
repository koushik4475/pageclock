import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pageclock/core/theme/theme_provider.dart';

double _contrastRatio(Color a, Color b) {
  final luminances = [a.computeLuminance(), b.computeLuminance()]..sort();
  final darker = luminances.first;
  final lighter = luminances.last;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('PageClock theme gallery', () {
    test('offers eleven named themes, including eight new palettes', () {
      expect(AppThemeId.values, hasLength(11));
      expect(
        AppThemeId.values.map((theme) => theme.displayName).toSet(),
        hasLength(11),
      );
    });

    test('every theme round-trips through stable and legacy storage IDs', () {
      for (final theme in AppThemeId.values) {
        expect(AppThemeIdExtension.fromStorage(theme.storageId), theme);
        expect(AppThemeIdExtension.fromStorage(theme.name), theme);
      }
      expect(
        AppThemeIdExtension.fromStorage('not-a-theme'),
        AppThemeId.defaultDark,
      );
    });

    test('each theme builds a matching Material 3 color scheme', () {
      for (final themeId in AppThemeId.values) {
        final palette = themeId.palette;
        final themeData = appThemeDataFor(themeId);

        expect(themeData.useMaterial3, isTrue);
        expect(
          themeData.brightness,
          palette.isDark ? Brightness.dark : Brightness.light,
        );
        expect(themeData.scaffoldBackgroundColor, palette.background);
        expect(themeData.colorScheme.surface, palette.surface);
        expect(themeData.colorScheme.primary, palette.primary);
        expect(themeData.colorScheme.onPrimary, palette.onPrimary);
        expect(palette.previewColors, hasLength(4));
      }
    });

    test('primary and surface text pairs meet 4.5:1 contrast', () {
      for (final themeId in AppThemeId.values) {
        final scheme = appThemeDataFor(themeId).colorScheme;
        expect(
          _contrastRatio(scheme.primary, scheme.onPrimary),
          greaterThanOrEqualTo(4.5),
          reason: '${themeId.displayName} primary button contrast',
        );
        expect(
          _contrastRatio(scheme.surface, scheme.onSurface),
          greaterThanOrEqualTo(4.5),
          reason: '${themeId.displayName} surface text contrast',
        );
      }
    });
  });
}
