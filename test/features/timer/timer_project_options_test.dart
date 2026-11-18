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

  test('preserves legacy choices until the first managed subject exists', () {
    expect(buildTimerProjectOptions(const []), legacyTimerProjectOptions);
  });

  test('offers active managed subjects and a single General Focus fallback', () {
    final options = buildTimerProjectOptions([
      subject('reading', 'Reading'),
      subject('research', 'Research'),
      subject('old', 'Archived', archived: true),
    ]);

    expect(options, ['General Focus', 'Reading', 'Research']);
    expect(options.where((name) => name == 'General Focus'), hasLength(1));
  });

  test('keeps General Focus as the only new-session choice when all subjects are archived', () {
    expect(
      buildTimerProjectOptions([
        subject('reading', 'Reading', archived: true),
      ]),
      ['General Focus'],
    );
  });
}
