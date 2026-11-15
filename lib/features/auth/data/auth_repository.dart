import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../domain/auth_models.dart';

/// Abstract contract for authentication operations.
/// Interface decouples presentation and application logic from Supabase SDK.
abstract class AuthRepository {
  Future<void> signInWithOtp(String email);

  Future<AuthUser?> verifyOtp({
    required String email,
    required String token,
  });

  Future<void> signInWithGoogle({String? redirectTo});

  Future<void> signOut();

  Future<bool> deleteAccount();

  AuthUser? get currentUser;

  Stream<AuthUser?> authStateChanges();
}

/// Production implementation of [AuthRepository] backed by Supabase.
class SupabaseAuthRepository implements AuthRepository {
  final sb.SupabaseClient _client;

  SupabaseAuthRepository(this._client);

  @override
  Future<void> signInWithOtp(String email) async {
    await _client.auth.signInWithOtp(
      email: email.trim(),
      shouldCreateUser: true,
    );
  }

  @override
  Future<AuthUser?> verifyOtp({
    required String email,
    required String token,
  }) async {
    final response = await _client.auth.verifyOTP(
      email: email.trim(),
      token: token.trim(),
      type: sb.OtpType.email,
    );

    if (response.user != null) {
      return AuthUser.fromSupabaseUser(response.user!);
    }
    return null;
  }

  @override
  Future<void> signInWithGoogle({String? redirectTo}) async {
    final effectiveRedirect = redirectTo ?? '${Uri.base.origin}/';
    await _client.auth.signInWithOAuth(
      sb.OAuthProvider.google,
      redirectTo: effectiveRedirect,
      authScreenLaunchMode: sb.LaunchMode.platformDefault,
    );
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  @override
  Future<bool> deleteAccount() async {
    final response = await _client.functions.invoke('delete-account');
    if (response.status == 200) {
      await signOut();
      return true;
    }
    return false;
  }

  @override
  AuthUser? get currentUser {
    final user = _client.auth.currentUser;
    return user != null ? AuthUser.fromSupabaseUser(user) : null;
  }

  @override
  Stream<AuthUser?> authStateChanges() {
    return _client.auth.onAuthStateChange.map((data) {
      final user = data.session?.user;
      return user != null ? AuthUser.fromSupabaseUser(user) : null;
    });
  }
}
