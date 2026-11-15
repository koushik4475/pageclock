import 'package:shared_preferences/shared_preferences.dart';

import 'web_session_repository.dart';

WebSessionRepository createSessionRepository(
  SharedPreferences preferences, {
  String? storageKey,
  bool? isUser,
}) {
  return WebSessionRepository(
    preferences,
    storageKey: storageKey ?? WebSessionRepository.defaultStorageKey,
    isUser: isUser,
  );
}
