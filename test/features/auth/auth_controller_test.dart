import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pageclock/core/account/account_scope.dart';
import 'package:pageclock/core/engine/stopwatch_engine.dart';
import 'package:pageclock/core/repository/session_repository.dart';
import 'package:pageclock/core/settings/app_settings.dart';
import 'package:pageclock/features/auth/application/auth_controller.dart';
import 'package:pageclock/features/auth/data/auth_repository.dart';
import 'package:pageclock/features/auth/domain/auth_models.dart';

class MockAuthRepository implements AuthRepository {
  AuthUser? mockCurrentUser;
  final _controller = StreamController<AuthUser?>.broadcast();
  bool throwOnSendOtp = false;
  String throwErrorString = '';

  @override
  AuthUser? get currentUser => mockCurrentUser;

  @override
  Stream<AuthUser?> authStateChanges() => _controller.stream;

  @override
  Future<void> signInWithOtp(String email) async {
    if (throwOnSendOtp) {
      throw Exception(throwErrorString);
    }
  }

  @override
  Future<AuthUser?> verifyOtp({required String email, required String token}) async {
    if (token == '123456') {
      final user = AuthUser(id: 'usr_verified_789', email: email);
      mockCurrentUser = user;
      _controller.add(user);
      return user;
    }
    throw Exception('invalid_token');
  }

  @override
  Future<void> signInWithGoogle({String? redirectTo}) async {}

  @override
  Future<void> signOut() async {
    mockCurrentUser = null;
    _controller.add(null);
  }

  @override
  Future<bool> deleteAccount() async {
    mockCurrentUser = null;
    _controller.add(null);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthController & Scope Guard Rules (§7.3)', () {
    late SharedPreferences prefs;
    late MockAuthRepository mockAuth;
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      mockAuth = MockAuthRepository();

      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          sessionRepositoryProvider.overrideWithValue(InMemorySessionRepository()),
          authRepositoryProvider.overrideWithValue(mockAuth),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('timer guard blocks Google sign-in when stopwatch is running', () async {
      final stopwatchNotifier = container.read(stopwatchProvider.notifier);
      await stopwatchNotifier.start();

      expect(container.read(stopwatchProvider).status, equals(StopwatchStatus.running));

      final authController = container.read(authControllerProvider.notifier);
      final success = await authController.signInWithGoogle();

      expect(success, isFalse);
      expect(
        container.read(authControllerProvider).errorMessage,
        equals(AuthController.timerBlockedMessage),
      );
    });

    test('timer guard blocks OTP submission when stopwatch is paused', () async {
      final stopwatchNotifier = container.read(stopwatchProvider.notifier);
      await stopwatchNotifier.start();
      await stopwatchNotifier.pause();

      expect(container.read(stopwatchProvider).status, equals(StopwatchStatus.paused));

      final authController = container.read(authControllerProvider.notifier);
      final success = await authController.sendOtp('reader@example.com');

      expect(success, isFalse);
      expect(
        container.read(authControllerProvider).errorMessage,
        equals(AuthController.timerBlockedMessage),
      );
    });

    test('timer guard blocks sign-out when stopwatch is active', () async {
      // First sign in while idle
      final authController = container.read(authControllerProvider.notifier);
      await authController.sendOtp('reader@example.com');
      await authController.verifyOtp('123456');

      expect(container.read(accountScopeProvider).isUser, isTrue);

      // Now start a reading timer
      final stopwatchNotifier = container.read(stopwatchProvider.notifier);
      await stopwatchNotifier.start();

      // Sign out must be strictly blocked
      final signOutSuccess = await authController.signOut();
      expect(signOutSuccess, isFalse);
      expect(
        container.read(authControllerProvider).errorMessage,
        equals(AuthController.timerBlockedMessage),
      );
      // Account scope must remain untouched
      expect(container.read(accountScopeProvider).isUser, isTrue);
    });

    test('timer guard blocks delete account when stopwatch is active', () async {
      final authController = container.read(authControllerProvider.notifier);
      await authController.sendOtp('reader@example.com');
      await authController.verifyOtp('123456');

      final stopwatchNotifier = container.read(stopwatchProvider.notifier);
      await stopwatchNotifier.start();

      final deleteSuccess = await authController.deleteAccount();
      expect(deleteSuccess, isFalse);
      expect(
        container.read(authControllerProvider).errorMessage,
        equals(AuthController.timerBlockedMessage),
      );
    });

    test('OTP resend cooldown survives simulated browser reload', () async {
      final authController = container.read(authControllerProvider.notifier);
      final sent = await authController.sendOtp('reader@example.com');
      expect(sent, isTrue);

      final stateBeforeReload = container.read(authControllerProvider);
      expect(stateBeforeReload.isOtpSent, isTrue);
      expect(stateBeforeReload.remainingCooldownSeconds, greaterThan(0));

      // Simulate browser reload by recreating ProviderContainer with same SharedPreferences
      final reloadedContainer = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(mockAuth),
        ],
      );

      final stateAfterReload = reloadedContainer.read(authControllerProvider);
      expect(stateAfterReload.isOtpSent, isTrue);
      expect(stateAfterReload.remainingCooldownSeconds, greaterThan(0));

      reloadedContainer.dispose();
    });

    test('rate limit error is mapped to calm, informative copy', () async {
      mockAuth.throwOnSendOtp = true;
      mockAuth.throwErrorString = 'over_email_send_rate_limit: 429 Too Many Requests';

      final authController = container.read(authControllerProvider.notifier);
      final sent = await authController.sendOtp('reader@example.com');

      expect(sent, isFalse);
      final err = container.read(authControllerProvider).errorMessage;
      expect(err, contains('Too many login attempts'));
    });

    test('delete account purges user partition and sync metadata', () async {
      final authController = container.read(authControllerProvider.notifier);
      await authController.sendOtp('reader@example.com');
      await authController.verifyOtp('123456');

      final userId = container.read(accountScopeProvider).userId!;

      // Put dummy data in user partition and sync meta
      await prefs.setString(AccountScope.userSessionsKey(userId), '["dummy"]');
      await prefs.setString(AccountScope.syncMetaKey(userId), '{"cursor": 5}');

      final deleted = await authController.deleteAccount();
      expect(deleted, isTrue);

      // Partitions must be wiped
      expect(prefs.containsKey(AccountScope.userSessionsKey(userId)), isFalse);
      expect(prefs.containsKey(AccountScope.syncMetaKey(userId)), isFalse);

      // Scope reverted to guest
      expect(container.read(accountScopeProvider), equals(const AccountScope.guest()));
    });
  });
}
