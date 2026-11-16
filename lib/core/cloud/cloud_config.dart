import 'package:flutter/foundation.dart';

/// Configuration and safety guards for optional cloud authentication and sync.
///
/// Under the PageClock architecture:
/// - Cloud authentication is supported on Flutter Web and Android.
/// - iOS and desktop builds remain offline-first and do not initialize cloud services.
/// - The public project URL and publishable key are safe client configuration.
class CloudConfig {
  const CloudConfig._();

  /// Compile-time environment flag controlling cloud auth and sync.
  ///
  /// Defaults to `true` for the configured PageClock Supabase project. Can be
  /// disabled explicitly via `--dart-define=PAGECLOCK_CLOUD_AUTH_ENABLED=false`.
  static const bool authEnabled = bool.fromEnvironment(
    'PAGECLOCK_CLOUD_AUTH_ENABLED',
    defaultValue: true,
  );

  /// Supabase project URL passed at compile time via:
  /// `--dart-define=SUPABASE_URL=https://...`
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://xmtmubuoooctkxenwrqs.supabase.co',
  );

  /// Supabase publishable/anon key passed at compile time via:
  /// `--dart-define=SUPABASE_PUBLISHABLE_KEY=...`
  ///
  /// NEVER provide or pass a service_role key to the client application.
  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_N2WUZi7zM2wW6AfR7_CkuA_mvJs57zN',
  );

  /// Native callback registered in Supabase Auth URL Configuration and Android manifest.
  static const String nativeRedirectUri =
      'com.example.pageclock://login-callback';

  /// Pure, deterministic guard that evaluates whether cloud sync/auth is active.
  ///
  /// Returns `true` if and only if:
  /// 1. The current platform is Web or Android.
  /// 2. [flag] is `true`.
  /// 3. [url] is non-empty after trimming.
  /// 4. [key] is non-empty after trimming.
  static bool isEnabledFor({
    required bool isWeb,
    bool isAndroid = false,
    required bool flag,
    required String url,
    required String key,
  }) {
    if (!isWeb && !isAndroid) return false;
    if (!flag) return false;
    if (url.trim().isEmpty) return false;
    if (key.trim().isEmpty) return false;
    return true;
  }

  /// Runtime state for the current running application instance.
  static bool get isEnabled => isEnabledFor(
        isWeb: kIsWeb,
        isAndroid: !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
        flag: authEnabled,
        url: supabaseUrl,
        key: supabasePublishableKey,
      );
}
