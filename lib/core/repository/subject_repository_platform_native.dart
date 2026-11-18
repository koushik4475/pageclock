import 'package:shared_preferences/shared_preferences.dart';

import '../db/app_database.dart';
import 'drift_subject_repository.dart';
import 'subject_repository_contract.dart';

SubjectRepository createSubjectRepository(
  SharedPreferences preferences, {
  required String storageKey,
  required bool isUser,
}) {
  final userId = isUser ? storageKey.split('_user_').last : null;
  final databaseName = userId == null || userId.isEmpty
      ? 'pageclock.sqlite'
      : 'pageclock_user_${userId}.sqlite';
  final database = userId == null || userId.isEmpty
      ? AppDatabase()
      : AppDatabase.forScope(databaseName);
  return DriftSubjectRepository(database);
}
