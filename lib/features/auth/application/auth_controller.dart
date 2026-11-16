import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState, AuthUser;
import '../../../core/account/account_scope.dart';
import '../../../core/cloud/auth_callback.dart';
import '../../../core/cloud/cloud_config.dart';
import '../../../core/engine/stopwatch_engine.dart';
import '../../../core/settings/app_settings.dart';
import '../data/auth_repository.dart';
import '../domain/auth_models.dart';

/// Provider for the [AuthRepository]. Returns null if cloud auth is disabled.
final authRepositoryProvider = Provider<AuthRepository?>((ref) {
  if (!CloudConfig.isEnabled) {
    return null;
  }
  try {
    // Lazy access to Supabase client
    final client = Supabase.instance.client;
    return SupabaseAuthRepository(client);
  } catch (_) {
    return null;
  }
});

/// Riverpod controller managing authentication operations, OTP flows, and scope transitions.
class AuthController extends StateNotifier<AuthState> {
  final Ref _ref;
  final AuthRepository? _authRepository;
  final SharedPreferences _prefs;
  StreamSubscription<AuthUser?>? _authSubscription;

  static const String otpCooldownKey = 'pageclock_otp_cooldown_deadline_ms';
  static const String timerBlockedMessage =
      'Stop or discard your running timer first.';

  AuthController({
    required Ref ref,
    required AuthRepository? authRepository,
    required SharedPreferences prefs,
  })  : _ref = ref,
        _authRepository = authRepository,
        _prefs = prefs,
        super(const AuthState.unauthenticated()) {
    _init();
  }

  void _init() {
    final currentUser = _authRepository?.currentUser;
    final savedDeadline = _prefs.getInt(otpCooldownKey);
    final now = DateTime.now().millisecondsSinceEpoch;

    if (currentUser != null) {
      state = AuthState.authenticated(currentUser);
    } else if (savedDeadline != null && savedDeadline > now) {
      state = AuthState.otpSent(
        email: '',
        cooldownDeadlineMs: savedDeadline,
      );
    }

    _authSubscription = _authRepository?.authStateChanges().listen((AuthUser? user) async {
      if (user != null) {
        if (!isTimerActive()) {
          await _activateUserScope(user.id);
        }
        state = AuthState.authenticated(user);
      } else {
        if (!isTimerActive()) {
          await _ref.read(accountScopeProvider.notifier).setGuest();
        }
        state = const AuthState.unauthenticated();
      }
    });
  }

  /// Switches to an isolated account partition. On native platforms, preserve
  /// completed guest sessions in the existing import queue before opening the
  /// account-specific Drift database. Running timers are never migrated.
  Future<void> _activateUserScope(String userId) async {
    final currentScope = _ref.read(accountScopeProvider);
    if (currentScope.isGuest && !kIsWeb) {
      final localRepository = _ref.read(sessionRepositoryProvider);
      final sessions = await localRepository.getAllSessions();
      final completed = sessions
          .where((session) => session.endedAtUtc != null)
          .map((session) => session.toMap())
          .toList();
      if (completed.isNotEmpty) {
        await _prefs.setString(
          AccountScope.guestSessionsKey,
          jsonEncode(completed),
        );
      } else {
        await _prefs.remove(AccountScope.guestSessionsKey);
      }
    }
    await _ref.read(accountScopeProvider.notifier).setUser(userId);
  }

  /// Evaluates whether the stopwatch is currently active (running or paused).
  ///
  /// Invariant (§7.3): Scope must never change while a timer is active.
  bool isTimerActive() {
    final status = _ref.read(stopwatchProvider).status;
    return status != StopwatchStatus.idle;
  }

  /// Sends a 6-digit OTP code to [email].
  Future<bool> sendOtp(String email) async {
    if (isTimerActive()) {
      state = const AuthState.error(timerBlockedMessage);
      return false;
    }

    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty || !trimmedEmail.contains('@')) {
      state = const AuthState.error('Please enter a valid email address.');
      return false;
    }

    if (_authRepository == null) {
      state = const AuthState.error('Cloud authentication is not enabled.');
      return false;
    }

