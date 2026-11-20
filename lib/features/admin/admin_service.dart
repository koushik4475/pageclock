import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/application/auth_controller.dart';

class AdminClient {
  final String id;
  final String email;
  final String name;
  final String? avatarUrl;
  final DateTime? createdAt;
  final DateTime? lastSignInAt;
  final DateTime? lastActiveAt;
  final String? signupCountryCode;
  final String? signupCountryName;
  final String authProvider;
  final int totalFocusMs;
  final int weekFocusMs;
  final int sessionCount;
  final int currentStreak;
  final int bestStreak;
  final Map<String, int> dailyFocusMs;

  const AdminClient({
    required this.id,
    required this.email,
    required this.name,
    required this.avatarUrl,
    required this.createdAt,
    required this.lastSignInAt,
    required this.lastActiveAt,
    required this.signupCountryCode,
    required this.signupCountryName,
    required this.authProvider,
    required this.totalFocusMs,
    required this.weekFocusMs,
    required this.sessionCount,
    required this.currentStreak,
    required this.bestStreak,
    required this.dailyFocusMs,
  });

  factory AdminClient.fromJson(Map<String, dynamic> json) => AdminClient(
        id: json['id'] as String,
        email: json['email'] as String? ?? '',
        name: json['name'] as String? ?? 'PageClock client',
        avatarUrl: json['avatarUrl'] as String?,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
        lastSignInAt: DateTime.tryParse(json['lastSignInAt'] as String? ?? ''),
        lastActiveAt: DateTime.tryParse(json['lastActiveAt'] as String? ?? ''),
        signupCountryCode: json['signupCountryCode'] as String?,
        signupCountryName: json['signupCountryName'] as String?,
        authProvider: (json['authProvider'] as String? ?? 'email').toLowerCase(),
        totalFocusMs: (json['totalFocusMs'] as num?)?.toInt() ?? 0,
        weekFocusMs: (json['weekFocusMs'] as num?)?.toInt() ?? 0,
        sessionCount: (json['sessionCount'] as num?)?.toInt() ?? 0,
        currentStreak: (json['currentStreak'] as num?)?.toInt() ?? 0,
        bestStreak: (json['bestStreak'] as num?)?.toInt() ?? 0,
        dailyFocusMs: (json['dailyFocusMs'] as Map? ?? {}).map(
          (key, value) => MapEntry(key.toString(), (value as num).toInt()),
        ),
      );
}

class AdminDailyPoint {
  final DateTime date;
  final int focusMs;
  const AdminDailyPoint(this.date, this.focusMs);
}

class AdminDashboardData {
  final int totalClients;
  final int activeToday;
  final int activeSevenDays;
  final int totalFocusMs;
  final int totalSessions;
  final int countriesReached;
  final int countryDetectedClients;
  final List<Map<String, dynamic>> countryDistribution;
  final List<AdminDailyPoint> dailyFocus;
  final List<AdminClient> clients;

  const AdminDashboardData({
    required this.totalClients,
    required this.activeToday,
    required this.activeSevenDays,
    required this.totalFocusMs,
    required this.totalSessions,
    required this.countriesReached,
    required this.countryDetectedClients,
    required this.countryDistribution,
    required this.dailyFocus,
    required this.clients,
  });

  factory AdminDashboardData.fromJson(Map<String, dynamic> json) {
    final summary = Map<String, dynamic>.from(json['summary'] as Map);
    return AdminDashboardData(
      totalClients: (summary['totalClients'] as num?)?.toInt() ?? 0,
      activeToday: (summary['activeToday'] as num?)?.toInt() ?? 0,
      activeSevenDays: (summary['activeSevenDays'] as num?)?.toInt() ?? 0,
      totalFocusMs: (summary['totalFocusMs'] as num?)?.toInt() ?? 0,
      totalSessions: (summary['totalSessions'] as num?)?.toInt() ?? 0,
      countriesReached: (summary['countriesReached'] as num?)?.toInt() ?? 0,
      countryDetectedClients: (summary['countryDetectedClients'] as num?)?.toInt() ?? 0,
      countryDistribution: (json['countryDistribution'] as List? ?? [])
          .map((item) => Map<String, dynamic>.from(item as Map)).toList(),
      dailyFocus: (json['dailyFocus'] as List? ?? []).map((item) {
        final point = Map<String, dynamic>.from(item as Map);
        return AdminDailyPoint(
          DateTime.parse(point['date'] as String),
          (point['focusMs'] as num?)?.toInt() ?? 0,
        );
      }).toList(),
      clients: (json['clients'] as List? ?? [])
          .map((item) => AdminClient.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
    );
  }
}

class AdminService {
  final SupabaseClient _client;
  AdminService(this._client);

  Future<bool> checkAccess() async {
    try {
      final response = await _client.functions.invoke(
        'admin-analytics',
        body: {'action': 'access'},
      );
      return response.status == 200 &&
          response.data is Map &&
          response.data['isAdmin'] == true;
    } on FunctionException catch (error) {
      if (error.status == 401 || error.status == 403) return false;
      rethrow;
    }
  }

  Future<AdminDashboardData> loadDashboard() async {
    final response = await _client.functions.invoke(
      'admin-analytics',
      body: {'action': 'dashboard'},
    );
    if (response.status != 200 || response.data is! Map) {
      throw StateError('Admin analytics could not be loaded.');
    }
    return AdminDashboardData.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }
}

final adminServiceProvider = Provider<AdminService>((ref) {
  return AdminService(Supabase.instance.client);
});

final adminAccessProvider = FutureProvider<bool>((ref) async {
  final userId = ref.watch(authControllerProvider.select((state) => state.user?.id));
  if (userId == null) return false;
  return ref.watch(adminServiceProvider).checkAccess();
});


final adminDashboardProvider = FutureProvider<AdminDashboardData>((ref) {
  return ref.watch(adminServiceProvider).loadDashboard();
});

String formatAdminDuration(int milliseconds) {
  final minutes = milliseconds ~/ 60000;
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;
  if (hours <= 0) return '${minutes}m';
  if (remainingMinutes == 0) return '${hours}h';
  return '${hours}h ${remainingMinutes}m';
}

String formatAdminAuthProvider(String provider) {
  return switch (provider.toLowerCase()) {
    'google' => 'Google SSO',
    'email' => 'Email OTP',
    'apple' => 'Apple',
    'github' => 'GitHub',
    '' => 'Unknown',
    _ => provider[0].toUpperCase() + provider.substring(1),
  };
}
