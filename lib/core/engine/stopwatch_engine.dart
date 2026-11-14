import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/reading_session.dart';
import '../repository/session_repository.dart';

enum StopwatchStatus { idle, running, paused }

class StopwatchState {
  final StopwatchStatus status;
  final ReadingSession? currentSession;
  final int? pauseTimestampUtc; // epoch ms when pause was triggered
  final int elapsedMs;

  const StopwatchState({
    required this.status,
    this.currentSession,
    this.pauseTimestampUtc,
    this.elapsedMs = 0,
  });

  bool get isRunning => status == StopwatchStatus.running;
  bool get isPaused => status == StopwatchStatus.paused;

  StopwatchState copyWith({
    StopwatchStatus? status,
    ReadingSession? currentSession,
    int? pauseTimestampUtc,
    int? elapsedMs,
    bool clearPauseTimestamp = false,
  }) {
    return StopwatchState(
      status: status ?? this.status,
      currentSession: currentSession ?? this.currentSession,
      pauseTimestampUtc: clearPauseTimestamp
          ? null
          : (pauseTimestampUtc ?? this.pauseTimestampUtc),
      elapsedMs: elapsedMs ?? this.elapsedMs,
    );
  }
}

class StopwatchNotifier extends StateNotifier<StopwatchState> {
  final SessionRepository _repository;
  Timer? _ticker;
  static const _uuid = Uuid();

  late final Future<void> _restoreFuture;
  bool _startInProgress = false;

  StopwatchNotifier(this._repository)
      : super(const StopwatchState(status: StopwatchStatus.idle)) {
    _restoreFuture = _restoreActiveSession();
  }

