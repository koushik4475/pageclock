import 'dart:convert';
import 'package:csv/csv.dart';
import '../models/reading_session.dart';

class SessionExportService {
  static String exportToCsv(List<ReadingSession> sessions) {
    final List<List<dynamic>> rows = [
      [
        'id',
        'started_at_utc',
        'ended_at_utc',
        'paused_total_ms',
        'duration_ms',
        'tz_offset_min',
        'subject_id',
        'note',
        'source',
        'device_id',
        'created_at',
        'updated_at',
      ]
    ];

    for (final s in sessions) {
      if (s.deletedAt != null) continue;
      rows.add([
        s.id,
        s.startedAtUtc,
        s.endedAtUtc ?? '',
        s.pausedTotalMs,
        s.durationMs,
        s.tzOffsetMin,
        s.subjectId ?? '',
        s.note ?? '',
        s.source,
        s.deviceId,
        s.createdAt,
        s.updatedAt,
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  static List<ReadingSession> importFromCsv(String csvData) {
    final rows = const CsvToListConverter().convert(csvData);
    if (rows.length <= 1) return [];

    final result = <ReadingSession>[];
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < 12) continue;

      result.add(
        ReadingSession(
          id: row[0].toString(),
          startedAtUtc: int.parse(row[1].toString()),
          endedAtUtc: row[2].toString().isEmpty ? null : int.tryParse(row[2].toString()),
          pausedTotalMs: int.tryParse(row[3].toString()) ?? 0,
          durationMs: int.tryParse(row[4].toString()) ?? 0,
          tzOffsetMin: int.tryParse(row[5].toString()) ?? 0,
          subjectId: row[6].toString().isEmpty ? null : row[6].toString(),
          note: row[7].toString().isEmpty ? null : row[7].toString(),
          source: row[8].toString().isEmpty ? 'timer' : row[8].toString(),
          deviceId: row[9].toString().isEmpty ? 'local' : row[9].toString(),
          createdAt: int.tryParse(row[10].toString()) ?? DateTime.now().millisecondsSinceEpoch,
          updatedAt: int.tryParse(row[11].toString()) ?? DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }
    return result;
  }

  static String exportJsonBackupV2({
    required List<ReadingSession> sessions,
    required Map<String, dynamic> settings,
    List<Map<String, dynamic>> subjects = const [],
    String appVersion = '1.0.0',
  }) {
    final activeSessions = sessions.where((s) => s.deletedAt == null).map((s) => s.toMap()).toList();
    final backup = {
      'schema': 2,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'appVersion': appVersion,
      'settings': settings,
      'subjects': subjects,
      'sessions': activeSessions,
    };
    return const JsonEncoder.withIndent('  ').convert(backup);
  }

  static BackupParseResult parseBackup(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is List) {
        // Legacy v1 array format
        final sessions = decoded
            .map((item) => ReadingSession.fromMap(item as Map<String, dynamic>))
            .toList();
        return BackupParseResult(
          schema: 1,
          sessions: sessions,
          settings: null,
          subjects: [],
        );
      }

      if (decoded is Map<String, dynamic>) {
        final schema = (decoded['schema'] as num?)?.toInt() ?? 1;
        final rawSessions = (decoded['sessions'] as List<dynamic>?) ?? [];
        final sessions = rawSessions
            .map((item) => ReadingSession.fromMap(item as Map<String, dynamic>))
            .toList();
        final settings = decoded['settings'] as Map<String, dynamic>?;
        final rawSubjects = (decoded['subjects'] as List<dynamic>?) ?? [];
        final subjects = rawSubjects.cast<Map<String, dynamic>>();

        return BackupParseResult(
          schema: schema,
          sessions: sessions,
          settings: settings,
          subjects: subjects,
        );
      }

      return BackupParseResult(
        schema: 0,
        sessions: [],
        errorMessage: 'Invalid JSON backup structure.',
      );
    } catch (e) {
      return BackupParseResult(
        schema: 0,
        sessions: [],
        errorMessage: 'Malformed JSON backup file: $e',
      );
    }
  }

  static String exportToJson(List<ReadingSession> sessions) {
    final active = sessions.where((s) => s.deletedAt == null).map((s) => s.toMap()).toList();
    return jsonEncode(active);
  }

  static List<ReadingSession> importFromJson(String jsonData) {
    final parsed = parseBackup(jsonData);
    return parsed.sessions;
  }
}

class BackupParseResult {
  final int schema;
  final List<ReadingSession> sessions;
  final Map<String, dynamic>? settings;
  final List<Map<String, dynamic>> subjects;
  final String? errorMessage;

  bool get isValid => errorMessage == null;

  BackupParseResult({
    required this.schema,
    required this.sessions,
    this.settings,
    this.subjects = const [],
    this.errorMessage,
  });
}
