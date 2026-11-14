import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Offline renderer shared by Clock Studio and the fullscreen focus clock.
/// Persisted IDs are stable: old settings and backups continue to work.
class ClockFaceView extends StatelessWidget {
  final String styleId, leftText, rightText, secondsText;
  final String? badge;
  final Color accentColor;
  final bool showSeconds, showDate, isDark, compact;
  final DateTime date;

  const ClockFaceView({
    super.key,
    required this.styleId,
    required this.leftText,
    required this.rightText,
    required this.secondsText,
    required this.badge,
    required this.accentColor,
    required this.showSeconds,
    required this.showDate,
    required this.date,
    required this.isDark,
    this.compact = false,
  });

  // Existing IDs are intentionally retained. New faces are additive.
  static const classicStyleIds = <String>[
    'classic_braun',
    'classic_railway',
    'classic_roman',
    'classic_regulator',
    'classic_classroom',
    'classic_night_lume',
  ];

  static const styleIds = <String>[
    'mac_flip', 'nixie', 'dot_matrix', 'lcd', 'neon',
    'terminal', 'gradient', 'analog', 'editorial', 'binary',
    ...classicStyleIds,
  ];

  /// Categories group every existing template and the new Classic collection.
  static const categoryIds = <String, List<String>>{
    'Classic': <String>[
      'classic_braun', 'classic_railway', 'classic_roman',
      'classic_regulator', 'classic_classroom', 'classic_night_lume',
      'analog',
    ],
    'Digital': <String>[
      'mac_flip', 'nixie', 'dot_matrix', 'lcd', 'terminal', 'binary',
    ],
    'Ambient': <String>['neon', 'gradient'],
    'Editorial': <String>['editorial'],
  };

