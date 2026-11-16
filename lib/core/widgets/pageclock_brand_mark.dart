import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Compact PageClock clock-and-open-book mark drawn as vector artwork so it
/// stays crisp at launcher, navigation and responsive dashboard sizes.
class PageClockBrandMark extends StatelessWidget {
  final double size;
  final Color? inkColor;
  final Color? accentColor;

  const PageClockBrandMark({
    super.key,
    this.size = 40,
    this.inkColor,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PageClockBrandPainter(
          ink: inkColor ?? scheme.onSurface,
          accent: accentColor ?? scheme.primary,
        ),
      ),
    );
  }
}

class _PageClockBrandPainter extends CustomPainter {
  final Color ink;
  final Color accent;

  const _PageClockBrandPainter({required this.ink, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 100;
    final stroke = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.2 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final center = Offset(size.width * .5, size.height * .38);
    final radius = size.width * .255;

    // Heritage clock dial, with an open lower edge that flows into the book.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi * .92,
      math.pi * 1.84,
      false,
      stroke,
    );

    final tickPaint = Paint()
      ..color = ink
      ..strokeWidth = 3.2 * scale
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 9; i++) {
      final angle = -math.pi * .88 + (math.pi * 1.76 * i / 8);
      final inner = radius * .78;
      final outer = radius * .94;
      canvas.drawLine(
        center + Offset(math.cos(angle) * inner, math.sin(angle) * inner),
        center + Offset(math.cos(angle) * outer, math.sin(angle) * outer),
        tickPaint,
      );
    }

    final handPaint = Paint()
      ..color = ink
      ..strokeWidth = 4.4 * scale
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, center + Offset(-radius * .42, -radius * .18), handPaint);

    final secondHand = Paint()
      ..color = accent
      ..strokeWidth = 3.1 * scale
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, center + Offset(radius * .52, -radius * .56), secondHand);
    canvas.drawCircle(center, 3.8 * scale, Paint()..color = accent);

    // Open book silhouette and central fold.
    final book = Path()
      ..moveTo(size.width * .10, size.height * .66)
      ..quadraticBezierTo(
        size.width * .29,
        size.height * .58,
        size.width * .49,
        size.height * .73,
      )
      ..quadraticBezierTo(
        size.width * .70,
        size.height * .58,
        size.width * .90,
        size.height * .66,
      )
      ..lineTo(size.width * .90, size.height * .84)
      ..quadraticBezierTo(
        size.width * .69,
        size.height * .75,
        size.width * .50,
        size.height * .91,
      )
      ..quadraticBezierTo(
        size.width * .30,
        size.height * .75,
        size.width * .10,
        size.height * .84,
      )
      ..close();
    canvas.drawPath(book, stroke);
    canvas.drawLine(
      Offset(size.width * .50, size.height * .73),
      Offset(size.width * .50, size.height * .90),
      stroke,
    );

    final pageAccent = Paint()
      ..color = accent
      ..strokeWidth = 2.2 * scale
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * .20, size.height * .73),
      Offset(size.width * .39, size.height * .78),
      pageAccent,
    );
    canvas.drawLine(
      Offset(size.width * .61, size.height * .78),
      Offset(size.width * .80, size.height * .73),
      pageAccent,
    );
  }

  @override
  bool shouldRepaint(covariant _PageClockBrandPainter oldDelegate) =>
      oldDelegate.ink != ink || oldDelegate.accent != accent;
}
