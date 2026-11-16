export 'auth_callback_sanitizer_stub.dart'
    if (dart.library.html) 'auth_callback_sanitizer_web.dart';

/// Supported types of authentication callbacks.
enum AuthCallbackType {
  none,
  pkceCode,
  error,
  accessToken,
}

/// Structured outcome of parsing an incoming OAuth or OTP redirect URL.
class AuthCallbackResult {
  final AuthCallbackType type;
  final String? code;
  final String? error;
  final String? errorDescription;
  final String? accessToken;

  const AuthCallbackResult._({
    required this.type,
    this.code,
    this.error,
    this.errorDescription,
    this.accessToken,
  });

  const AuthCallbackResult.none()
      : this._(type: AuthCallbackType.none);

  const AuthCallbackResult.pkceCode({required String code})
      : this._(type: AuthCallbackType.pkceCode, code: code);

  const AuthCallbackResult.error({
    required String error,
    String? errorDescription,
  }) : this._(
          type: AuthCallbackType.error,
          error: error,
          errorDescription: errorDescription,
        );

  const AuthCallbackResult.accessToken({required String accessToken})
      : this._(type: AuthCallbackType.accessToken, accessToken: accessToken);

  bool get isSuccess => type == AuthCallbackType.pkceCode;
  bool get isError => type == AuthCallbackType.error;
  bool get isAccessToken => type == AuthCallbackType.accessToken;
  bool get isNone => type == AuthCallbackType.none;

  /// Whether the user intentionally cancelled or denied consent.
  bool get isCancelled {
    if (!isError) return false;
    final err = error?.toLowerCase() ?? '';
    final desc = errorDescription?.toLowerCase() ?? '';
    return err == 'access_denied' ||
        desc.contains('cancel') ||
        desc.contains('denied') ||
        desc.contains('closed');
  }

  /// Calm, non-technical, privacy-respecting message suitable for UI toasts/banners.
  String get calmErrorMessage {
    if (!isError) return '';
    if (isCancelled) {
      return 'Sign-in was cancelled.';
    }
    return 'Unable to complete sign-in. Please try again.';
  }

  @override
  String toString() {
    // SECURITY: Never include raw tokens or codes in debug/log outputs.
    switch (type) {
      case AuthCallbackType.pkceCode:
        return 'AuthCallbackResult.pkceCode(code: [REDACTED])';
      case AuthCallbackType.accessToken:
        return 'AuthCallbackResult.accessToken(token: [REDACTED])';
      case AuthCallbackType.error:
        return 'AuthCallbackResult.error(error: $error, description: $errorDescription)';
      case AuthCallbackType.none:
        return 'AuthCallbackResult.none()';
    }
  }
}

/// Parses an incoming OAuth redirect [Uri] and classifies its auth payload.
///
/// Supports query parameter codes (`?code=...`), query errors (`?error=...`),
/// fragment errors (`#error=access_denied&error_description=...`), and
/// fragment implicit tokens (`#access_token=...`).
/// An optional [fragmentOverride] can be passed if the fragment was already
/// captured and stripped from the browser URL prior to Flutter bootstrap.
AuthCallbackResult parseAuthCallback(Uri uri, {String? fragmentOverride}) {
  // 1. Check query parameters first
  final code = uri.queryParameters['code'];
  if (code != null && code.trim().isNotEmpty) {
    return AuthCallbackResult.pkceCode(code: code.trim());
  }

  final queryError = uri.queryParameters['error'];
  if (queryError != null && queryError.trim().isNotEmpty) {
    return AuthCallbackResult.error(
      error: queryError.trim(),
      errorDescription: uri.queryParameters['error_description']?.trim(),
    );
  }

  // 2. Check fragment (either passed directly or in uri.fragment)
  final rawFragment = fragmentOverride ?? uri.fragment;
  if (rawFragment.isNotEmpty) {
    final cleanFragment = rawFragment.startsWith('#')
        ? rawFragment.substring(1).trim()
        : rawFragment.trim();

    if (cleanFragment.isNotEmpty && cleanFragment.contains('=')) {
      try {
        final params = Uri.splitQueryString(cleanFragment);
        if (params.containsKey('error')) {
          return AuthCallbackResult.error(
            error: params['error'] ?? 'unknown_error',
            errorDescription: params['error_description'],
          );
        }
        if (params.containsKey('access_token')) {
          final token = params['access_token'];
          if (token != null && token.isNotEmpty) {
            return AuthCallbackResult.accessToken(accessToken: token);
          }
        }
      } catch (_) {
        // If fragment isn't query-encoded, ignore it
      }
    }
  }

  return const AuthCallbackResult.none();
}
