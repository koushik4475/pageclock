import 'package:flutter_test/flutter_test.dart';
import '../lib/features/admin/admin_service.dart';

void main() {
  group('AdminDashboardData country analytics', () {
    test('parses country summary and distribution', () {
      final data = AdminDashboardData.fromJson({
        'summary': {
          'totalClients': 3,
          'activeToday': 1,
          'activeSevenDays': 2,
          'totalFocusMs': 7200000,
          'totalSessions': 9,
          'countriesReached': 2,
          'countryDetectedClients': 2,
        },
        'countryDistribution': [
          {'countryCode': 'IN', 'countryName': 'India', 'clients': 1},
          {'countryCode': 'US', 'countryName': 'United States', 'clients': 1},
        ],
        'dailyFocus': [],
        'clients': [
          {
            'id': 'user-1',
            'email': 'reader@example.com',
            'name': 'Reader',
            'signupCountryCode': 'IN',
            'signupCountryName': 'India',
            'totalFocusMs': 120000,
            'weekFocusMs': 60000,
            'sessionCount': 2,
            'currentStreak': 1,
            'bestStreak': 2,
            'dailyFocusMs': {},
          },
        ],
      });

      expect(data.countriesReached, 2);
      expect(data.countryDetectedClients, 2);
      expect(data.countryDistribution.first['countryCode'], 'IN');
      expect(data.clients.single.signupCountryName, 'India');
    });

    test('older responses without country fields remain compatible', () {
      final data = AdminDashboardData.fromJson({
        'summary': {
          'totalClients': 0,
          'activeToday': 0,
          'activeSevenDays': 0,
          'totalFocusMs': 0,
          'totalSessions': 0,
        },
        'dailyFocus': [],
        'clients': [],
      });

      expect(data.countriesReached, 0);
      expect(data.countryDetectedClients, 0);
      expect(data.countryDistribution, isEmpty);
    });
  });
}