  static String categoryFor(String id) {
    for (final entry in categoryIds.entries) {
      if (entry.value.contains(id)) return entry.key;
    }
    return 'Digital';
  }

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
    'classic_braun' => 'Braun Minimal',
    'classic_railway' => 'Railway Classic',
    'classic_roman' => 'Roman Heritage',
    'classic_regulator' => 'Regulator',
    'classic_classroom' => 'Classroom Clear',
    'classic_night_lume' => 'Night Lume',
    _ => 'macOS Flip',
  };

  static Color colorFromHex(String value) {
    final parsed = int.tryParse(value.replaceFirst('#', ''), radix: 16);
    return Color(0xFF000000 | (parsed ?? 0xFFF5A623));
  }

  @override
  Widget build(BuildContext context) {
    final time = leftText + ':' + rightText;
    final dateLabel = _weekday(date.weekday) + '  ' +
        date.day.toString().padLeft(2, '0') + ' ' + _month(date.month);
    final displayTime = showSeconds ? time + ':' + secondsText : time;
    final classic = classicStyleIds.contains(styleId);
    final palette = _classicPalette(styleId, isDark);
    final usePaletteAccent =
        accentColor.value == colorFromHex('#F5A623').value;
    final faceAccent =
        classic && usePaletteAccent ? palette.accent : accentColor;

    final background = classic ? palette.background : switch (styleId) {
      'lcd' => const Color(0xFFB6C58A),
      'gradient' => const Color(0xFF101A36),
      'neon' => const Color(0xFF130B25),
      'editorial' => isDark ? const Color(0xFF25231F) : const Color(0xFFF0EBDD),
      'terminal' || 'binary' => const Color(0xFF050A08),
      _ => const Color(0xFF08090D),
    };
    final foreground = classic ? palette.foreground : switch (styleId) {
      'lcd' => const Color(0xFF17220E),
      'editorial' => isDark ? const Color(0xFFF0EBDD) : const Color(0xFF202020),
      'terminal' || 'binary' => const Color(0xFF63F5A5),
      'nixie' => const Color(0xFFFFA34A),
      _ => Colors.white,
    };

    Widget face;
    if (classic) {
      face = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: compact ? 106 : 292,
            height: compact ? 106 : 292,
            child: CustomPaint(
              painter: _ClassicAnalogClockPainter(
                date: date,
                styleId: styleId,
                foreground: foreground,
                accent: faceAccent,
                background: background,
                bezel: palette.bezel,
              ),
            ),
          ),
          SizedBox(height: compact ? 2 : 12),
          Text(
            displayTime,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: foreground,
              fontSize: compact ? 17 : 38,
              fontWeight: FontWeight.w700,
              letterSpacing: compact ? -0.5 : -1.2,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      );
    } else if (styleId == 'analog') {
      face = AspectRatio(
        aspectRatio: 1,
        child: CustomPaint(
          painter: _AnalogClockPainter(
            date: date,
            foreground: foreground,
            accent: accentColor,
          ),
        ),
      );
    } else if (styleId == 'binary') {
      face = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'HOUR  ' + date.hour.toRadixString(2).padLeft(5, '0'),
            style: TextStyle(
              color: foreground,
              fontFamily: 'monospace',
              fontSize: compact ? 10 : 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'MIN   ' + date.minute.toRadixString(2).padLeft(6, '0'),
            style: TextStyle(
              color: foreground,
              fontFamily: 'monospace',
              fontSize: compact ? 10 : 20,
            ),
          ),
        ],
      );
    } else if (styleId == 'editorial') {
      face = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            leftText,
            style: TextStyle(
              color: foreground,
              fontSize: compact ? 30 : 100,
              fontWeight: FontWeight.w300,
              height: .95,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            rightText,
            style: TextStyle(
              color: foreground,
              fontSize: compact ? 30 : 100,
              fontWeight: FontWeight.w800,
              height: .95,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      );
    } else if (styleId == 'mac_flip') {
      face = FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _flipCard(leftText, foreground, compact),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 3 : 12),
              child: Text(
                ':',
                style: TextStyle(color: foreground, fontSize: compact ? 22 : 72),
              ),
            ),
            _flipCard(rightText, foreground, compact),
          ],
        ),
      );
    } else {
      final glow = styleId == 'nixie' || styleId == 'neon';
      face = Text(
        displayTime,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: styleId == 'dot_matrix' ? accentColor : foreground,
          fontSize: compact ? 25 : 76,
          fontWeight: FontWeight.w800,
          fontFamily: styleId == 'terminal' || styleId == 'lcd' || styleId == 'dot_matrix' ? 'monospace' : null,
          letterSpacing: styleId == 'dot_matrix' ? (compact ? 1 : 7) : (compact ? -1 : -4),
          fontFeatures: const [FontFeature.tabularFigures()],
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
            ? const LinearGradient(
                colors: [Color(0xFF111C3D), Color(0xFF39235E), Color(0xFF0C4B5A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : styleId == 'neon'
                ? const LinearGradient(
                    colors: [Color(0xFF1C0B32), Color(0xFF070A18)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
        borderRadius: BorderRadius.circular(compact ? 10 : 28),
        border: Border.all(color: foreground.withOpacity(.16)),
        boxShadow: styleId == 'mac_flip' || styleId == 'nixie'
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(.35),
                  blurRadius: compact ? 6 : 28,
                  offset: Offset(0, compact ? 2 : 12),
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badge != null && !compact)
            Text(
              badge!,
              style: TextStyle(
                color: foreground.withOpacity(.72),
                fontSize: 12,
                letterSpacing: 3,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (badge != null && !compact) const SizedBox(height: 12),
          if (styleId == 'dot_matrix')
            Wrap(
              alignment: WrapAlignment.center,
              children: displayTime.split('').map((character) {
                return Text(
                  character,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: compact ? 24 : 76,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w900,
                    shadows: [Shadow(color: accentColor, blurRadius: compact ? 3 : 12)],
                  ),
                );
              }).toList(),
            )
          else
            face,
          if (showDate && !compact) ...[
            const SizedBox(height: 18),
            Text(
              dateLabel,
              style: TextStyle(
                color: foreground.withOpacity(.7),
                letterSpacing: 2,
                fontSize: 13,
              ),
            ),
          ],
          if (showSeconds && styleId == 'mac_flip' && !compact)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(secondsText, style: TextStyle(color: accentColor, fontSize: 24)),
            ),
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
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(.4),
          blurRadius: compact ? 4 : 20,
          offset: Offset(0, compact ? 2 : 8),
        ),
      ],
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        Text(
          value,
          style: TextStyle(
            color: foreground,
            fontSize: compact ? 28 : 104,
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          child: Container(height: 1, color: Colors.black.withOpacity(.55)),
        ),
      ],
    ),
  );

  static _ClassicClockPalette _classicPalette(String id, bool isDark) {
    switch (id) {
      case 'classic_braun':
        return const _ClassicClockPalette(
          background: Color(0xFFF3F0E7),
          foreground: Color(0xFF171717),
          accent: Color(0xFFE87924),
          bezel: Color(0xFFD8D1C3),
        );
      case 'classic_railway':
        return const _ClassicClockPalette(
          background: Color(0xFFFCFCFA),
          foreground: Color(0xFF111111),
          accent: Color(0xFFD92727),
          bezel: Color(0xFFD8D8D4),
        );
      case 'classic_roman':
        return const _ClassicClockPalette(
          background: Color(0xFFF4EBDD),
          foreground: Color(0xFF2E261E),
          accent: Color(0xFF987044),
          bezel: Color(0xFFB69A75),
        );
      case 'classic_regulator':
        return const _ClassicClockPalette(
          background: Color(0xFFF0E4D1),
          foreground: Color(0xFF2C2118),
          accent: Color(0xFF9B613B),
          bezel: Color(0xFF80502F),
        );
      case 'classic_classroom':
        return const _ClassicClockPalette(
          background: Color(0xFFFFFFFF),
          foreground: Color(0xFF111827),
          accent: Color(0xFFDA3B32),
          bezel: Color(0xFFD6DCE3),
        );
      case 'classic_night_lume':
        return const _ClassicClockPalette(
          background: Color(0xFF171D26),
          foreground: Color(0xFFF0E5C7),
          accent: Color(0xFFD6B76A),
          bezel: Color(0xFF343B45),
        );
      default:
        return _ClassicClockPalette(
          background: isDark ? const Color(0xFF25231F) : const Color(0xFFF0EBDD),
          foreground: isDark ? const Color(0xFFF0EBDD) : const Color(0xFF202020),
          accent: const Color(0xFFF5A623),
          bezel: const Color(0xFFB8B1A5),
        );
    }
  }

  static String _weekday(int day) => const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day - 1];
  static String _month(int month) => const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][month - 1];
}

