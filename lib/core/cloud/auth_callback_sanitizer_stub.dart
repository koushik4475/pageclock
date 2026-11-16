/// Platform-independent stub for auth callback URL sanitizer.
/// On native/desktop/tests, URL manipulation is a no-op.

class AuthCallbackSanitizer {
  const AuthCallbackSanitizer._();

  /// Reads and cleans any error or access token from the URL fragment before
  /// Flutter router parses the hash as a route.
  static String? sanitizeFragment() {
    return null;
  }

  /// Removes PKCE authorization code (?code=...) from browser URL bar after exchange.
  static void cleanQueryParams() {}
}
