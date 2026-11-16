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
  String? _storageIssue;

  static const defaultStorageKey = 'pageclock_subjects_v1_guest';

  WebSubjectRepository(
    this._prefs, {
    this.storageKey = defaultStorageKey,
  }) {
    _loadFromStorage();
  }

  @override
  String? get storageIssue => _storageIssue;

  void _loadFromStorage() {
    _subjects.clear();
    _storageIssue = null;
    final raw = _prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        throw const FormatException('Stored subjects must be a JSON list.');
      }

      // Decode into a temporary map. Never expose a partial snapshot or replace
      // the original payload when one row is malformed or has an unknown shape.
      final loaded = <String, Subject>{};
      for (var index = 0; index < decoded.length; index++) {
        final item = decoded[index];
        if (item is! Map) {
          throw FormatException('Stored subject at index $index is not an object.');
        }
        final subject = Subject.fromMap(Map<String, dynamic>.from(item));
        if (subject.id.trim().isEmpty ||
            subject.name.trim().isEmpty ||
            subject.color.trim().isEmpty) {
          throw FormatException('Stored subject at index $index has empty required fields.');
        }
        if (loaded.containsKey(subject.id)) {
          throw FormatException('Stored subjects contain duplicate ID "${subject.id}".');
        }
        loaded[subject.id] = subject;
      }
      _subjects.addAll(loaded);
    } catch (error) {
      _storageIssue =
          'Stored subjects could not be read. Existing data is preserved; repair or export the stored data before editing subjects.';
      debugPrint('[WebSubjectRepository] Could not load stored subjects (${error.runtimeType}).');
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

  void _ensureWritable() {
    final issue = _storageIssue;
    if (issue != null) {
      throw SubjectStorageCorruptionException(issue);
    }
  }

  Future<void> _commit() async {
    _ensureWritable();
    final payload = jsonEncode(
      _subjects.values.map((subject) => subject.toMap()).toList(),
    );
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
    _ensureWritable();
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
    _ensureWritable();
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
  Future<void> dispose() async {
    await _changes.close();
  }
}
