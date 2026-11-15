import 'package:shared_preferences/shared_preferences.dart';

import '../db/app_database.dart';

DriftSessionRepository createSessionRepository(
  SharedPreferences preferences, {
  String? storageKey,
  bool? isUser,
}) {
  return DriftSessionRepository(AppDatabase());
}
