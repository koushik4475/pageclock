import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pageclock/core/cloud/cloud_config.dart';

void main() {
  group('CloudConfig safety guards', () {
    const validUrl = 'https://xyzcompany.supabase.co';
    const validKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';

    testWidgets('default compile-time values point to the configured public project', (tester) async {
      expect(CloudConfig.authEnabled, isTrue);
      expect(CloudConfig.supabaseUrl, startsWith('https://'));
      expect(CloudConfig.supabasePublishableKey, startsWith('sb_publishable_'));
      // The host test runner is not Web or Android.
      expect(CloudConfig.isEnabled, isFalse);
    }, variant: TargetPlatformVariant.only(TargetPlatform.linux));

    test('unsupported native platforms remain disabled', () {
      // iOS and desktop remain offline-first.
      expect(
        CloudConfig.isEnabledFor(
          isWeb: false,
          isAndroid: false,
          flag: true,
          url: validUrl,
          key: validKey,
        ),
        isFalse,
      );

      expect(
        CloudConfig.isEnabledFor(
          isWeb: false,
          isAndroid: false,
          flag: false,
          url: validUrl,
          key: validKey,
        ),
        isFalse,
      );

      expect(
        CloudConfig.isEnabledFor(
          isWeb: false,
          isAndroid: false,
          flag: true,
          url: '',
          key: '',
        ),
        isFalse,
      );
    });

    test('Android is enabled when the flag and public project configuration are present', () {
      expect(
        CloudConfig.isEnabledFor(
          isWeb: false,
          isAndroid: true,
          flag: true,
          url: validUrl,
          key: validKey,
        ),
        isTrue,
      );
    });

    test('isEnabledFor is false when flag is false, even on web with valid credentials', () {
      expect(
        CloudConfig.isEnabledFor(
          isWeb: true,
          flag: false,
          url: validUrl,
          key: validKey,
        ),
        isFalse,
      );
    });

    test('isEnabledFor is false when url or key is empty or whitespace', () {
      expect(
        CloudConfig.isEnabledFor(
          isWeb: true,
          flag: true,
          url: '',
          key: validKey,
        ),
        isFalse,
      );

      expect(
        CloudConfig.isEnabledFor(
          isWeb: true,
          flag: true,
          url: '   ',
          key: validKey,
        ),
        isFalse,
      );

      expect(
        CloudConfig.isEnabledFor(
          isWeb: true,
          flag: true,
          url: validUrl,
          key: '',
        ),
        isFalse,
      );

      expect(
        CloudConfig.isEnabledFor(
          isWeb: true,
          flag: true,
          url: validUrl,
          key: '   ',
        ),
        isFalse,
      );
    });

    test('isEnabledFor is true only when isWeb, flag is true, and credentials are valid', () {
      expect(
        CloudConfig.isEnabledFor(
          isWeb: true,
          flag: true,
          url: validUrl,
          key: validKey,
        ),
        isTrue,
      );
    });
  });
}
