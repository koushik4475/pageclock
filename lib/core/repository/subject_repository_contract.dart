import 'dart:async';

import '../models/subject.dart';

/// Offline persistence contract for user-managed reading subjects.
abstract class SubjectRepository {
  /// Non-null when persisted web subject data could not be decoded safely.
  /// Implementations without a serialized web store always return null.
  String? get storageIssue;

  Future<List<Subject>> getAllSubjects({bool includeArchived = true});

  Stream<List<Subject>> watchSubjects({bool includeArchived = true});

  Future<void> saveSubject(Subject subject);

  Future<void> setArchived(String id, bool archived);

  Future<void> dispose();
}

/// Raised when persisted subject data is malformed and must not be overwritten.
class SubjectStorageCorruptionException implements Exception {
  final String message;

  const SubjectStorageCorruptionException(this.message);

  @override
  String toString() => message;
}

/// Raised when two active subjects would have the same case-insensitive name.
class SubjectNameConflictException implements Exception {
  final String name;

  const SubjectNameConflictException(this.name);

  @override
  String toString() => 'An active subject named "$name" already exists.';
}

String normalizeSubjectName(String name) {
  final normalized = name.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(name, 'name', 'Subject name cannot be empty.');
  }
  return normalized;
}

void ensureUniqueActiveSubjectName(
  Subject candidate,
  Iterable<Subject> existing,
) {
  if (candidate.archived) return;
  final normalized = candidate.name.trim().toLowerCase();
  final duplicate = existing.any(
    (other) =>
        other.id != candidate.id &&
        !other.archived &&
        other.name.trim().toLowerCase() == normalized,
  );
  if (duplicate) {
    throw SubjectNameConflictException(candidate.name.trim());
  }
}

/// Deterministic in-memory implementation used by tests and previews.
class InMemorySubjectRepository implements SubjectRepository {
  final Map<String, Subject> _subjects = {};
  final StreamController<void> _changes = StreamController<void>.broadcast();

  InMemorySubjectRepository([Iterable<Subject> initial = const []]) {
    for (final subject in initial) {
      _subjects[subject.id] = subject;
    }
  }

  @override
  String? get storageIssue => null;

  List<Subject> _snapshot({required bool includeArchived}) {
    final values = _subjects.values
        .where((subject) => includeArchived || !subject.archived)
        .toList()
      ..sort((a, b) {
        final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
        return byName != 0 ? byName : a.id.compareTo(b.id);
      });
    return values;
  }

  @override
  Future<List<Subject>> getAllSubjects({bool includeArchived = true}) async =>
      _snapshot(includeArchived: includeArchived);

  @override
  Stream<List<Subject>> watchSubjects({bool includeArchived = true}) {
    late final StreamController<List<Subject>> controller;
    StreamSubscription<void>? subscription;
    controller = StreamController<List<Subject>>(
      onListen: () {
        // Subscribe before emitting the initial snapshot so a write between
        // the first frame and the next stream event cannot be missed.
        subscription = _changes.stream.listen(
          (_) => controller.add(_snapshot(includeArchived: includeArchived)),
        );
        controller.add(_snapshot(includeArchived: includeArchived));
      },
      onCancel: () async {
        await subscription?.cancel();
      },
    );
    return controller.stream;
  }

  @override
  Future<void> saveSubject(Subject subject) async {
    final normalized = subject.copyWith(
      name: normalizeSubjectName(subject.name),
    );
    ensureUniqueActiveSubjectName(normalized, _subjects.values);
    _subjects[normalized.id] = normalized;
    _changes.add(null);
  }

  @override
  Future<void> setArchived(String id, bool archived) async {
    final existing = _subjects[id];
    if (existing == null) {
      throw StateError('Subject "$id" was not found.');
    }
    final updated = existing.copyWith(archived: archived);
    ensureUniqueActiveSubjectName(updated, _subjects.values);
    _subjects[id] = updated;
    _changes.add(null);
  }

  @override
  Future<void> dispose() async {
    await _changes.close();
  }
}
