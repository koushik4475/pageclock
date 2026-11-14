/// A completed pause interval, stored in UTC epoch milliseconds.
class PauseInterval {
  final int startedAtUtc;
  final int endedAtUtc;

  const PauseInterval({
    required this.startedAtUtc,
    required this.endedAtUtc,
  });

  int get durationMs {
    final value = endedAtUtc - startedAtUtc;
    return value > 0 ? value : 0;
  }

  Map<String, int> toMap() => {
        'start_utc': startedAtUtc,
        'end_utc': endedAtUtc,
      };

  factory PauseInterval.fromMap(Map<String, dynamic> map) {
    final start = (map['start_utc'] as num).toInt();
    final end = (map['end_utc'] as num).toInt();
    return PauseInterval(startedAtUtc: start, endedAtUtc: end);
  }
}

/// A focused (non-paused) interval within a reading session.
class SessionTimeInterval {
  final int startUtc;
  final int endUtc;

  const SessionTimeInterval({
    required this.startUtc,
    required this.endUtc,
  });

  int get durationMs {
    final value = endUtc - startUtc;
    return value > 0 ? value : 0;
  }
}

class ReadingSession {
  final String id;
  final int startedAtUtc; // epoch ms
  final int? endedAtUtc; // null if running
  final int? pausedAtUtc; // null if running, timestamp ms if currently paused
  final int pausedTotalMs;
  final int durationMs; // denormalized active duration on stop
  final int tzOffsetMin; // user's timezone offset in minutes at start
  final String? subjectId;
  final String? note;
  final String source; // 'timer' | 'manual'
  final String deviceId;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;

  /// Completed pauses in UTC. Older backups and rows default to an empty list.
  final List<PauseInterval> pauseIntervals;

  ReadingSession({
    required this.id,
    required this.startedAtUtc,
    this.endedAtUtc,
    this.pausedAtUtc,
    this.pausedTotalMs = 0,
    this.durationMs = 0,
    required this.tzOffsetMin,
    this.subjectId,
    this.note,
    this.source = 'timer',
    this.deviceId = 'local',
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    List<PauseInterval> pauseIntervals = const [],
  }) : pauseIntervals = List.unmodifiable(pauseIntervals);

  bool get isRunning => endedAtUtc == null && pausedAtUtc == null;
  bool get isPaused => endedAtUtc == null && pausedAtUtc != null;

  DateTime get startTime => DateTime.fromMillisecondsSinceEpoch(startedAtUtc);
  DateTime? get endTime => endedAtUtc != null ? DateTime.fromMillisecondsSinceEpoch(endedAtUtc!) : null;
  String get subjectName => subjectId ?? 'General Focus';
  String? get bookTitle => note;

  int calculateCurrentDurationMs(int nowUtc) {
    if (endedAtUtc != null) {
      return durationMs;
    }
    final effectiveNow = pausedAtUtc ?? nowUtc;
    final rawElapsed = effectiveNow - startedAtUtc;
    final net = rawElapsed - pausedTotalMs;
    return net > 0 ? net : 0;
  }

  /// Returns exact focused-time intervals, excluding all completed pauses.
  ///
  /// For legacy sessions with only [pausedTotalMs], the original pause
  /// positions cannot be reconstructed. Their stored net duration is placed
  /// contiguously from the original start as a deterministic, documented
  /// fallback; the total remains correct but day/hour allocation is approximate.
  List<SessionTimeInterval> activeIntervals({int? nowUtcMs}) {
    final end = endedAtUtc ??
        pausedAtUtc ??
        nowUtcMs ??
        DateTime.now().toUtc().millisecondsSinceEpoch;
    if (end <= startedAtUtc) return const [];

    if (pauseIntervals.isEmpty && pausedTotalMs > 0) {
      final rawActiveMs = endedAtUtc != null
          ? (durationMs > 0
              ? durationMs
              : end - startedAtUtc - pausedTotalMs)
          : calculateCurrentDurationMs(end);
      final activeMs = rawActiveMs > 0 ? rawActiveMs : 0;
      final candidateEnd = startedAtUtc + activeMs;
      final fallbackEnd = candidateEnd < end ? candidateEnd : end;
      if (fallbackEnd <= startedAtUtc) return const [];
      return [
        SessionTimeInterval(startUtc: startedAtUtc, endUtc: fallbackEnd),
      ];
    }

    final pauses = <PauseInterval>[...pauseIntervals];
    if (endedAtUtc == null && pausedAtUtc != null) {
      pauses.add(PauseInterval(
        startedAtUtc: pausedAtUtc!,
        endedAtUtc: end,
      ));
    }
    pauses.sort((a, b) => a.startedAtUtc.compareTo(b.startedAtUtc));

    final focused = <SessionTimeInterval>[];
    var cursor = startedAtUtc;
    for (final pause in pauses) {
      final pauseStart =
          pause.startedAtUtc > startedAtUtc ? pause.startedAtUtc : startedAtUtc;
      final pauseEnd = pause.endedAtUtc < end ? pause.endedAtUtc : end;
      if (pauseEnd <= cursor || pauseEnd <= pauseStart) continue;

      if (pauseStart > cursor) {
        focused.add(SessionTimeInterval(startUtc: cursor, endUtc: pauseStart));
      }
      if (pauseEnd > cursor) cursor = pauseEnd;
      if (cursor >= end) break;
    }
    if (cursor < end) {
      focused.add(SessionTimeInterval(startUtc: cursor, endUtc: end));
    }
    return focused;
  }

