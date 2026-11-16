import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
import 'package:pageclock/features/settings/toggl_settings_screen.dart';

class _FakeAuthRepository implements AuthRepository {
  AuthUser? mockCurrentUser;
  final StreamController<AuthUser?> _events = StreamController<AuthUser?>.broadcast();
  int signOutCalls = 0;

  _FakeAuthRepository(this.mockCurrentUser);

  @override
  AuthUser? get currentUser => mockCurrentUser;

  @override
  Stream<AuthUser?> authStateChanges() => _events.stream;

  @override
  Future<void> signInWithOtp(String email) async {}

  @override
  Future<AuthUser?> verifyOtp({
    required String email,
    required String token,
  }) async =>
      mockCurrentUser;

  @override
  Future<void> signInWithGoogle({String? redirectTo}) async {}

  @override
  Future<void> signOut() async {
    signOutCalls++;
    mockCurrentUser = null;
    _events.add(null);
  }

  @override
  Future<bool> deleteAccount() async => false;

  Future<void> dispose() => _events.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Settings sign-out flow', () {
    late SharedPreferences prefs;
    late _FakeAuthRepository auth;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        AccountScope.activeScopeKey: 'user:reader-123',
      });
      prefs = await SharedPreferences.getInstance();
      auth = _FakeAuthRepository(
        const AuthUser(id: 'reader-123', email: 'reader@example.com'),
      );
    });

    tearDown(() async {
      await auth.dispose();
    });

    Future<ProviderContainer> pumpSettings(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          sessionRepositoryProvider.overrideWithValue(InMemorySessionRepository()),
          authRepositoryProvider.overrideWithValue(auth),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: TogglSettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -1600),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sign Out'), findsOneWidget);
      return container;
    }

    testWidgets('requires confirmation and switches to guest only after sign-out', (tester) async {
      final container = await pumpSettings(tester);

      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();

      expect(find.text('Sign out of PageClock?'), findsOneWidget);
      expect(auth.signOutCalls, 0);
      expect(container.read(accountScopeProvider).isUser, isTrue);

      await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
      await tester.pumpAndSettle();

      expect(auth.signOutCalls, 1);
      expect(container.read(accountScopeProvider).isGuest, isTrue);
      expect(
        find.text('Signed out. PageClock is now in local guest mode.'),
        findsOneWidget,
      );
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('cancel keeps the authenticated account active', (tester) async {
      final container = await pumpSettings(tester);

      await tester.tap(find.text('Sign Out'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(auth.signOutCalls, 0);
      expect(container.read(accountScopeProvider).isUser, isTrue);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));

    testWidgets('active timer blocks sign-out before showing confirmation', (tester) async {
      final container = await pumpSettings(tester);
      await container.read(stopwatchProvider.notifier).start();
      await tester.pump();

      await tester.tap(find.text('Sign Out'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Sign out of PageClock?'), findsNothing);
      expect(find.text(AuthController.timerBlockedMessage), findsOneWidget);
      expect(auth.signOutCalls, 0);
      expect(container.read(accountScopeProvider).isUser, isTrue);
    }, variant: TargetPlatformVariant.only(TargetPlatform.android));
  });
}
