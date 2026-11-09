import 'package:shared_preferences/shared_preferences.dart';

import '../db/app_database.dart';
import 'session_repository.dart';

SessionRepository createSessionRepository(SharedPreferences preferences) {
  return DriftSessionRepository(AppDatabase());
}
