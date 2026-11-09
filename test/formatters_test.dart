import 'package:flutter_test/flutter_test.dart';
import 'package:pageclock/core/format/formatters.dart';

void main() {
  group('AppFormatters', () {
    test('formats supported date patterns', () {
      final date = DateTime(2026, 11, 9);
      expect(AppFormatters.formatDate(date, 'YYYY-MM-DD'), '2026-11-09');
      expect(AppFormatters.formatDate(date, 'MM/DD/YYYY'), '11/09/2026');
      expect(AppFormatters.formatDate(date, 'DD/MM/YYYY'), '09/11/2026');
    });

    test('respects 12-hour and 24-hour clock preferences', () {
      final time = DateTime(2026, 11, 9, 17, 5);
      expect(AppFormatters.formatTime(time, true), '17:05');
      expect(AppFormatters.formatTime(time, false), '05:05 PM');
    });

    test('formats durations in digital and human styles', () {
      expect(
        AppFormatters.formatDuration(3723000, format: 'digital'),
        '01:02:03',
      );
      expect(
        AppFormatters.formatDuration(3723000, format: 'human'),
        '1h 2m',
      );
      expect(
        AppFormatters.formatDuration(45000, format: 'human'),
        '45s',
      );
    });
  });
}