    state = AuthState.loading(pendingEmail: trimmedEmail);
    try {
      await _authRepository.signInWithOtp(trimmedEmail);

      final deadline = DateTime.now().millisecondsSinceEpoch + 60000;
      await _prefs.setInt(otpCooldownKey, deadline);

      state = AuthState.otpSent(
        email: trimmedEmail,
        cooldownDeadlineMs: deadline,
      );
      return true;
    } catch (e) {
      final msg = _mapAuthError(e);
      state = AuthState.error(msg, pendingEmail: trimmedEmail);
      return false;
    }
  }

  /// Verifies a 6-digit OTP code.
  Future<bool> verifyOtp(String token) async {
    if (isTimerActive()) {
      state = const AuthState.error(timerBlockedMessage);
      return false;
    }

    final email = state.emailPendingOtp;
    if (email == null || email.isEmpty) {
      state = const AuthState.error('No pending email verification.');
      return false;
    }

    if (_authRepository == null) {
      state = const AuthState.error('Cloud authentication is not enabled.');
      return false;
    }

    state = AuthState.loading(pendingEmail: email);
    try {
      final user = await _authRepository.verifyOtp(
        email: email,
        token: token.trim(),
      );

      if (user != null) {
        await _prefs.remove(otpCooldownKey);
        await _activateUserScope(user.id);
        AuthCallbackSanitizer.cleanQueryParams();
        state = AuthState.authenticated(user);
        return true;
      } else {
        state = const AuthState.error('Invalid verification code.');
        return false;
      }
    } catch (e) {
      final msg = _mapAuthError(e);
      state = AuthState.error(msg, pendingEmail: email);
      return false;
    }
  }

  /// Initiates Google OAuth redirect flow with PKCE.
  Future<bool> signInWithGoogle() async {
    if (isTimerActive()) {
      state = const AuthState.error(timerBlockedMessage);
      return false;
    }

    if (_authRepository == null) {
      state = const AuthState.error('Cloud authentication is not enabled.');
      return false;
    }

    state = const AuthState.loading();
    try {
      await _authRepository.signInWithGoogle();
      return true;
    } catch (e) {
      final msg = _mapAuthError(e);
      state = AuthState.error(msg);
      return false;
    }
  }

  /// Signs out of current account and switches to guest scope.
  Future<bool> signOut() async {
    if (isTimerActive()) {
      state = const AuthState.error(timerBlockedMessage);
      return false;
    }

    state = const AuthState.loading();
    try {
      await _authRepository?.signOut();
      await _ref.read(accountScopeProvider.notifier).setGuest();
      state = const AuthState.unauthenticated();
      return true;
    } catch (e) {
      final msg = _mapAuthError(e);
      state = AuthState.error(msg);
      return false;
    }
  }

  /// Deletes the authenticated account and purges local user partition data.
  Future<bool> deleteAccount() async {
    if (isTimerActive()) {
      state = const AuthState.error(timerBlockedMessage);
      return false;
    }

    final currentUser = state.user ?? _authRepository?.currentUser;
    if (currentUser == null) return false;

    state = const AuthState.loading();
    try {
      final deleted = await _authRepository?.deleteAccount() ?? false;
      if (deleted) {
        // Wipe local user partition and sync metadata
        await _prefs.remove(AccountScope.userSessionsKey(currentUser.id));
        await _prefs.remove(AccountScope.syncMetaKey(currentUser.id));
        await _ref.read(accountScopeProvider.notifier).setGuest();
        state = const AuthState.unauthenticated();
        return true;
      } else {
        state = const AuthState.error('Could not delete account. Please try again.');
        return false;
      }
    } catch (e) {
      final msg = _mapAuthError(e);
      state = AuthState.error(msg);
      return false;
    }
  }

  /// Maps backend exception details to calm, user-safe copy.
  String _mapAuthError(dynamic e) {
    final str = e.toString().toLowerCase();
    if (str.contains('over_email_send_rate_limit') ||
        str.contains('rate limit') ||
        str.contains('too many requests')) {
      return 'Too many login attempts. Please wait a few minutes before trying again.';
    }
    if (str.contains('otp_expired') || str.contains('expired')) {
      return 'The code has expired. Please request a new code.';
    }
    if (str.contains('invalid') || str.contains('token')) {
      return 'The code entered is invalid. Please try again.';
    }
    return 'Authentication could not be completed. Please try again.';
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

/// Provider for [AuthController].
final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return AuthController(
    ref: ref,
    authRepository: repo,
    prefs: prefs,
  );
});
