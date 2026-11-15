/// Authenticated user representation.
class AuthUser {
  final String id;
  final String email;
  final String? displayName;
  final String? avatarUrl;

  const AuthUser({
    required this.id,
    required this.email,
    this.displayName,
    this.avatarUrl,
  });

  factory AuthUser.fromSupabaseUser(dynamic user) {
    final metadata = (user.userMetadata as Map<String, dynamic>?) ?? {};
    return AuthUser(
      id: user.id as String,
      email: (user.email as String?) ?? '',
      displayName: (metadata['full_name'] as String?) ??
          (metadata['name'] as String?) ??
          (metadata['display_name'] as String?),
      avatarUrl: (metadata['avatar_url'] as String?) ??
          (metadata['picture'] as String?),
    );
  }
}

/// UI-facing authentication flow state.
enum AuthUiStatus {
  unauthenticated,
  loading,
  otpSent,
  authenticated,
  error,
}

/// Comprehensive auth state for Riverpod.
class AuthState {
  final AuthUiStatus status;
  final AuthUser? user;
  final String? emailPendingOtp;
  final String? errorMessage;
  final int? otpCooldownDeadlineMs;

  const AuthState({
    required this.status,
    this.user,
    this.emailPendingOtp,
    this.errorMessage,
    this.otpCooldownDeadlineMs,
  });

  const AuthState.unauthenticated()
      : this(status: AuthUiStatus.unauthenticated);

  const AuthState.loading({String? pendingEmail})
      : this(status: AuthUiStatus.loading, emailPendingOtp: pendingEmail);

  const AuthState.otpSent({
    required String email,
    required int cooldownDeadlineMs,
  }) : this(
          status: AuthUiStatus.otpSent,
          emailPendingOtp: email,
          otpCooldownDeadlineMs: cooldownDeadlineMs,
        );

  const AuthState.authenticated(AuthUser user)
      : this(status: AuthUiStatus.authenticated, user: user);

  const AuthState.error(String message, {String? pendingEmail})
      : this(
          status: AuthUiStatus.error,
          errorMessage: message,
          emailPendingOtp: pendingEmail,
        );

  bool get isAuthenticated => status == AuthUiStatus.authenticated;
  bool get isLoading => status == AuthUiStatus.loading;
  bool get isOtpSent => status == AuthUiStatus.otpSent;
  bool get hasError => status == AuthUiStatus.error;

  /// Remaining cooldown seconds before a new OTP can be requested.
  int get remainingCooldownSeconds {
    if (otpCooldownDeadlineMs == null) return 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final diffMs = otpCooldownDeadlineMs! - now;
    return diffMs > 0 ? (diffMs / 1000).ceil() : 0;
  }
}
