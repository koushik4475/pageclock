import 'package:shared_preferences/shared_preferences.dart';

import 'subject_repository_contract.dart';
import 'web_subject_repository.dart';

SubjectRepository createSubjectRepository(
  SharedPreferences preferences, {
  required String storageKey,
  required bool isUser,
}) {
  return WebSubjectRepository(preferences, storageKey: storageKey);
}