class _ClassicClockPalette {
  final Color background;
  final Color foreground;
  final Color accent;
  final Color bezel;

  const _ClassicClockPalette({
    required this.background,
    required this.foreground,
    required this.accent,
    required this.bezel,
  });
}

/// Shared painter for the six classic dials. Variants change dial language;
/// time-of-day hand movement stays based on the device clock.
class _ClassicAnalogClockPainter extends CustomPainter {
  final DateTime date;
  final String styleId;
  final Color foreground, accent, background, bezel;

  const _ClassicAnalogClockPainter({
    required this.date,
    required this.styleId,
    required this.foreground,
    required this.accent,
    required this.background,
    required this.bezel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * .47;
    final isNight = styleId == 'classic_night_lume';
    final isRailway = styleId == 'classic_railway';
    final isRoman = styleId == 'classic_roman';
    final isRegulator = styleId == 'classic_regulator';
    final isClassroom = styleId == 'classic_classroom';

    if (isRegulator) {
      canvas.drawCircle(
        center,
        radius * 1.02,
        Paint()..color = bezel..style = PaintingStyle.stroke..strokeWidth = radius * .085,
      );
    } else {
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = bezel.withOpacity(.72)..style = PaintingStyle.stroke..strokeWidth = 1.4,
      );
    }
    canvas.drawCircle(
      center,
      radius * .965,
      Paint()..color = foreground.withOpacity(.13)..style = PaintingStyle.stroke..strokeWidth = 1,
    );

    for (var i = 0; i < 60; i++) {
      final angle = i * math.pi / 30 - math.pi / 2;
      final major = i % 5 == 0;
      final outer = center + Offset(math.cos(angle), math.sin(angle)) * radius * .91;
      final innerFactor = isRailway ? (major ? .73 : .865) : (major ? .78 : .875);
      final inner = center + Offset(math.cos(angle), math.sin(angle)) * radius * innerFactor;
      final tickPaint = Paint()
        ..color = foreground.withOpacity(major ? 1 : (isNight ? .42 : .48))
        ..strokeWidth = major
            ? (isRailway ? radius * .045 : radius * .024)
            : math.max(1.0, radius * .006).toDouble()
        ..strokeCap = isRailway ? StrokeCap.square : StrokeCap.round;
      canvas.drawLine(inner, outer, tickPaint);
    }

    void drawLabel(String label, double hour, double labelRadius, double fontSize, {bool bold = false, Color? color}) {
      final angle = hour * math.pi / 6 - math.pi / 2;
      final position = center + Offset(math.cos(angle), math.sin(angle)) * radius * labelRadius;
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: color ?? foreground,
            fontSize: fontSize,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            fontFamily: isRoman ? 'serif' : null,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      painter.paint(canvas, Offset(position.dx - painter.width / 2, position.dy - painter.height / 2));
    }

    final labelSize = radius * (isClassroom ? .105 : .095);
    if (isRoman) {
      const numerals = ['XII', 'I', 'II', 'III', 'IIII', 'V', 'VI', 'VII', 'VIII', 'IX', 'X', 'XI'];
      for (var i = 0; i < 12; i++) {
        drawLabel(numerals[i], i.toDouble(), .70, labelSize, bold: true);
      }
    } else if (isClassroom) {
      for (var i = 1; i <= 12; i++) {
        drawLabel(i.toString(), i.toDouble(), .72, labelSize, bold: true);
      }
    } else if (isRegulator) {
      for (var i = 1; i <= 12; i++) {
        drawLabel((i * 5).toString().padLeft(2, '0'), i.toDouble(), .70, radius * .075, bold: true);
      }
    } else if (isNight) {
      for (final i in [0, 3, 6, 9]) {
        drawLabel(
          i == 0 ? '12' : i.toString(),
          i.toDouble(),
          .69,
          labelSize * .95,
          bold: true,
          color: const Color(0xFFF4E6BE),
        );
      }
    }

    final hourAngle = (date.hour % 12 + date.minute / 60) * math.pi / 6 - math.pi / 2;
    final minuteAngle = (date.minute + date.second / 60) * math.pi / 30 - math.pi / 2;
    final secondAngle = date.second * math.pi / 30 - math.pi / 2;

    void drawHand(double angle, double length, double width, Color color, {double tail = .12}) {
      final end = center + Offset(math.cos(angle), math.sin(angle)) * radius * length;
      final start = center - Offset(math.cos(angle), math.sin(angle)) * radius * tail;
      if (isNight) {
        final glow = Paint()
          ..color = color.withOpacity(.22)
          ..strokeWidth = width * 3
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawLine(start, end, glow);
      }
      canvas.drawLine(
        start,
        end,
        Paint()..color = color..strokeWidth = width..strokeCap = StrokeCap.round,
      );
    }

    drawHand(hourAngle, .48, radius * .052, foreground, tail: .10);
    drawHand(minuteAngle, .72, radius * .032, foreground, tail: .13);
    drawHand(secondAngle, .82, radius * .009, accent, tail: .19);

    if (isRailway) {
      final paddle = center + Offset(math.cos(secondAngle), math.sin(secondAngle)) * radius * .82;
      canvas.drawCircle(paddle, radius * .045, Paint()..color = accent);
    }

    canvas.drawCircle(center, radius * .045, Paint()..color = accent);
    canvas.drawCircle(center, radius * .018, Paint()..color = background);
  }

