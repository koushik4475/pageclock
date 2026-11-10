import 'package:flutter_test/flutter_test.dart';
import 'package:pageclock/core/models/reading_session.dart';
import 'package:pageclock/core/services/export_service.dart';

void main() {
  group('Export/Import Roundtrip Tests (PRD Acceptance #8)', () {
    final sampleSessions = [
      ReadingSession(
        id: 'session-1',
        startedAtUtc: 1700000000000,
        endedAtUtc: 1700001800000,
        durationMs: 1800000,
        tzOffsetMin: 330,
        subjectId: 'sub-deep-work',
        note: 'Chapter 4',
        source: 'timer',
        deviceId: 'pixel-8',
        createdAt: 1700000000000,
        updatedAt: 1700001800000,
      ),
      ReadingSession(
        id: 'session-2',
        startedAtUtc: 1700086400000,
        endedAtUtc: 1700090000000,
        durationMs: 3600000,
        tzOffsetMin: 330,
        subjectId: null,
        note: null,
        source: 'manual',
        deviceId: 'macbook',
        createdAt: 1700086400000,
        updatedAt: 1700090000000,
      ),
    ];

    test('CSV Export and Import roundtrip preserves all fields', () {
      final csv = SessionExportService.exportToCsv(sampleSessions);
      final imported = SessionExportService.importFromCsv(csv);

      expect(imported.length, equals(2));
      expect(imported[0].id, equals(sampleSessions[0].id));
      expect(imported[0].startedAtUtc, equals(sampleSessions[0].startedAtUtc));
      expect(imported[0].durationMs, equals(sampleSessions[0].durationMs));
      expect(imported[0].tzOffsetMin, equals(sampleSessions[0].tzOffsetMin));
      expect(imported[0].subjectId, equals('sub-deep-work'));
      expect(imported[0].note, equals('Chapter 4'));
      expect(imported[0].source, equals('timer'));

      expect(imported[1].id, equals(sampleSessions[1].id));
      expect(imported[1].durationMs, equals(sampleSessions[1].durationMs));
      expect(imported[1].source, equals('manual'));
    });

    test('JSON Export and Import roundtrip preserves all fields', () {
      final json = SessionExportService.exportToJson(sampleSessions);
      final imported = SessionExportService.importFromJson(json);

      expect(imported.length, equals(2));
      expect(imported[0].id, equals(sampleSessions[0].id));
      expect(imported[0].subjectId, equals('sub-deep-work'));
      expect(imported[1].id, equals(sampleSessions[1].id));
      expect(imported[1].source, equals('manual'));
    });
  });
}
