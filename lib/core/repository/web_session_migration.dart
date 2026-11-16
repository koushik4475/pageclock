import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../account/account_scope.dart';
import '../models/reading_session.dart';

/// Handles non-destructive, idempotent migration of legacy `pageclock_web_sessions_v1`
/// sessions into the modern `pageclock_web_sessions_v2_guest` partition.
///
/// Invariants:
/// 1. `pageclock_web_sessions_v1` is NEVER deleted or mutated.
/// 2. Migration is safe to run repeatedly on every app boot. If an older cached PWA tab
///    writes new sessions to `v1`, subsequent loads will re-merge them by LWW into `v2_guest`.
class WebSessionMigration {
  const WebSessionMigration._();

  /// Migrates sessions from v1 to v2 guest using Last-Write-Wins (LWW) conflict resolution.
  /// Returns the total number of sessions in the v2 guest partition after migration.
  static Future<int> migrateLegacyV1ToV2Guest(SharedPreferences prefs) async {
    final rawV1 = prefs.getString(AccountScope.legacyV1Key);
    if (rawV1 == null || rawV1.trim().isEmpty) {
      return 0;
    }

    List<ReadingSession> v1Sessions;
    try {
      final decoded = json.decode(rawV1) as List<dynamic>;
      v1Sessions = decoded
          .map((item) => ReadingSession.fromMap(Map<String, dynamic>.from(item as Map)))
          .toList();
    } catch (e) {
      debugPrint('[WebSessionMigration] Error decoding legacy v1 sessions: $e');
      return 0;
    }

    if (v1Sessions.isEmpty) return 0;

    // Load existing v2 guest sessions
    final Map<String, ReadingSession> guestSessions = {};
    final rawV2 = prefs.getString(AccountScope.guestSessionsKey);
    if (rawV2 != null && rawV2.trim().isNotEmpty) {
      try {
        final decodedV2 = json.decode(rawV2) as List<dynamic>;
        for (final item in decodedV2) {
          final s = ReadingSession.fromMap(Map<String, dynamic>.from(item as Map));
          guestSessions[s.id] = s;
        }
      } catch (e) {
        debugPrint('[WebSessionMigration] Error decoding existing v2 guest sessions: $e');
      }
    }

    bool changed = false;
    for (final legacy in v1Sessions) {
      final existing = guestSessions[legacy.id];
      if (existing == null) {
        guestSessions[legacy.id] = legacy;
        changed = true;
      } else {
        // LWW tie-break
        if (legacy.updatedAt > existing.updatedAt) {
          guestSessions[legacy.id] = legacy;
          changed = true;
        } else if (legacy.updatedAt == existing.updatedAt) {
          // Tombstone wins on equal timestamp
          if (legacy.deletedAt != null && existing.deletedAt == null) {
            guestSessions[legacy.id] = legacy;
            changed = true;
          }
        }
      }
    }

    if (changed || rawV2 == null) {
      final serialized = guestSessions.values.map((s) => s.toMap()).toList();
      final saved = await prefs.setString(
        AccountScope.guestSessionsKey,
        json.encode(serialized),
      );
      if (!saved) {
        throw StateError(
          'Browser storage rejected the PageClock legacy v1 migration save.',
        );
      }
    }

    return guestSessions.length;
  }
}
