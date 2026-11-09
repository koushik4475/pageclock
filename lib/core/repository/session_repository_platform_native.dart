import 'package:shared_preferences/shared_preferences.dart';

import '../db/app_database.dart';

DriftSessionRepository createSessionRepository(
  SharedPreferences preferences,
) {
  return DriftSessionRepository(AppDatabase());
}