  @override
  bool shouldRepaint(covariant _ClassicAnalogClockPainter old) =>
      old.date.second != date.second ||
      old.styleId != styleId ||
      old.foreground != foreground ||
      old.accent != accent ||
      old.background != background ||
      old.bezel != bezel;
}

/// Original analog face remains available with its original visual style.
class _AnalogClockPainter extends CustomPainter {
  final DateTime date;
  final Color foreground, accent;

  const _AnalogClockPainter({
    required this.date,
    required this.foreground,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * .46;
    final ring = Paint()
      ..color = foreground.withOpacity(.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, ring);
    for (var i = 0; i < 60; i++) {
      final angle = i * math.pi / 30 - math.pi / 2;
      final outer = center + Offset(math.cos(angle), math.sin(angle)) * radius * .92;
      final inner = center + Offset(math.cos(angle), math.sin(angle)) * radius * (i % 5 == 0 ? .80 : .87);
      canvas.drawLine(
        inner,
        outer,
        Paint()
          ..color = foreground.withOpacity(.65)
          ..strokeWidth = i % 5 == 0 ? 3 : 1,
      );
    }

    void hand(double angle, double length, double width, Color color) {
      final end = center + Offset(math.cos(angle - math.pi / 2), math.sin(angle - math.pi / 2)) * radius * length;
      canvas.drawLine(
        center,
        end,
        Paint()
          ..color = color
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
    }

    hand((date.hour % 12 + date.minute / 60) * math.pi / 6, .52, 6, foreground);
    hand((date.minute + date.second / 60) * math.pi / 30, .72, 4, foreground);
    hand(date.second * math.pi / 30, .82, 1.5, accent);
    canvas.drawCircle(center, 5, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(covariant _AnalogClockPainter old) =>
      old.date.second != date.second ||
      old.foreground != foreground ||
      old.accent != accent;
}
