import 'dart:html' as html;

/// Web implementation of URL sanitizer for PKCE and OAuth callbacks.
///
/// In hash-routing mode, OAuth error fragments (e.g. #error=access_denied)
/// will cause Flutter's Navigator to crash or treat the error string as a route.
/// This sanitizer captures the fragment into an in-memory one-shot holder and
/// removes it from the browser address bar before Flutter starts.
class AuthCallbackSanitizer {
  const AuthCallbackSanitizer._();

  static String? _cachedFragment;

  /// Captures any error or token in the fragment and cleans it from the address bar.
  static String? sanitizeFragment() {
    if (_cachedFragment != null) return _cachedFragment;
    try {
      final hash = html.window.location.hash;
      if (hash.startsWith('#error') ||
          hash.startsWith('#access_token') ||
          hash.contains('error=') ||
          hash.contains('access_token=')) {
        _cachedFragment = hash.startsWith('#') ? hash.substring(1) : hash;
        final cleanUrl = '${html.window.location.pathname}${html.window.location.search}';
        html.window.history?.replaceState(null, '', cleanUrl);
        return _cachedFragment;
      }
    } catch (_) {
      // In case of restricted iframe/sandbox
    }
    return null;
  }

  /// Removes PKCE authorization code (?code=...) from browser URL bar after exchange.
  static void cleanQueryParams() {
    try {
      final location = html.window.location;
      final uri = Uri.parse(location.href);
      if (uri.queryParameters.containsKey('code') ||
          uri.queryParameters.containsKey('error') ||
          uri.queryParameters.containsKey('error_description')) {
        final queryParams = Map<String, String>.from(uri.queryParameters)
          ..remove('code')
          ..remove('error')
          ..remove('error_description')
          ..remove('error_code');
        final newUri = uri.replace(
          query: queryParams.isEmpty ? null : Uri(queryParameters: queryParams).query,
        );
        html.window.history?.replaceState(null, '', newUri.toString());
      }
    } catch (_) {
      // In case of restricted iframe/sandbox
    }
  }
}
