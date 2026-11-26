import 'package:flutter_test/flutter_test.dart';
import 'package:pageclock/core/models/subject.dart';
import 'package:pageclock/features/timer/timer_project_options.dart';

void main() {
  Subject subject(String id, String name, {bool archived = false}) => Subject(
        id: id,
        name: name,
        color: '#F97316',
        archived: archived,
      );

  test('offers only General Focus when no custom subjects exist', () {
    expect(buildTimerProjectOptions(const []), ['General Focus']);
  });

  test('offers General Focus and active user-created subjects only', () {
    final options = buildTimerProjectOptions([
      subject('reading', 'Reading'),
      subject('research', 'Research'),
      subject('old', 'Archived', archived: true),
    ]);

    expect(options, ['General Focus', 'Reading', 'Research']);
    expect(options, isNot(contains('Coding')));
    expect(options, isNot(contains('Deep Work')));
    expect(options, isNot(contains('Study')));
  });

  test('keeps General Focus as the only choice when all subjects are archived', () {
    expect(
      buildTimerProjectOptions([
        subject('reading', 'Reading', archived: true),
      ]),
      ['General Focus'],
    );
  });

  test('does not duplicate General Focus when a custom subject uses that name', () {
    expect(
      buildTimerProjectOptions([subject('general', 'General Focus')]),
      ['General Focus'],
    );
  });
}
