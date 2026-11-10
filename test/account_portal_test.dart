import 'package:flutter_test/flutter_test.dart';
import 'package:pageclock/features/account/account_portal.dart';

void main() {
  test('Supabase is disabled unless both public settings are supplied', () {
    expect(isSupabaseConfigured, isFalse);
  });
}
