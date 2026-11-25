import '../../core/models/subject.dart';

const legacyTimerProjectOptions = <String>[
  'General Focus',
  'Coding',
  'Reading',
  'Deep Work',
  'Study',
];

/// Keeps the original project choices for existing installs until the user
/// creates their first managed subject. Once managed subjects exist, only
/// active subjects and the safe General Focus fallback are offered for new
/// sessions. Archived subjects remain available through historical entries.
List<String> buildTimerProjectOptions(Iterable<Subject> subjects) {
  final allSubjects = subjects.toList(growable: false);
  if (allSubjects.isEmpty) {
    return List<String>.unmodifiable(legacyTimerProjectOptions);
  }

  final activeNames = allSubjects
      .where((subject) => !subject.archived)
      .map((subject) => subject.name.trim())
      .where((name) => name.isNotEmpty)
      .toSet();

  if (activeNames.isEmpty) return const ['General Focus'];

  final options = <String>{'General Focus', ...activeNames}.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return options;
}
