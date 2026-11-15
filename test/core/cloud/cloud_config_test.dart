import 'package:flutter_test/flutter_test.dart';
import 'package:pageclock/core/cloud/cloud_config.dart';

void main() {
  group('CloudConfig safety guards', () {
    const validUrl = 'https://xyzcompany.supabase.co';
    const validKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';

    test('default compile-time values are disabled and empty', () {
      expect(CloudConfig.authEnabled, isFalse);
      expect(CloudConfig.supabaseUrl, isEmpty);
      expect(CloudConfig.supabasePublishableKey, isEmpty);
      expect(CloudConfig.isEnabled, isFalse);
    });

    test('isEnabledFor is strictly false when isWeb is false (native protection)', () {
      // Even with flag enabled and non-empty keys, native platform must never enable cloud
      expect(
        CloudConfig.isEnabledFor(
          isWeb: false,
          flag: true,
          url: validUrl,
          key: validKey,
        ),
        isFalse,
      );

      expect(
        CloudConfig.isEnabledFor(
          isWeb: false,
          flag: false,
          url: validUrl,
          key: validKey,
        ),
        isFalse,
      );

      expect(
        CloudConfig.isEnabledFor(
          isWeb: false,
          flag: true,
          url: '',
          key: '',
        ),
        isFalse,
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
