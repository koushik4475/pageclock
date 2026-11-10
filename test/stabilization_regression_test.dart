import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pageclock/core/models/reading_session.dart';
import 'package:pageclock/core/repository/session_repository.dart';
import 'package:pageclock/core/services/export_service.dart';
import 'package:pageclock/core/settings/app_settings.dart';
import 'package:pageclock/core/theme/theme_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 8 Comprehensive Stabilization Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('1. Settings round-trip: modifications persist across ProviderContainers', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container1 = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );

      // Mutate settings in container 1
      await container1.read(settingsProvider.notifier).update(
            (s) => s.copyWith(
              themeId: 'special1',
              dailyGoalMinutes: 45,
              streakThresholdMinutes: 15,
              pomodoroFocusMinutes: 50,
            ),
          );

      expect(container1.read(settingsProvider).themeId, 'special1');
      expect(container1.read(appThemeIdProvider), AppThemeId.special1);
      expect(container1.read(settingsProvider).dailyGoalMinutes, 45);
      container1.dispose();

      // Create new fresh container with same prefs instance
      final container2 = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );

      expect(container2.read(settingsProvider).themeId, 'special1');
      expect(container2.read(appThemeIdProvider), AppThemeId.special1);
      expect(container2.read(settingsProvider).dailyGoalMinutes, 45);
      expect(container2.read(settingsProvider).pomodoroFocusMinutes, 50);
      container2.dispose();
    });

    test('2. Repository starts clean and empty with zero sample data', () async {
      final repo = InMemorySessionRepository([]);
      final all = await repo.getAllSessions();
      expect(all, isEmpty);

      final active = await repo.getActiveSession();
      expect(active, isNull);
    });

    test('3. Export/Import JSON v2 format with duplicate skipping', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final session1 = ReadingSession(
        id: 'session-uuid-1',
        startedAtUtc: now - 3600000,
        endedAtUtc: now,
        durationMs: 3600000,
        tzOffsetMin: 0,
        subjectId: 'General Focus',
        createdAt: now,
        updatedAt: now,
      );

      final settingsMap = {
        'themeId': 'special1',
        'dailyGoalMinutes': 60,
      };

      final jsonV2 = SessionExportService.exportJsonBackupV2(
        sessions: [session1],
        settings: settingsMap,
      );

      final parsed = SessionExportService.parseBackup(jsonV2);
      expect(parsed.isValid, isTrue);
      expect(parsed.schema, 2);
      expect(parsed.sessions.length, 1);
      expect(parsed.sessions.first.id, 'session-uuid-1');
      expect(parsed.settings?['themeId'], 'special1');

      // Test duplicate merging logic
      final repo = InMemorySessionRepository([session1]);
      final existingSessions = await repo.getAllSessions();
      final existingIds = existingSessions.map((s) => s.id).toSet();

      int addedCount = 0;
      int duplicateCount = 0;

      for (final s in parsed.sessions) {
        if (existingIds.contains(s.id)) {
          duplicateCount++;
        } else {
          await repo.saveSession(s);
          addedCount++;
        }
      }

      expect(duplicateCount, 1);
      expect(addedCount, 0);
    });

    test('4. Malformed JSON import returns invalid result without crashing', () {
      const malformed = '{"schema": 2, "sessions": [invalid json...}';
      final parsed = SessionExportService.parseBackup(malformed);
      expect(parsed.isValid, isFalse);
      expect(parsed.errorMessage, isNotNull);
      expect(parsed.sessions, isEmpty);
    });

    test('5. Hard delete wipes all sessions and active session returns null', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final session = ReadingSession(
        id: 'session-test-wipe',
        startedAtUtc: now,
        tzOffsetMin: 0,
        createdAt: now,
        updatedAt: now,
      );

      final repo = InMemorySessionRepository([session]);
      expect((await repo.getAllSessions()).length, 1);

      await repo.hardDeleteAll();
      expect((await repo.getAllSessions()), isEmpty);
      expect((await repo.getActiveSession()), isNull);
    });
  });
}