  int activeDurationMs({int? nowUtcMs}) {
    return activeIntervals(nowUtcMs: nowUtcMs)
        .fold(0, (total, interval) => total + interval.durationMs);
  }

  ReadingSession copyWith({
    String? id,
    int? startedAtUtc,
    int? endedAtUtc,
    int? pausedAtUtc,
    bool clearPausedAtUtc = false,
    int? pausedTotalMs,
    int? durationMs,
    int? tzOffsetMin,
    String? subjectId,
    String? note,
    String? source,
    String? deviceId,
    int? createdAt,
    int? updatedAt,
    int? deletedAt,
    List<PauseInterval>? pauseIntervals,
  }) {
    return ReadingSession(
      id: id ?? this.id,
      startedAtUtc: startedAtUtc ?? this.startedAtUtc,
      endedAtUtc: endedAtUtc ?? this.endedAtUtc,
      pausedAtUtc: clearPausedAtUtc ? null : (pausedAtUtc ?? this.pausedAtUtc),
      pausedTotalMs: pausedTotalMs ?? this.pausedTotalMs,
      durationMs: durationMs ?? this.durationMs,
      tzOffsetMin: tzOffsetMin ?? this.tzOffsetMin,
      subjectId: subjectId ?? this.subjectId,
      note: note ?? this.note,
      source: source ?? this.source,
      deviceId: deviceId ?? this.deviceId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      pauseIntervals: pauseIntervals ?? this.pauseIntervals,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'started_at_utc': startedAtUtc,
      'ended_at_utc': endedAtUtc,
      'paused_at_utc': pausedAtUtc,
      'paused_total_ms': pausedTotalMs,
      'duration_ms': durationMs,
      'tz_offset_min': tzOffsetMin,
      'subject_id': subjectId,
      'note': note,
      'source': source,
      'device_id': deviceId,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'deleted_at': deletedAt,
      'pause_intervals': pauseIntervals.map((interval) => interval.toMap()).toList(),
    };
  }

  factory ReadingSession.fromMap(Map<String, dynamic> map) {
    final rawPauseIntervals = map['pause_intervals'];
    final intervals = <PauseInterval>[];
    if (rawPauseIntervals is List) {
      for (final item in rawPauseIntervals) {
        if (item is Map) {
          try {
            intervals.add(PauseInterval.fromMap(Map<String, dynamic>.from(item)));
          } catch (_) {
            // Ignore malformed interval records while preserving the session.
          }
        }
      }
    }

    return ReadingSession(
      id: map['id'] as String,
      startedAtUtc: (map['started_at_utc'] as num).toInt(),
      endedAtUtc: (map['ended_at_utc'] as num?)?.toInt(),
      pausedAtUtc: (map['paused_at_utc'] as num?)?.toInt(),
      pausedTotalMs: (map['paused_total_ms'] as num?)?.toInt() ?? 0,
      durationMs: (map['duration_ms'] as num?)?.toInt() ?? 0,
      tzOffsetMin: (map['tz_offset_min'] as num?)?.toInt() ?? 0,
      subjectId: map['subject_id'] as String?,
      note: map['note'] as String?,
      source: map['source'] as String? ?? 'timer',
      deviceId: map['device_id'] as String? ?? 'local',
      createdAt: (map['created_at'] as num).toInt(),
      updatedAt: (map['updated_at'] as num).toInt(),
      deletedAt: (map['deleted_at'] as num?)?.toInt(),
      pauseIntervals: intervals,
    );
  }
}
