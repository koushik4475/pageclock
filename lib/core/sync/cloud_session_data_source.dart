import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/reading_session.dart';

/// Single item returned from a cloud pull query, preserving its `server_seq`.
class CloudSessionRow {
  final ReadingSession session;
  final int serverSeq;

  const CloudSessionRow({
    required this.session,
    required this.serverSeq,
  });
}

/// Structured response from pulling a batch of sessions from cloud.
class CloudPullResponse {
  final List<CloudSessionRow> rows;
  final int maxServerSeq;

  const CloudPullResponse({
    required this.rows,
    required this.maxServerSeq,
  });
}

/// Abstract contract for syncing reading sessions with Supabase PostgREST.
///
/// Interface allows clean unit testing without live network connections.
abstract class CloudSessionDataSource {
  /// Pulls sessions committed on or after [afterServerSeq] up to [limit] rows.
  Future<CloudPullResponse> pullSessions({
    required String userId,
    required int afterServerSeq,
    int limit = 500,
  });

  /// Pushes a batch of sessions using `upsert` with composite PK `(user_id, id)`.
  Future<void> pushBatch({
    required String userId,
    required List<ReadingSession> sessions,
  });

  /// Pushes a single session row (used when dissecting a poisoned batch).
  Future<void> pushSingle({
    required String userId,
    required ReadingSession session,
  });
}

/// Production implementation of [CloudSessionDataSource] backed by `supabase_flutter`.
class SupabaseSessionDataSource implements CloudSessionDataSource {
  final SupabaseClient _client;

  SupabaseSessionDataSource(this._client);

  static const String tableName = 'reading_sessions';

  @override
  Future<CloudPullResponse> pullSessions({
    required String userId,
    required int afterServerSeq,
    int limit = 500,
  }) async {
    final response = await _client
        .from(tableName)
        .select('*')
        .eq('user_id', userId)
        .gt('server_seq', afterServerSeq)
        .order('server_seq', ascending: true)
        .limit(limit);

    final rawList = response as List<dynamic>;
    final rows = <CloudSessionRow>[];
    int maxSeq = afterServerSeq;

    for (final raw in rawList) {
      final map = Map<String, dynamic>.from(raw as Map);
      final seq = (map['server_seq'] as num).toInt();
      if (seq > maxSeq) {
        maxSeq = seq;
      }
      final session = sessionFromCloudRow(map);
      rows.add(CloudSessionRow(session: session, serverSeq: seq));
    }

    return CloudPullResponse(rows: rows, maxServerSeq: maxSeq);
  }

  @override
  Future<void> pushBatch({
    required String userId,
    required List<ReadingSession> sessions,
  }) async {
    if (sessions.isEmpty) return;

    final rows = sessions
        .map((s) => sessionToCloudRow(userId: userId, session: s))
        .toList();

    await _client.from(tableName).upsert(
          rows,
          onConflict: 'user_id,id',
        );
  }

  @override
  Future<void> pushSingle({
    required String userId,
    required ReadingSession session,
  }) async {
    final row = sessionToCloudRow(userId: userId, session: session);
    await _client.from(tableName).upsert(
          row,
          onConflict: 'user_id,id',
        );
  }

  /// Transforms a local [ReadingSession] into a PostgREST database row.
  static Map<String, dynamic> sessionToCloudRow({
    required String userId,
    required ReadingSession session,
  }) {
    assert(
      session.endedAtUtc != null,
      'Only completed sessions may sync to cloud (rs_ended_at_utc constraint)',
    );

    return {
      'user_id': userId,
      'id': session.id,
      'started_at_utc': session.startedAtUtc,
      'ended_at_utc': session.endedAtUtc!,
      'paused_total_ms': session.pausedTotalMs,
      'pause_intervals':
          session.pauseIntervals.map((interval) => interval.toMap()).toList(),
      'duration_ms': session.durationMs,
      'tz_offset_min': session.tzOffsetMin,
      'subject_id': session.subjectId,
      // Cloud database trigger nulls note on soft-deleted rows
      'note': session.deletedAt != null ? null : session.note,
      'source': session.source,
      'device_id': session.deviceId,
      'created_at_ms': session.createdAt,
      'updated_at_ms': session.updatedAt,
      'deleted_at_ms': session.deletedAt,
    };
  }

  /// Transforms a PostgREST database row into a local [ReadingSession].
  static ReadingSession sessionFromCloudRow(Map<String, dynamic> map) {
    final rawPauseIntervals = map['pause_intervals'];
    final intervals = <PauseInterval>[];
    if (rawPauseIntervals is List) {
      for (final item in rawPauseIntervals) {
        if (item is Map) {
          try {
            intervals.add(
              PauseInterval.fromMap(Map<String, dynamic>.from(item)),
            );
          } catch (_) {}
        }
      }
    }

    return ReadingSession(
      id: map['id'] as String,
      startedAtUtc: (map['started_at_utc'] as num).toInt(),
      endedAtUtc: (map['ended_at_utc'] as num).toInt(),
      pausedAtUtc: null, // Completed rows always have null pausedAtUtc
      pausedTotalMs: (map['paused_total_ms'] as num?)?.toInt() ?? 0,
      durationMs: (map['duration_ms'] as num?)?.toInt() ?? 0,
      tzOffsetMin: (map['tz_offset_min'] as num?)?.toInt() ?? 0,
      subjectId: map['subject_id'] as String?,
      note: map['note'] as String?,
      source: map['source'] as String? ?? 'timer',
      deviceId: map['device_id'] as String? ?? 'local',
      createdAt: (map['created_at_ms'] as num).toInt(),
      updatedAt: (map['updated_at_ms'] as num).toInt(),
      deletedAt: (map['deleted_at_ms'] as num?)?.toInt(),
      pauseIntervals: intervals,
    );
  }
}