  Future<void> _restoreActiveSession() async {
    final active = await _repository.getActiveSession();
    if (!mounted || active == null) return;

    final nowUtc = DateTime.now().toUtc().millisecondsSinceEpoch;
    final elapsed = active.calculateCurrentDurationMs(nowUtc);
    final isPaused = active.pausedAtUtc != null;
    state = StopwatchState(
      status: isPaused ? StopwatchStatus.paused : StopwatchStatus.running,
      currentSession: active,
      pauseTimestampUtc: active.pausedAtUtc,
      elapsedMs: elapsed,
    );
    if (!isPaused) {
      _startTicker();
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (state.status == StopwatchStatus.running && state.currentSession != null) {
        final nowUtc = DateTime.now().toUtc().millisecondsSinceEpoch;
        final elapsed = state.currentSession!.calculateCurrentDurationMs(nowUtc);
        state = state.copyWith(elapsedMs: elapsed);
      }
    });
  }

  Future<void> start({String? subjectId, String? note}) async {
    // Do not create a new row until the persisted active session has been
    // restored. Otherwise a fast first tap after cold launch can orphan a
    // second active session while the async restore later replaces UI state.
    await _restoreFuture;
    if (_startInProgress) return;
    _startInProgress = true;
    try {
      // If already running, ignore
      if (state.status == StopwatchStatus.running) return;

      // If currently paused, resume existing session instead of orphaning it
      if (state.status == StopwatchStatus.paused && state.currentSession != null) {
        await resume();
        return;
      }

      final nowUtc = DateTime.now().toUtc().millisecondsSinceEpoch;
      final tzOffset = DateTime.now().timeZoneOffset.inMinutes;

      final session = ReadingSession(
        id: _uuid.v4(),
        startedAtUtc: nowUtc,
        endedAtUtc: null,
        pausedAtUtc: null,
        pausedTotalMs: 0,
        durationMs: 0,
        tzOffsetMin: tzOffset,
        subjectId: subjectId,
        note: note,
        source: 'timer',
        deviceId: 'local',
        createdAt: nowUtc,
        updatedAt: nowUtc,
      );

      await _repository.saveSession(session);
      if (!mounted) return;

      state = StopwatchState(
        status: StopwatchStatus.running,
        currentSession: session,
        elapsedMs: 0,
      );

      _startTicker();
    } finally {
      _startInProgress = false;
    }
  }

  Future<void> pause() async {
    await _restoreFuture;
    if (state.status != StopwatchStatus.running || state.currentSession == null) return;

    _ticker?.cancel();
    final nowUtc = DateTime.now().toUtc().millisecondsSinceEpoch;

    final updated = state.currentSession!.copyWith(
      pausedAtUtc: nowUtc,
      updatedAt: nowUtc,
    );
    await _repository.updateSession(updated);

    state = state.copyWith(
      status: StopwatchStatus.paused,
      currentSession: updated,
      pauseTimestampUtc: nowUtc,
    );
  }

  Future<void> resume() async {
    await _restoreFuture;
    if (state.status != StopwatchStatus.paused || state.currentSession == null) return;

    final nowUtc = DateTime.now().toUtc().millisecondsSinceEpoch;
    final pauseStart = state.currentSession!.pausedAtUtc ?? state.pauseTimestampUtc ?? nowUtc;
    final pauseDuration = (nowUtc - pauseStart).clamp(0, double.maxFinite.toInt());

    final currentSession = state.currentSession!;
    final updatedSession = currentSession.copyWith(
      clearPausedAtUtc: true,
      pausedTotalMs: currentSession.pausedTotalMs + pauseDuration,
      pauseIntervals: pauseDuration > 0
          ? [
              ...currentSession.pauseIntervals,
              PauseInterval(startedAtUtc: pauseStart, endedAtUtc: nowUtc),
            ]
          : currentSession.pauseIntervals,
      updatedAt: nowUtc,
    );

    await _repository.updateSession(updatedSession);

    state = state.copyWith(
      status: StopwatchStatus.running,
      currentSession: updatedSession,
      clearPauseTimestamp: true,
      elapsedMs: updatedSession.calculateCurrentDurationMs(nowUtc),
    );

    _startTicker();
  }

  Future<ReadingSession?> stop({int minSessionDurationMs = 10000, bool forceSave = false}) async {
    await _restoreFuture;
    if (state.currentSession == null) return null;

    _ticker?.cancel();
    final nowUtc = DateTime.now().toUtc().millisecondsSinceEpoch;

    var session = state.currentSession!;
    if (state.status == StopwatchStatus.paused) {
      final pauseStart = session.pausedAtUtc ?? state.pauseTimestampUtc ?? nowUtc;
      final additionalPause = (nowUtc - pauseStart).clamp(0, double.maxFinite.toInt());
      session = session.copyWith(
        clearPausedAtUtc: true,
        pausedTotalMs: session.pausedTotalMs + additionalPause,
        pauseIntervals: additionalPause > 0
            ? [
                ...session.pauseIntervals,
                PauseInterval(startedAtUtc: pauseStart, endedAtUtc: nowUtc),
              ]
            : session.pauseIntervals,
      );
    }

    final finalDuration = session.calculateCurrentDurationMs(nowUtc);

    // If shorter than threshold and user or system discards
    if (finalDuration < minSessionDurationMs && minSessionDurationMs > 0 && !forceSave) {
      await _repository.softDeleteSession(session.id);
      state = const StopwatchState(status: StopwatchStatus.idle);
      return null;
    }

    final finishedSession = session.copyWith(
      clearPausedAtUtc: true,
      endedAtUtc: nowUtc,
      durationMs: finalDuration,
      updatedAt: nowUtc,
    );

    await _repository.updateSession(finishedSession);
    state = const StopwatchState(status: StopwatchStatus.idle);
    return finishedSession;
  }

  /// Discards the active session without saving it as a completed entry.
  Future<void> cancel() async {
    await _restoreFuture;
    _ticker?.cancel();
    final session = state.currentSession;
    if (session != null) {
      await _repository.softDeleteSession(session.id);
    }
    state = const StopwatchState(status: StopwatchStatus.idle);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

final stopwatchProvider =
    StateNotifierProvider<StopwatchNotifier, StopwatchState>((ref) {
  final repo = ref.watch(sessionRepositoryProvider);
  return StopwatchNotifier(repo);
});

/// Backwards-compatible name used by the fullscreen and settings screens.
final stopwatchEngineProvider = stopwatchProvider;
