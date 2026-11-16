import 'package:flutter_test/flutter_test.dart';
import 'package:pageclock/core/cloud/auth_callback.dart';

void main() {
  group('AuthCallback Parsing & Sanitization (§7.2)', () {
    test('parses PKCE authorization code from query parameters', () {
      final uri = Uri.parse('https://pageclock.pages.dev/?code=pkce_secret_auth_code_123');
      final result = parseAuthCallback(uri);

      expect(result.type, equals(AuthCallbackType.pkceCode));
      expect(result.isSuccess, isTrue);
      expect(result.code, equals('pkce_secret_auth_code_123'));
      expect(result.isError, isFalse);

      // Verify sensitive code is redacted from toString()
      expect(result.toString(), contains('[REDACTED]'));
      expect(result.toString(), isNot(contains('pkce_secret_auth_code_123')));
    });

    test('parses error and error_description from query parameters', () {
      final uri = Uri.parse(
        'https://pageclock.pages.dev/?error=access_denied&error_description=User+denied+the+request',
      );
      final result = parseAuthCallback(uri);

      expect(result.type, equals(AuthCallbackType.error));
      expect(result.isError, isTrue);
      expect(result.isSuccess, isFalse);
      expect(result.error, equals('access_denied'));
      expect(result.errorDescription, equals('User denied the request'));
      expect(result.isCancelled, isTrue);
      expect(result.calmErrorMessage, equals('Sign-in was cancelled.'));
    });

    test('parses error and error_description from URL fragment', () {
      final uri = Uri.parse(
        'https://pageclock.pages.dev/#error=access_denied&error_description=The+user+cancelled+OAuth',
      );
      final result = parseAuthCallback(uri);

      expect(result.type, equals(AuthCallbackType.error));
      expect(result.error, equals('access_denied'));
      expect(result.isCancelled, isTrue);
      expect(result.calmErrorMessage, equals('Sign-in was cancelled.'));
    });

    test('parses fragment override when URL fragment was already stripped by sanitizer', () {
      final uri = Uri.parse('https://pageclock.pages.dev/');
      const strippedFragment = 'error=access_denied&error_description=User+closed+window';
      final result = parseAuthCallback(uri, fragmentOverride: strippedFragment);

      expect(result.type, equals(AuthCallbackType.error));
      expect(result.error, equals('access_denied'));
      expect(result.isCancelled, isTrue);
      expect(result.calmErrorMessage, equals('Sign-in was cancelled.'));
    });

    test('parses implicit access token from fragment with strict redaction', () {
      final uri = Uri.parse(
        'https://pageclock.pages.dev/#access_token=sbp_secret_access_token_999&token_type=bearer',
      );
      final result = parseAuthCallback(uri);

      expect(result.type, equals(AuthCallbackType.accessToken));
      expect(result.accessToken, equals('sbp_secret_access_token_999'));

      // Verify token is redacted
      expect(result.toString(), contains('[REDACTED]'));
      expect(result.toString(), isNot(contains('sbp_secret_access_token_999')));
    });

    test('returns none for clean home or navigation URIs', () {
      final cleanUri = Uri.parse('https://pageclock.pages.dev/#/timer');
      final result = parseAuthCallback(cleanUri);

      expect(result.type, equals(AuthCallbackType.none));
      expect(result.isNone, isTrue);
      expect(result.isSuccess, isFalse);
      expect(result.isError, isFalse);
    });

    test('handles non-cancelled generic auth errors with calm copy', () {
      final uri = Uri.parse('https://pageclock.pages.dev/?error=server_error&error_description=Internal+failure');
      final result = parseAuthCallback(uri);

      expect(result.isError, isTrue);
      expect(result.isCancelled, isFalse);
      expect(result.calmErrorMessage, equals('Unable to complete sign-in. Please try again.'));
    });
  });
}
