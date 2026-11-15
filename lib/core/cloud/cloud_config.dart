import 'package:flutter/foundation.dart';

/// Configuration and safety guards for optional cloud authentication and sync.
///
/// Under the PageClock architecture:
/// - Cloud authentication is restricted to Flutter Web only.
/// - Native builds (Android/iOS) remain 100% offline-first and never initialize cloud services.
/// - Feature flag [authEnabled] defaults to `false`.
class CloudConfig {
  const CloudConfig._();

  /// Compile-time environment flag controlling cloud auth and sync.
  ///
  /// Defaults to `false`. Must be explicitly enabled via:
  /// `--dart-define=PAGECLOCK_CLOUD_AUTH_ENABLED=true`
  static const bool authEnabled = bool.fromEnvironment(
    'PAGECLOCK_CLOUD_AUTH_ENABLED',
    defaultValue: false,
  );

  /// Supabase project URL passed at compile time via:
  /// `--dart-define=SUPABASE_URL=https://...`
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  /// Supabase publishable/anon key passed at compile time via:
  /// `--dart-define=SUPABASE_PUBLISHABLE_KEY=...`
  ///
  /// NEVER provide or pass a service_role key to the client application.
  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: '',
  );

  /// Pure, deterministic guard that evaluates whether cloud sync/auth is active.
  ///
  /// Returns `true` if and only if:
  /// 1. [isWeb] is `true` (native builds MUST evaluate to false).
  /// 2. [flag] is `true`.
  /// 3. [url] is non-empty after trimming.
  /// 4. [key] is non-empty after trimming.
  static bool isEnabledFor({
    required bool isWeb,
    required bool flag,
    required String url,
    required String key,
  }) {
    if (!isWeb) return false;
    if (!flag) return false;
    if (url.trim().isEmpty) return false;
    if (key.trim().isEmpty) return false;
    return true;
  }

  /// Runtime state for the current running application instance.
  static bool get isEnabled => isEnabledFor(
        isWeb: kIsWeb,
        flag: authEnabled,
        url: supabaseUrl,
        key: supabasePublishableKey,
      );
}
