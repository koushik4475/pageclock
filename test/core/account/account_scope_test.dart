import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pageclock/core/account/account_scope.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AccountScope Value Object & Serialization', () {
    test('guest scope properties and storage keys', () {
      const scope = AccountScope.guest();
      expect(scope.isGuest, isTrue);
      expect(scope.isUser, isFalse);
      expect(scope.userId, isNull);
      expect(scope.storageKey, equals(AccountScope.guestSessionsKey));
      expect(scope.storageKey, equals('pageclock_web_sessions_v2_guest'));
      expect(scope.syncMetaStorageKey, isEmpty);
      expect(scope.subjectsStorageKey, equals(AccountScope.guestSubjectsKey));
      expect(scope.serialize(), equals('guest'));
    });

    test('user scope properties and storage keys', () {
      const scope = AccountScope.user('usr_uuid_12345');
      expect(scope.isGuest, isFalse);
      expect(scope.isUser, isTrue);
      expect(scope.userId, equals('usr_uuid_12345'));
      expect(
        scope.storageKey,
        equals('pageclock_web_sessions_v2_user_usr_uuid_12345'),
      );
      expect(
        scope.syncMetaStorageKey,
        equals('pageclock_sync_meta_v1_user_usr_uuid_12345'),
      );
      expect(scope.subjectsStorageKey, equals('pageclock_subjects_v1_user_usr_uuid_12345'));
      expect(scope.serialize(), equals('user:usr_uuid_12345'));
    });

    test('equality and hashcode are value-based', () {
      const guest1 = AccountScope.guest();
      const guest2 = AccountScope.guest();
      const user1 = AccountScope.user('user_abc');
      const user2 = AccountScope.user('user_abc');
      const user3 = AccountScope.user('user_diff');

      expect(guest1, equals(guest2));
      expect(user1, equals(user2));
      expect(user1, isNot(equals(guest1)));
      expect(user1, isNot(equals(user3)));
      expect(user1.hashCode, equals(user2.hashCode));
    });

    test('serialization round-trip', () {
      expect(AccountScope.parse(null), equals(const AccountScope.guest()));
      expect(AccountScope.parse(''), equals(const AccountScope.guest()));
      expect(AccountScope.parse('guest'), equals(const AccountScope.guest()));
      expect(
        AccountScope.parse('user:usr_999'),
        equals(const AccountScope.user('usr_999')),
      );
      expect(
        AccountScope.parse('user:  usr_trimmed  '),
        equals(const AccountScope.user('usr_trimmed')),
      );
      expect(AccountScope.parse('invalid_prefix'), equals(const AccountScope.guest()));
    });
  });

  group('AccountScopeNotifier Persistence & Offline Boot (§7.3)', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to guest scope when no prior scope was saved in prefs', () async {
      final prefs = await SharedPreferences.getInstance();
      final notifier = AccountScopeNotifier(prefs);

      expect(notifier.state, equals(const AccountScope.guest()));
    });

    test('restores saved user scope from disk on offline boot', () async {
      SharedPreferences.setMockInitialValues({
        AccountScope.activeScopeKey: 'user:usr_offline_boot_uuid',
      });
      final prefs = await SharedPreferences.getInstance();
      final notifier = AccountScopeNotifier(prefs);

      // Offline boot with expired or missing network session must safely open user's partition
      expect(notifier.state, equals(const AccountScope.user('usr_offline_boot_uuid')));
      expect(
        notifier.state.storageKey,
        equals('pageclock_web_sessions_v2_user_usr_offline_boot_uuid'),
      );
    });

    test('updates disk prefs when switching between scopes', () async {
      final prefs = await SharedPreferences.getInstance();
      final notifier = AccountScopeNotifier(prefs);

      await notifier.setUser('user_alpha');
      expect(notifier.state, equals(const AccountScope.user('user_alpha')));
      expect(
        prefs.getString(AccountScope.activeScopeKey),
        equals('user:user_alpha'),
      );

      await notifier.setGuest();
      expect(notifier.state, equals(const AccountScope.guest()));
      expect(
        prefs.getString(AccountScope.activeScopeKey),
        equals('guest'),
      );
    });
  });
}
