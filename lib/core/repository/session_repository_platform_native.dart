import 'package:shared_preferences/shared_preferences.dart';

import '../db/app_database.dart';

DriftSessionRepository createSessionRepository(
  SharedPreferences preferences, {
  String? storageKey,
  bool? isUser,
}) {
  final userId = isUser == true && storageKey != null
      ? storageKey.split('_user_').last
      : null;
  final databaseName = userId == null || userId.isEmpty
      ? 'pageclock.sqlite'
      : 'pageclock_user_${userId}.sqlite';
  return DriftSessionRepository(
    userId == null ? AppDatabase() : AppDatabase.forScope(databaseName),
  );
}
