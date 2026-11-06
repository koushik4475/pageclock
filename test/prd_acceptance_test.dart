import 'package:flutter_test/flutter_test.dart';
import 'package:pageclock/core/models/reading_session.dart';
import 'package:pageclock/core/repository/session_repository.dart';
import 'package:pageclock/core/services/export_service.dart';

void main() {
  group('PRD §13 Acceptance Criteria Tests', () {
    test('AC-1 & AC-2: Timestamp timing survives app kill and pause intervals', () {
      final start = DateTime(2026, 11, 6, 10, 0, 0).millisecondsSinceEpoch;
      // Simulated app background/kill for 30 mins, with 5 mins pause
      final session = ReadingSession(
        id: 'test-kill-survival',
        startedAtUtc: start,
        pausedTotalMs: 5 * 60 * 1000,
        tzOffsetMin: 0,
        createdAt: start,
        updatedAt: start,
      );

      final nowAfter30Mins = start + (30 * 60 * 1000);
      final elapsed = session.calculateCurrentDurationMs(nowAfter30Mins);

      // 30 min elapsed - 5 min pause = 25 min net (1,500,000 ms)
      expect(elapsed, equals(25 * 60 * 1000));
    });

    test('AC-8: CSV Export contains every session and re-imports without loss', () {
      final original = [
        ReadingSession(
          id: 'session-1',
          startedAtUtc: 1700000000000,
          endedAtUtc: 1700003600000,
          pausedTotalMs: 60000,
          durationMs: 3540000,
          tzOffsetMin: 330,
          subjectId: 'book-1',
          note: 'Deep focus reading',
          source: 'timer',
          deviceId: 'local',
          createdAt: 1700000000000,
          updatedAt: 1700003600000,
        ),
      ];

      final csv = SessionExportService.exportToCsv(original);
      final imported = SessionExportService.importFromCsv(csv);

      expect(imported.length, equals(1));
      expect(imported.first.id, equals(original.first.id));
      expect(imported.first.startedAtUtc, equals(original.first.startedAtUtc));
      expect(imported.first.durationMs, equals(original.first.durationMs));
      expect(imported.first.note, equals(original.first.note));
    });
  });
}
