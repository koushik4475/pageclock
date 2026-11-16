import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/subject.dart';
import 'subject_repository_contract.dart';

/// SharedPreferences-backed subject storage for Flutter Web.
///
/// Guest and signed-in users receive separate keys. Writes roll back the
/// in-memory cache if browser storage rejects the update.
class WebSubjectRepository implements SubjectRepository {
  final SharedPreferences _prefs;
  final String storageKey;
  final Map<String, Subject> _subjects = {};
  final StreamController<void> _changes = StreamController<void>.broadcast();

  static const defaultStorageKey = 'pageclock_subjects_v1_guest';

  WebSubjectRepository(
    this._prefs, {
    this.storageKey = defaultStorageKey,
  }) {
    _loadFromStorage();
  }

  void _loadFromStorage() {
    _subjects.clear();
    final raw = _prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        throw const FormatException('Subject backup must be a JSON list.');
      }
      for (final item in decoded) {
        if (item is! Map) continue;
        try {
          final subject = Subject.fromMap(Map<String, dynamic>.from(item));
          _subjects[subject.id] = subject;
        } catch (error) {
          debugPrint('[WebSubjectRepository] Skipping invalid subject: $error');
        }
      }
    } catch (error) {
      debugPrint('[WebSubjectRepository] Could not load subjects: $error');
    }
  }

  Future<void> reloadFromStorage() async {
    await _prefs.reload();
    _loadFromStorage();
    _changes.add(null);
  }

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

  Future<void> _commit() async {
    final payload = jsonEncode(_subjects.values.map((subject) => subject.toMap()).toList());
    final saved = await _prefs.setString(storageKey, payload);
    if (!saved) {
      throw StateError('Browser storage rejected the subject update.');
    }
    _changes.add(null);
  }

  @override
  Future<List<Subject>> getAllSubjects({bool includeArchived = true}) async =>
      _snapshot(includeArchived: includeArchived);

  @override
  Stream<List<Subject>> watchSubjects({bool includeArchived = true}) async* {
    yield _snapshot(includeArchived: includeArchived);
    await for (final _ in _changes.stream) {
      yield _snapshot(includeArchived: includeArchived);
    }
  }

  @override
  Future<void> saveSubject(Subject subject) async {
    final normalized = subject.copyWith(
      name: normalizeSubjectName(subject.name),
    );
    ensureUniqueActiveSubjectName(normalized, _subjects.values);
    final previous = _subjects[normalized.id];
    _subjects[normalized.id] = normalized;
    try {
      await _commit();
    } catch (_) {
      if (previous == null) {
        _subjects.remove(normalized.id);
      } else {
        _subjects[normalized.id] = previous;
      }
      rethrow;
    }
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
    try {
      await _commit();
    } catch (_) {
      _subjects[id] = existing;
      rethrow;
    }
  }

  @override
  Future<void> dispose() => _changes.close();
}
