import 'dart:convert';
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

    test('CSV export and import preserve a currently paused session', () {
      final pausedAt = 1700176400000;
      final pausedSession = ReadingSession(
        id: 'session-paused',
        startedAtUtc: 1700172800000,
        pausedAtUtc: pausedAt,
        pausedTotalMs: 5 * 60 * 1000,
        durationMs: 0,
        tzOffsetMin: 330,
        subjectId: 'sub-deep-work',
        note: 'Chapter 5',
        source: 'timer',
        deviceId: 'pixel-8',
        createdAt: 1700172800000,
        updatedAt: pausedAt,
      );

      final csv = SessionExportService.exportToCsv([pausedSession]);
      final imported = SessionExportService.importFromCsv(csv);

      expect(imported, hasLength(1));
      expect(imported.single.pausedAtUtc, equals(pausedAt));
      expect(imported.single.pausedTotalMs, equals(pausedSession.pausedTotalMs));
      expect(imported.single.isPaused, isTrue);
      expect(
        imported.single.calculateCurrentDurationMs(pausedAt + 60 * 60 * 1000),
        equals(pausedAt - pausedSession.startedAtUtc - pausedSession.pausedTotalMs),
      );
    });

    test('CSV importer remains compatible with legacy 12-column exports', () {
      const legacyCsv = 'id,started_at_utc,ended_at_utc,paused_total_ms,duration_ms,tz_offset_min,subject_id,note,source,device_id,created_at,updated_at\r\n'
          'legacy-session,1700000000000,1700001800000,0,1800000,330,,,,local,1700000000000,1700001800000';

      final imported = SessionExportService.importFromCsv(legacyCsv);

      expect(imported, hasLength(1));
      expect(imported.single.id, equals('legacy-session'));
      expect(imported.single.endedAtUtc, equals(1700001800000));
      expect(imported.single.pausedAtUtc, isNull);
      expect(imported.single.durationMs, equals(1800000));
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

    test('CSV and JSON roundtrips preserve completed pause intervals', () {
      final start = 1700200000000;
      final session = ReadingSession(
        id: 'pause-roundtrip',
        startedAtUtc: start,
        endedAtUtc: start + 90 * 60000,
        pausedTotalMs: 30 * 60000,
        durationMs: 60 * 60000,
        tzOffsetMin: 330,
        pauseIntervals: [
          PauseInterval(
            startedAtUtc: start + 15 * 60000,
            endedAtUtc: start + 45 * 60000,
          ),
        ],
        createdAt: start,
        updatedAt: start + 90 * 60000,
      );

      final csvImported =
          SessionExportService.importFromCsv(SessionExportService.exportToCsv([session]));
      expect(csvImported.single.pauseIntervals, hasLength(1));
      expect(csvImported.single.pauseIntervals.single.startedAtUtc, start + 15 * 60000);
      expect(csvImported.single.pauseIntervals.single.endedAtUtc, start + 45 * 60000);

      final jsonImported =
          SessionExportService.importFromJson(SessionExportService.exportToJson([session]));
      expect(jsonImported.single.pauseIntervals, hasLength(1));
      expect(jsonImported.single.activeDurationMs(), 60 * 60000);
    });

    test('legacy JSON backups without pause intervals remain compatible', () {
      final start = 1700300000000;
      final legacy = {
        'id': 'legacy-json',
        'started_at_utc': start,
        'ended_at_utc': start + 60 * 60000,
        'paused_total_ms': 15 * 60000,
        'duration_ms': 45 * 60000,
        'tz_offset_min': 0,
        'created_at': start,
        'updated_at': start + 60 * 60000,
      };

      final imported = SessionExportService.importFromJson('[${jsonEncode(legacy)}]');
      expect(imported.single.pauseIntervals, isEmpty);
      expect(imported.single.activeDurationMs(), 45 * 60000);
    });
  });
}
