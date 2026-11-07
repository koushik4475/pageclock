class ReadingSession {
  final String id;
  final int startedAtUtc; // epoch ms
  final int? endedAtUtc; // null if running
  final int pausedTotalMs;
  final int durationMs; // denormalized on stop
  final int tzOffsetMin; // user's timezone offset in minutes at start
  final String? subjectId;
  final String? note;
  final String source; // 'timer' | 'manual'
  final String deviceId;
  final int createdAt;
  final int updatedAt;
  final int? deletedAt;

  const ReadingSession({
    required this.id,
    required this.startedAtUtc,
    this.endedAtUtc,
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
  });

  bool get isRunning => endedAtUtc == null;

  DateTime get startTime => DateTime.fromMillisecondsSinceEpoch(startedAtUtc);
  DateTime? get endTime => endedAtUtc != null ? DateTime.fromMillisecondsSinceEpoch(endedAtUtc!) : null;
  String get subjectName => subjectId ?? 'General Focus';
  String? get bookTitle => note;

  int calculateCurrentDurationMs(int nowUtc) {
    if (endedAtUtc != null) {
      return durationMs;
    }
    final rawElapsed = nowUtc - startedAtUtc;
    final net = rawElapsed - pausedTotalMs;
    return net > 0 ? net : 0;
  }

  ReadingSession copyWith({
    String? id,
    int? startedAtUtc,
    int? endedAtUtc,
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
  }) {
    return ReadingSession(
      id: id ?? this.id,
      startedAtUtc: startedAtUtc ?? this.startedAtUtc,
      endedAtUtc: endedAtUtc ?? this.endedAtUtc,
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
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'started_at_utc': startedAtUtc,
      'ended_at_utc': endedAtUtc,
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
    };
  }

  factory ReadingSession.fromMap(Map<String, dynamic> map) {
    return ReadingSession(
      id: map['id'] as String,
      startedAtUtc: map['started_at_utc'] as int,
      endedAtUtc: map['ended_at_utc'] as int?,
      pausedTotalMs: map['paused_total_ms'] as int? ?? 0,
      durationMs: map['duration_ms'] as int? ?? 0,
      tzOffsetMin: map['tz_offset_min'] as int? ?? 0,
      subjectId: map['subject_id'] as String?,
      note: map['note'] as String?,
      source: map['source'] as String? ?? 'timer',
      deviceId: map['device_id'] as String? ?? 'local',
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
      deletedAt: map['deleted_at'] as int?,
    );
  }
}
