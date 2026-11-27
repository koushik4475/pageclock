import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/features/admin/admin_dashboard_screen.dart';
import '../lib/features/admin/admin_service.dart';

void main() {
  for (final width in [320.0, 768.0, 1280.0]) {
    testWidgets('Dashboard navigation and metrics fit at width $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(ProviderScope(
        overrides: [
          adminDashboardProvider.overrideWith((ref) async => AdminDashboardData.fromJson({
            'summary': <String, dynamic>{},
            'clients': [],
            'dailyFocus': [],
          })),
        ],
        child: const MaterialApp(home: AdminDashboardScreen()),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Community overview'), findsOneWidget);
      expect(find.text('Total clients'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.descendant(
        of: width < 600 ? find.byType(NavigationBar) : find.byType(NavigationRail),
        matching: find.byIcon(Icons.people_alt_outlined),
      ).first);
      await tester.pumpAndSettle();
      expect(find.text('Client directory'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
