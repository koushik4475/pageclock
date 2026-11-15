import 'package:flutter/foundation.dart';
import '../models/reading_session.dart';

/// Identifies which version won during conflict resolution.
enum MergeWinner {
  local,
  remote,
}

/// Structured outcome of merging a local and remote session.
class SessionMergeResult {
  final ReadingSession session;
  final MergeWinner winner;
  final bool hadConflict;

  const SessionMergeResult({
    required this.session,
    required this.winner,
    this.hadConflict = false,
  });

  bool get isLocalWinner => winner == MergeWinner.local;
  bool get isRemoteWinner => winner == MergeWinner.remote;
}

/// Pure, deterministic Last-Write-Wins (LWW) conflict resolution for PageClock reading sessions.
///
/// Invariant: Merge logic is identical on client and server.
/// Tie-breaking hierarchy:
/// 1. Higher `updatedAt` (epoch ms) strictly wins.
/// 2. If equal, a tombstone (`deletedAt != null`) beats a live row (`deletedAt == null`).
/// 3. If still equal (both deleted or both live), the SERVER (remote) row wins.
/// 4. Whenever a tombstone wins, `note` is cleared (matching cloud database trigger).
class SessionMerge {
  const SessionMerge._();

  /// Merges a [local] session with a [remote] session.
  /// At least one of [local] or [remote] must be non-null.
  static SessionMergeResult merge({
    ReadingSession? local,
    ReadingSession? remote,
  }) {
    assert(
      local != null || remote != null,
      'At least one session must be provided for merge',
    );

    if (local == null) {
      final sanitizedRemote = _sanitizeTombstone(remote!);
      return SessionMergeResult(
        session: sanitizedRemote,
        winner: MergeWinner.remote,
      );
    }

    if (remote == null) {
      final sanitizedLocal = _sanitizeTombstone(local);
      return SessionMergeResult(
        session: sanitizedLocal,
        winner: MergeWinner.local,
      );
    }

    assert(
      local.id == remote.id,
      'Cannot merge sessions with differing IDs: ${local.id} vs ${remote.id}',
    );

    // Rule 1: Higher updatedAt wins
    if (local.updatedAt > remote.updatedAt) {
      return SessionMergeResult(
        session: _sanitizeTombstone(local),
        winner: MergeWinner.local,
      );
    }

    if (remote.updatedAt > local.updatedAt) {
      return SessionMergeResult(
        session: _sanitizeTombstone(remote),
        winner: MergeWinner.remote,
      );
    }

    // Rule 2: Equal timestamps -> tombstone wins over live row
    final bool localIsTombstone = local.deletedAt != null;
    final bool remoteIsTombstone = remote.deletedAt != null;

    if (localIsTombstone && !remoteIsTombstone) {
      return SessionMergeResult(
        session: _sanitizeTombstone(local),
        winner: MergeWinner.local,
        hadConflict: true,
      );
    }

    if (remoteIsTombstone && !localIsTombstone) {
      return SessionMergeResult(
        session: _sanitizeTombstone(remote),
        winner: MergeWinner.remote,
        hadConflict: true,
      );
    }

    // Rule 3: Still equal (both live or both tombstones) -> SERVER (remote) row wins
    final bool contentsDiffer = local.durationMs != remote.durationMs ||
        local.note != remote.note ||
        local.startedAtUtc != remote.startedAtUtc ||
        local.endedAtUtc != remote.endedAtUtc;

    if (contentsDiffer) {
      debugPrint(
        '[SessionMerge] Conflict resolved for session ${local.id}: server row wins on identical timestamp (${local.updatedAt})',
      );
    }

    return SessionMergeResult(
      session: _sanitizeTombstone(remote),
      winner: MergeWinner.remote,
      hadConflict: contentsDiffer,
    );
  }

  /// Ensures that any soft-deleted session has its note cleared,
  /// preserving privacy and matching cloud trigger behavior.
  static ReadingSession _sanitizeTombstone(ReadingSession s) {
    if (s.deletedAt != null && s.note != null) {
      return s.copyWith(clearNote: true);
    }
    return s;
  }
}
