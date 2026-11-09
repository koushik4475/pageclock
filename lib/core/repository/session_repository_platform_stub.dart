import 'package:shared_preferences/shared_preferences.dart';

import 'web_session_repository.dart';

WebSessionRepository createSessionRepository(SharedPreferences preferences) {
  return WebSessionRepository(preferences);
}
