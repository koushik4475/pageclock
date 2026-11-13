import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Offline clock-face renderer shared by the fullscreen clock and Clock Studio.
class ClockFaceView extends StatelessWidget {
  final String styleId, leftText, rightText, secondsText;
  final String? badge;
  final Color accentColor;
  final bool showSeconds, showDate, isDark, compact;
  final DateTime date;

  const ClockFaceView({
    super.key, required this.styleId, required this.leftText,
    required this.rightText, required this.secondsText, required this.badge,
    required this.accentColor, required this.showSeconds, required this.showDate,
    required this.date, required this.isDark, this.compact = false,
  });

  static const styleIds = <String>[
    'mac_flip', 'nixie', 'dot_matrix', 'lcd', 'neon',
    'terminal', 'gradient', 'analog', 'editorial', 'binary',
  ];

  static String labelFor(String id) => switch (id) {
    'mac_flip' => 'macOS Flip',
    'nixie' => 'Nixie Tube',
    'dot_matrix' => 'Dot Matrix',
    'lcd' => 'Retro LCD',
    'neon' => 'Neon Glow',
    'terminal' => 'Terminal',
    'gradient' => 'Aurora',
    'analog' => 'Analog',
    'editorial' => 'Editorial',
    'binary' => 'Binary',
    _ => 'macOS Flip',
  };

  static Color colorFromHex(String value) {
    final parsed = int.tryParse(value.replaceFirst('#', ''), radix: 16);
    return Color(0xFF000000 | (parsed ?? 0xFFF5A623));
  }

  @override
  Widget build(BuildContext context) {
    final time = leftText + ':' + rightText;
    final dateLabel = _weekday(date.weekday) + '  ' + date.day.toString().padLeft(2, '0') + ' ' + _month(date.month);
    final background = switch (styleId) {
      'lcd' => const Color(0xFFB6C58A),
      'gradient' => const Color(0xFF101A36),
      'neon' => const Color(0xFF130B25),
      'editorial' => const Color(0xFFF0EBDD),
      'terminal' || 'binary' => const Color(0xFF050A08),
      _ => const Color(0xFF08090D),
    };
    final foreground = switch (styleId) {
      'lcd' => const Color(0xFF17220E),
      'editorial' => const Color(0xFF202020),
      'terminal' || 'binary' => const Color(0xFF63F5A5),
      'nixie' => const Color(0xFFFFA34A),
      _ => Colors.white,
    };
    final displayTime = showSeconds ? time + ':' + secondsText : time;
    final size = compact ? 25.0 : 76.0;
    Widget face;

    switch (styleId) {
      case 'analog':
        face = AspectRatio(
          aspectRatio: 1,
          child: CustomPaint(painter: _AnalogClockPainter(date: date, foreground: foreground, accent: accentColor)),
        );
      case 'binary':
        face = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('HOUR  ' + date.hour.toRadixString(2).padLeft(5, '0'), style: TextStyle(color: foreground, fontFamily: 'monospace', fontSize: compact ? 10 : 20)),
            const SizedBox(height: 8),
            Text('MIN   ' + date.minute.toRadixString(2).padLeft(6, '0'), style: TextStyle(color: foreground, fontFamily: 'monospace', fontSize: compact ? 10 : 20)),
          ],
        );
      case 'editorial':
        face = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(leftText, style: TextStyle(color: foreground, fontSize: compact ? 30 : 100, fontWeight: FontWeight.w300, height: .95)),
            Text(rightText, style: TextStyle(color: foreground, fontSize: compact ? 30 : 100, fontWeight: FontWeight.w800, height: .95)),
          ],
        );
      case 'mac_flip':
        face = Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _flipCard(leftText, foreground, compact),
            Padding(padding: EdgeInsets.symmetric(horizontal: compact ? 3 : 12), child: Text(':', style: TextStyle(color: foreground, fontSize: compact ? 22 : 72))),
            _flipCard(rightText, foreground, compact),
          ],
        );
      default:
        final glow = styleId == 'nixie' || styleId == 'neon';
        face = Text(
          displayTime,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: styleId == 'dot_matrix' ? accentColor : foreground,
            fontSize: size,
            fontWeight: FontWeight.w800,
            fontFamily: styleId == 'terminal' || styleId == 'lcd' || styleId == 'dot_matrix' ? 'monospace' : null,
            letterSpacing: styleId == 'dot_matrix' ? (compact ? 1 : 7) : (compact ? -1 : -4),
            shadows: glow ? [Shadow(color: accentColor, blurRadius: compact ? 7 : 28)] : null,
          ),
        );
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 8 : 20),
      decoration: BoxDecoration(
        color: styleId == 'gradient' || styleId == 'neon' ? null : background,
        gradient: styleId == 'gradient'
            ? const LinearGradient(colors: [Color(0xFF111C3D), Color(0xFF39235E), Color(0xFF0C4B5A)], begin: Alignment.topLeft, end: Alignment.bottomRight)
            : styleId == 'neon'
                ? const LinearGradient(colors: [Color(0xFF1C0B32), Color(0xFF070A18)], begin: Alignment.topLeft, end: Alignment.bottomRight)
                : null,
        borderRadius: BorderRadius.circular(compact ? 10 : 28),
        border: Border.all(color: foreground.withOpacity(.16)),
        boxShadow: styleId == 'mac_flip' || styleId == 'nixie'
            ? [BoxShadow(color: Colors.black.withOpacity(.35), blurRadius: compact ? 6 : 28, offset: Offset(0, compact ? 2 : 12))]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badge != null && !compact) Text(badge!, style: TextStyle(color: foreground.withOpacity(.6), fontSize: 12, letterSpacing: 3)),
          if (badge != null && !compact) const SizedBox(height: 12),
          if (styleId == 'dot_matrix')
            Wrap(alignment: WrapAlignment.center, children: displayTime.split('').map((c) => Text(c, style: TextStyle(color: accentColor, fontSize: compact ? 24 : 76, fontFamily: 'monospace', fontWeight: FontWeight.w900, shadows: [Shadow(color: accentColor, blurRadius: compact ? 3 : 12)]))).toList())
          else
            face,
          if (showDate && !compact) ...[
            const SizedBox(height: 18),
            Text(dateLabel, style: TextStyle(color: foreground.withOpacity(.7), letterSpacing: 2, fontSize: 13)),
          ],
          if (showSeconds && styleId == 'mac_flip' && !compact)
            Padding(padding: const EdgeInsets.only(top: 12), child: Text(secondsText, style: TextStyle(color: accentColor, fontSize: 24))),
        ],
      ),
    );
  }

  Widget _flipCard(String value, Color foreground, bool compact) => Container(
    width: compact ? 48 : 160,
    height: compact ? 48 : 170,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: const Color(0xFF17191F),
      borderRadius: BorderRadius.circular(compact ? 7 : 20),
      border: Border.all(color: Colors.white.withOpacity(.12)),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(.4), blurRadius: compact ? 4 : 20, offset: Offset(0, compact ? 2 : 8))],
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        Text(value, style: TextStyle(color: foreground, fontSize: compact ? 28 : 104, fontWeight: FontWeight.w800, fontFeatures: const [FontFeature.tabularFigures()])),
        Positioned(left: 0, right: 0, child: Container(height: 1, color: Colors.black.withOpacity(.55))),
      ],
    ),
  );

  static String _weekday(int day) => const ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][day - 1];
  static String _month(int month) => const ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][month - 1];
}

