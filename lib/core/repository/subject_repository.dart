import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../account/account_scope.dart';
import '../models/subject.dart';
import '../settings/app_settings.dart';
import 'subject_repository_contract.dart';
import 'subject_repository_platform_stub.dart'
    if (dart.library.io) 'subject_repository_platform_native.dart' as platform;

export 'subject_repository_contract.dart';

final subjectRepositoryProvider = Provider<SubjectRepository>((ref) {
  final preferences = ref.watch(sharedPreferencesProvider);
  final scope = ref.watch(accountScopeProvider);
  final repository = platform.createSubjectRepository(
    preferences,
    storageKey: scope.subjectsStorageKey,
    isUser: scope.isUser,
  );
  ref.onDispose(() => unawaited(repository.dispose()));
  return repository;
});

/// All persisted subjects, including archived ones, for timer reconciliation.
final allSubjectsProvider = StreamProvider<List<Subject>>((ref) {
  final repository = ref.watch(subjectRepositoryProvider);
  return repository.watchSubjects(includeArchived: true);
});
