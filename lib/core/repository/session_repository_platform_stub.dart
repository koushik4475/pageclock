import 'package:shared_preferences/shared_preferences.dart';

import 'session_repository.dart';
import 'web_session_repository.dart';

SessionRepository createSessionRepository(SharedPreferences preferences) {
  return WebSessionRepository(preferences);
}