class _AnalogClockPainter extends CustomPainter {
  final DateTime date;
  final Color foreground, accent;
  const _AnalogClockPainter({required this.date, required this.foreground, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * .46;
    final ring = Paint()..color = foreground.withOpacity(.35)..style = PaintingStyle.stroke..strokeWidth = 2;
    canvas.drawCircle(center, radius, ring);
    for (var i = 0; i < 60; i++) {
      final angle = i * math.pi / 30 - math.pi / 2;
      final outer = center + Offset(math.cos(angle), math.sin(angle)) * radius * .92;
      final inner = center + Offset(math.cos(angle), math.sin(angle)) * radius * (i % 5 == 0 ? .80 : .87);
      canvas.drawLine(inner, outer, Paint()..color = foreground.withOpacity(.65)..strokeWidth = i % 5 == 0 ? 3 : 1);
    }
    void hand(double angle, double length, double width, Color color) {
      final end = center + Offset(math.cos(angle - math.pi / 2), math.sin(angle - math.pi / 2)) * radius * length;
      canvas.drawLine(center, end, Paint()..color = color..strokeWidth = width..strokeCap = StrokeCap.round);
    }
    hand((date.hour % 12 + date.minute / 60) * math.pi / 6, .52, 6, foreground);
    hand((date.minute + date.second / 60) * math.pi / 30, .72, 4, foreground);
    hand(date.second * math.pi / 30, .82, 1.5, accent);
    canvas.drawCircle(center, 5, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(covariant _AnalogClockPainter old) => old.date.second != date.second || old.foreground != foreground || old.accent != accent;
}
