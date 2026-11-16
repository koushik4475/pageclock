import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../settings/app_settings.dart';

/// Represents the active account scope: either guest (local-only) or an authenticated user.
///
/// Invariant: Scope is persisted locally and resolved at boot from disk, NOT derived
/// from ephemeral network state or session refreshes. Offline boot with an expired JWT
/// continues to open the user's partition safely.
class AccountScope {
  final String? userId;

  const AccountScope.guest() : userId = null;

  const AccountScope.user(this.userId)
      : assert(userId != null && userId != '', 'userId cannot be null or empty');

  bool get isGuest => userId == null;
  bool get isUser => userId != null;

  // Persisted storage keys
  static const String activeScopeKey = 'pageclock_active_scope_v1';
  static const String legacyV1Key = 'pageclock_web_sessions_v1';
  static const String guestSessionsKey = 'pageclock_web_sessions_v2_guest';
  static const String guestImportLogKey = 'pageclock_guest_import_log_v1';

  static String userSessionsKey(String uid) =>
      'pageclock_web_sessions_v2_user_$uid';

  static String syncMetaKey(String uid) =>
      'pageclock_sync_meta_v1_user_$uid';

  String get storageKey => isUser ? userSessionsKey(userId!) : guestSessionsKey;

  String get syncMetaStorageKey => isUser ? syncMetaKey(userId!) : '';

  static String storageKeyForScope(AccountScope scope) => scope.storageKey;

  String serialize() => isUser ? 'user:$userId' : 'guest';

  factory AccountScope.parse(String? raw) {
    if (raw == null || raw.isEmpty || raw == 'guest') {
      return const AccountScope.guest();
    }
    if (raw.startsWith('user:')) {
      final uid = raw.substring(5).trim();
      if (uid.isNotEmpty) {
        return AccountScope.user(uid);
      }
    }
    return const AccountScope.guest();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccountScope &&
          runtimeType == other.runtimeType &&
          userId == other.userId;

  @override
  int get hashCode => userId.hashCode;

  @override
  String toString() =>
      isUser ? 'AccountScope.user($userId)' : 'AccountScope.guest()';
}

/// Notifier that manages the active account scope with disk persistence.
class AccountScopeNotifier extends StateNotifier<AccountScope> {
  final SharedPreferences _prefs;

  AccountScopeNotifier(this._prefs) : super(_loadInitialScope(_prefs));

  static AccountScope _loadInitialScope(SharedPreferences prefs) {
    final raw = prefs.getString(AccountScope.activeScopeKey);
    return AccountScope.parse(raw);
  }

  Future<void> setScope(AccountScope newScope) async {
    if (state == newScope) return;
    await _prefs.setString(AccountScope.activeScopeKey, newScope.serialize());
    state = newScope;
  }

  Future<void> setGuest() => setScope(const AccountScope.guest());

  Future<void> setUser(String userId) => setScope(AccountScope.user(userId));
}

/// Provider for the active account scope.
final accountScopeProvider =
    StateNotifierProvider<AccountScopeNotifier, AccountScope>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AccountScopeNotifier(prefs);
});
