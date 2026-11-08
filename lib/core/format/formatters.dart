import 'package:intl/intl.dart';

class AppFormatters {
  static String formatDate(DateTime dt, String formatPattern) {
    switch (formatPattern) {
      case 'MM/DD/YYYY':
        return DateFormat('MM/dd/yyyy').format(dt);
      case 'DD/MM/YYYY':
        return DateFormat('dd/MM/yyyy').format(dt);
      case 'YYYY-MM-DD':
      default:
        return DateFormat('yyyy-MM-dd').format(dt);
    }
  }

  static String formatTime(DateTime dt, bool use24Hour) {
    if (use24Hour) {
      return DateFormat('HH:mm').format(dt);
    } else {
      return DateFormat('hh:mm a').format(dt);
    }
  }

  static String formatDuration(int durationMs, {String format = 'digital'}) {
    final totalSeconds = (durationMs / 1000).round();
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (format == 'human') {
      if (hours > 0) {
        return '${hours}h ${minutes}m';
      } else if (minutes > 0) {
        return '${minutes}m ${seconds}s';
      } else {
        return '${seconds}s';
      }
    }

    // Default digital
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
  }

  static String formatHoursFraction(double hours) {
    final h = hours.floor();
    final m = ((hours - h) * 60).round();
    if (h > 0) {
      return '${h}h ${m}m';
    }
    return '${m}m';
  }
}
