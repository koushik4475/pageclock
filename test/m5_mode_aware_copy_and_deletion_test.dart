import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pageclock/core/account/account_scope.dart';
import 'package:pageclock/core/engine/stopwatch_engine.dart';
import 'package:pageclock/core/models/reading_session.dart';
import 'package:pageclock/core/repository/session_repository.dart';
import 'package:pageclock/core/services/pdf_service.dart';
import 'package:pageclock/core/settings/app_settings.dart';
import 'package:pageclock/features/auth/application/auth_controller.dart';
import 'package:pageclock/features/auth/data/auth_repository.dart';
import 'package:pageclock/features/auth/domain/auth_models.dart';

class MockAuthRepository extends Mock implements AuthRepository {}
class MockSessionRepository extends Mock implements SessionRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(ReadingSession(
      id: 'fallback-dummy',
      startedAtUtc: 0,
      durationMs: 0,
      tzOffsetMin: 0,
      source: 'timer',
      createdAt: 0,
      updatedAt: 0,
    ));
  });

  group('M5: Mode-Aware PDF Service Tests', () {
    final sampleSessions = [
      ReadingSession(
        id: 'sess-pdf-1',
        startedAtUtc: 1700000000000,
        endedAtUtc: 1700001800000,
        durationMs: 1800000,
        tzOffsetMin: 0,
        source: 'timer',
        deviceId: 'local',
        createdAt: 1700000000000,
        updatedAt: 1700001800000,
        note: 'Calculus',
      ),
    ];

    test('generatePdf generates non-empty PDF bytes for offline/guest mode', () async {
      final bytes = await SessionPdfService.generatePdf(
        sampleSessions,
        isCloudSync: false,
      );
      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(100));
    });

    test('generatePdf generates non-empty PDF bytes with isCloudSync: true', () async {
      final bytes = await SessionPdfService.generatePdf(
        sampleSessions,
        isCloudSync: true,
      );
      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(100));
    });

    test('generatePdf generates non-empty PDF bytes with customFooterText override', () async {
      final bytes = await SessionPdfService.generatePdf(
        sampleSessions,
        customFooterText: 'PageClock Custom Verification Footer',
      );
      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(100));
    });
  });

  group('M5: Mode-Aware AccountScope Specifications', () {
    test('guest scope behaves as local only and points to guest partition', () {
      const scope = AccountScope.guest();
      expect(scope.isGuest, isTrue);
      expect(scope.isUser, isFalse);
      expect(scope.userId, isNull);
      expect(scope.storageKey, equals(AccountScope.guestSessionsKey));
      expect(scope.syncMetaStorageKey, isEmpty);
      expect(scope.serialize(), equals('guest'));
    });

    test('user scope correctly scopes storage and sync meta keys', () {
      const uid = '01932345-6789-7def-8123-456789abcdef';
      const scope = AccountScope.user(uid);
      expect(scope.isGuest, isFalse);
      expect(scope.isUser, isTrue);
      expect(scope.userId, equals(uid));
      expect(scope.storageKey, equals('pageclock_web_sessions_v2_user_$uid'));
      expect(scope.syncMetaStorageKey, equals('pageclock_sync_meta_v1_user_$uid'));
      expect(scope.serialize(), equals('user:$uid'));
    });

    test('AccountScope parse recovers serialized scopes safely', () {
      expect(AccountScope.parse(null), equals(const AccountScope.guest()));
      expect(AccountScope.parse(''), equals(const AccountScope.guest()));
      expect(AccountScope.parse('guest'), equals(const AccountScope.guest()));
      expect(AccountScope.parse('invalid'), equals(const AccountScope.guest()));
      expect(AccountScope.parse('user:'), equals(const AccountScope.guest()));
      expect(
        AccountScope.parse('user:test-uuid-123'),
        equals(const AccountScope.user('test-uuid-123')),
      );
    });
  });

  group('M5: Service Worker Hardening (web/sw.js)', () {
    late String swContent;

    setUp(() {
      final file = File('web/sw.js');
      expect(file.existsSync(), isTrue, reason: 'web/sw.js must exist');
      swContent = file.readAsStringSync();
    });

    test('CACHE_NAME is bumped to pageclock-brand-v4', () {
      expect(swContent, contains("const CACHE_NAME = 'pageclock-brand-v4';"));
    });

    test('Bypasses caching for search params containing code= or error=', () {
      expect(
        swContent,
        contains("requestUrl.searchParams.has('code') || requestUrl.searchParams.has('error')"),
        reason: 'Service worker must detect code and error OAuth callback parameters',
      );
      expect(
        swContent,
        contains('!hasAuthParams'),
        reason: 'Service worker must skip cache.put when auth params are present',
      );
    });
  });

  group('M5: Honest Documentation & Privacy Checks', () {
    test('PRIVACY_POLICY.md distinguishes native offline vs optional web sync', () {
      final file = File('PRIVACY_POLICY.md');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      // Native offline
      expect(content, contains('Android & iOS Native Applications (100% Offline-First)'));
      expect(content, contains('Zero Cloud Communication'));
      expect(content, contains('Zero Third-Party Trackers or SDKs'));

      // Web optional cloud
      expect(content, contains('Web Application (Local by Default, Optional Cloud Sync)'));
      expect(content, contains('Local Guest Mode (Default)'));
      expect(content, contains('Optional Account & Cloud Sync (Opt-In Only)'));

      // Processors
      expect(content, contains('Supabase'));
      expect(content, contains('Resend'));

      // Rights and deletion
      expect(content, contains('Right to be Forgotten'));
      expect(content, contains('Delete Account'));
      expect(content, contains('cascades deletion'));
      expect(content, contains('Guest Data Is Sacred'));

      // Free tier notice
      expect(content, contains('Free Tier Service Notice'));
      expect(content, contains('Export JSON Backup'));
    });

    test('README.md contains mode-aware qualifiers and web cloud section', () {
      final file = File('README.md');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      expect(content, contains('Native Android and iOS builds are 100% offline-first'));
      expect(content, contains('Web runs locally by default with optional, opt-in cloud synchronization'));
      expect(content, contains('Privacy: Offline-First & Honest'));
      expect(content, contains('Web Cloud Synchronization & Data Sovereignty'));
      expect(content, contains('Cascading Account Deletion'));
      expect(content, contains('Free-Tier Periodic Backup Notice'));
    });
  });

  group('M5: Account Deletion Flow Tests', () {
    late SharedPreferences prefs;
    late MockAuthRepository mockAuthRepo;
    late MockSessionRepository mockSessionRepo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        AccountScope.activeScopeKey: 'user:user-del-test',
        'pageclock_web_sessions_v2_user_user-del-test': '["session_data"]',
        'pageclock_sync_meta_v1_user_user-del-test': '{"cursor": 42}',
      });
      prefs = await SharedPreferences.getInstance();
      mockAuthRepo = MockAuthRepository();
      mockSessionRepo = MockSessionRepository();
    });

    test('deleteAccount is blocked when stopwatch is running', () async {
      when(() => mockSessionRepo.saveSession(any())).thenAnswer((_) async {});
      when(() => mockSessionRepo.getActiveSession()).thenAnswer((_) async => null);
      when(() => mockAuthRepo.authStateChanges()).thenAnswer((_) => const Stream.empty());
      when(() => mockAuthRepo.currentUser).thenReturn(
        const AuthUser(id: 'user-del-test', email: 'test@example.com'),
      );

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          sessionRepositoryProvider.overrideWithValue(mockSessionRepo),
          authRepositoryProvider.overrideWithValue(mockAuthRepo),
        ],
      );

      final stopwatch = container.read(stopwatchProvider.notifier);
      await stopwatch.start(); // Start running timer

      final authController = container.read(authControllerProvider.notifier);
      final result = await authController.deleteAccount();

      expect(result, isFalse);
      expect(container.read(authControllerProvider).errorMessage, equals(AuthController.timerBlockedMessage));
      expect(container.read(accountScopeProvider).isUser, isTrue, reason: 'Scope must not change when blocked');

      await stopwatch.cancel();
      container.dispose();
    });

    test('deleteAccount purges local user partition, sync metadata, and reverts scope to guest', () async {
      when(() => mockAuthRepo.authStateChanges()).thenAnswer((_) => const Stream.empty());
      when(() => mockAuthRepo.currentUser).thenReturn(
        const AuthUser(id: 'user-del-test', email: 'test@example.com'),
      );
      when(() => mockAuthRepo.deleteAccount()).thenAnswer((_) async => true);

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          sessionRepositoryProvider.overrideWithValue(mockSessionRepo),
          authRepositoryProvider.overrideWithValue(mockAuthRepo),
        ],
      );

      // Verify initial state
      expect(prefs.containsKey('pageclock_web_sessions_v2_user_user-del-test'), isTrue);
      expect(prefs.containsKey('pageclock_sync_meta_v1_user_user-del-test'), isTrue);
      expect(container.read(accountScopeProvider).userId, equals('user-del-test'));

      final authController = container.read(authControllerProvider.notifier);
      final success = await authController.deleteAccount();

      expect(success, isTrue);
      verify(() => mockAuthRepo.deleteAccount()).called(1);

      // Assert user partition and sync metadata are wiped
      expect(prefs.containsKey('pageclock_web_sessions_v2_user_user-del-test'), isFalse);
      expect(prefs.containsKey('pageclock_sync_meta_v1_user_user-del-test'), isFalse);

      // Assert scope reverted to guest
      expect(container.read(accountScopeProvider).isGuest, isTrue);
      expect(prefs.getString(AccountScope.activeScopeKey), equals('guest'));

      container.dispose();
    });
  });
}
