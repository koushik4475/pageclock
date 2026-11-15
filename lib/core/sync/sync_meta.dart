import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../account/account_scope.dart';
import '../models/reading_session.dart';

/// User's choice regarding guest history import upon first sign-in.
enum GuestImportChoice {
  merge,
  cloudOnly,
  notNow;

  String toValue() {
    switch (this) {
      case GuestImportChoice.merge:
        return 'merge';
      case GuestImportChoice.cloudOnly:
        return 'cloud_only';
      case GuestImportChoice.notNow:
        return 'not_now';
    }
  }

  static GuestImportChoice? fromValue(String? raw) {
    if (raw == null) return null;
    switch (raw) {
      case 'merge':
        return GuestImportChoice.merge;
      case 'cloud_only':
        return GuestImportChoice.cloudOnly;
      case 'not_now':
        return GuestImportChoice.notNow;
      default:
        return null;
    }
  }
}

/// Per-user cloud sync metadata stored locally in SharedPreferences.
///
/// Replaces separate outbox architectures by tracking:
/// - [cursor]: High-water mark of cloud `server_seq` successfully ingested.
/// - [syncedVersions]: Map of `{sessionId: updatedAtMs}` reflecting the exact
///   version acknowledged by the server.
/// - [importChoice]: Records if/how guest history was imported.
/// - [quarantine]: Map of `{sessionId: reason}` for poison-pill rows that
///   failed schema or constraint validation.
class SyncMeta {
  final String userId;
  int cursor;
  final Map<String, int> syncedVersions;
  GuestImportChoice? importChoice;
  final Map<String, String> quarantine;

  SyncMeta({
    required this.userId,
    this.cursor = 0,
    Map<String, int>? syncedVersions,
    this.importChoice,
    Map<String, String>? quarantine,
  })  : syncedVersions = syncedVersions ?? {},
        quarantine = quarantine ?? {};

  String get storageKey => AccountScope.syncMetaKey(userId);

  /// Checks whether a local session requires synchronization to the cloud.
  ///
  /// Invariants:
  /// 1. Only completed sessions (`endedAtUtc != null`) may be dirty.
  /// 2. Running timers and cancelled/discarded drafts (`endedAtUtc == null`) are NEVER dirty.
  /// 3. Quarantined sessions are skipped until resolved.
  bool isDirty(ReadingSession session) {
    // Never sync running timers or cancelled running sessions
    if (session.endedAtUtc == null) {
      return false;
    }

    // Skip quarantined rows
    if (quarantine.containsKey(session.id)) {
      return false;
    }

    final syncedUpdatedAt = syncedVersions[session.id];
    return syncedUpdatedAt == null || syncedUpdatedAt != session.updatedAt;
  }

  /// Records that the exact [updatedAt] timestamp of [sessionId] was acknowledged by the server.
  /// If the session was edited locally mid-flight to a higher `updatedAt`, it will remain dirty.
  void markSynced(String sessionId, int updatedAt) {
    syncedVersions[sessionId] = updatedAt;
    quarantine.remove(sessionId);
  }

  /// Moves a poison-pill row to quarantine with a diagnostic error reason.
  void markQuarantined(String sessionId, String reason) {
    quarantine[sessionId] = reason;
  }

  /// Removes a row from quarantine (e.g. for user retry or edit).
  void clearQuarantine(String sessionId) {
    quarantine.remove(sessionId);
  }

  /// Advances the cursor to the maximum observed `server_seq`.
  void updateCursor(int newSeq) {
    if (newSeq > cursor) {
      cursor = newSeq;
    }
  }

  /// Resets the cursor to 0, forcing a full resync from sequence start on next pull.
  void resetCursor() {
    cursor = 0;
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'cursor': cursor,
      'synced_versions': syncedVersions,
      'import_choice': importChoice?.toValue(),
      'quarantine': quarantine,
    };
  }

  factory SyncMeta.fromMap(String userId, Map<String, dynamic> map) {
    final synced = <String, int>{};
    final rawSynced = map['synced_versions'];
    if (rawSynced is Map) {
      rawSynced.forEach((k, v) {
        if (v is num) synced[k.toString()] = v.toInt();
      });
    }

    final quar = <String, String>{};
    final rawQuar = map['quarantine'];
    if (rawQuar is Map) {
      rawQuar.forEach((k, v) {
        if (v != null) quar[k.toString()] = v.toString();
      });
    }

    return SyncMeta(
      userId: userId,
      cursor: (map['cursor'] as num?)?.toInt() ?? 0,
      syncedVersions: synced,
      importChoice: GuestImportChoice.fromValue(map['import_choice'] as String?),
      quarantine: quar,
    );
  }

  static SyncMeta load(SharedPreferences prefs, String userId) {
    final key = AccountScope.syncMetaKey(userId);
    final raw = prefs.getString(key);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = json.decode(raw) as Map<String, dynamic>;
        return SyncMeta.fromMap(userId, decoded);
      } catch (e) {
        debugPrint('[SyncMeta] Error decoding sync meta for $userId: $e');
      }
    }
    return SyncMeta(userId: userId);
  }

  Future<bool> save(SharedPreferences prefs) async {
    final raw = json.encode(toMap());
    return prefs.setString(storageKey, raw);
  }
}
