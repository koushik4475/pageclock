import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pageclock/core/repository/session_repository.dart';
import 'package:pageclock/core/settings/app_settings.dart';
import 'package:pageclock/core/theme/theme_provider.dart';
import 'package:pageclock/features/dashboard/pageclock_dashboard_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('PageClock dashboard fits phone tablet and desktop in both brand themes', (tester) async {
    final sizes = <Size>[
      const Size(360, 800),
      const Size(390, 844),
      const Size(768, 1024),
      const Size(1024, 768),
      const Size(1440, 900),
    ];
    final repository = InMemorySessionRepository([]);
    final preferences = await SharedPreferences.getInstance();

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final themeId in ['pageclock_classic', 'default_dark']) {
      await preferences.setString(
        'pageclock_app_settings_v1',
        jsonEncode(AppSettings(themeId: themeId).toJson()),
      );
      final appTheme = appThemeDataFor(AppThemeIdExtension.fromStorage(themeId));

      for (final size in sizes) {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(preferences),
              sessionRepositoryProvider.overrideWithValue(repository),
            ],
            child: MaterialApp(
              theme: appTheme,
              home: PageClockDashboardScreen(
                sessions: const [],
                onOpenTimer: () {},
                onNavigate: (_) {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('This week'), findsOneWidget);
        expect(find.text('Recent sessions'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: '$themeId dashboard overflowed at $size');
      }
    }
  });
}
