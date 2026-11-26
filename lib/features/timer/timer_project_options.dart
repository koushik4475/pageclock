import '../../core/models/subject.dart';

/// New focus sessions offer only the built-in fallback and user-created
/// active subjects. Legacy preset labels (Coding, Reading, Deep Work, Study)
/// remain visible in historical session records but are no longer offered
/// as choices for new sessions.
List<String> buildTimerProjectOptions(Iterable<Subject> subjects) {
  final activeNames = subjects
      .where((subject) => !subject.archived)
      .map((subject) => subject.name.trim())
      .where((name) => name.isNotEmpty && name.toLowerCase() != 'general focus')
      .toSet();

  if (activeNames.isEmpty) return const ['General Focus'];

  final options = <String>{'General Focus', ...activeNames}.toList()
    ..sort((a, b) {
      if (a == 'General Focus') return -1;
      if (b == 'General Focus') return 1;
      return a.toLowerCase().compareTo(b.toLowerCase());
    });
  return List<String>.unmodifiable(options);
}
