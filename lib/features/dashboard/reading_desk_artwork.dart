import 'package:flutter/material.dart';

/// A quiet, reusable reading-desk illustration for the dashboard focus card.
///
/// It is drawn in Flutter rather than loaded from the network, so it stays
/// crisp on web, tablet and mobile and remains available offline.
class ReadingDeskArtwork extends StatelessWidget {
  final double width;
  final double height;
  final bool isDark;

  const ReadingDeskArtwork({
    super.key,
    this.width = 176,
    this.height = 144,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ExcludeSemantics(
        child: CustomPaint(
          size: Size(width, height),
          painter: _ReadingDeskPainter(isDark: isDark),
        ),
      ),
    );
  }
}

class _ReadingDeskPainter extends CustomPainter {
  final bool isDark;

  const _ReadingDeskPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 240;
    final sy = size.height / 180;
    canvas.save();
    canvas.scale(sx, sy);

    final glow = isDark
        ? const Color(0x44FF8A24)
        : const Color(0x55F59A4A);
    final leaf = isDark
        ? const Color(0xFF668C68)
        : const Color(0xFF668B54);
    final leafLight = isDark
        ? const Color(0xFF91A978)
        : const Color(0xFF91A86B);
    final ink = isDark
        ? const Color(0xFF1B2631)
        : const Color(0xFF6B5140);
    final cream = isDark
        ? const Color(0xFFE8D9C5)
        : const Color(0xFFFFF5E8);

    // Scenic reading-hour backdrop: warm horizon, layered mountains and a
    // softly glowing sun. The illustration stays self-contained and offline.
    final sceneRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(4, 5, 232, 164),
      const Radius.circular(18),
    );
    canvas.save();
    canvas.clipRRect(sceneRect);
    canvas.drawRRect(
      sceneRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const [
                  Color(0xFF172B3E),
                  Color(0xFF664B50),
                  Color(0xFFD17B50),
                  Color(0xFFEFAD70),
                ]
              : const [
                  Color(0xFFFFE9CE),
                  Color(0xFFFFD6AA),
                  Color(0xFFF4B17D),
                  Color(0xFFE99B70),
                ],
          stops: const [0, .42, .76, 1],
        ).createShader(const Rect.fromLTWH(4, 5, 232, 164)),
    );

    // Diffused sunset glow behind the mountain ridge.
    canvas.drawCircle(
      const Offset(167, 61),
      49,
      Paint()
        ..shader = RadialGradient(
          colors: [
            isDark
                ? const Color(0x99FFB36A)
                : const Color(0x99FFF0BF),
            isDark
                ? const Color(0x33FF9A52)
                : const Color(0x22FFF0BF),
            Colors.transparent,
          ],
        ).createShader(
          const Rect.fromCircle(center: Offset(167, 61), radius: 49),
        ),
    );
    canvas.drawCircle(
      const Offset(167, 61),
      22,
      Paint()
        ..color = isDark
            ? const Color(0xFFFFC17A)
            : const Color(0xFFFFF1C7),
    );

    // Distant mountain silhouettes.
    final distant = Path()
      ..moveTo(4, 119)
      ..lineTo(31, 91)
      ..lineTo(51, 105)
      ..lineTo(84, 69)
      ..lineTo(111, 100)
      ..lineTo(139, 78)
      ..lineTo(173, 111)
      ..lineTo(205, 83)
      ..lineTo(236, 108)
      ..lineTo(236, 169)
      ..lineTo(4, 169)
      ..close();
    canvas.drawPath(
      distant,
      Paint()
        ..color = isDark
            ? const Color(0xFF46576A)
            : const Color(0xFFCB8B70),
    );

    // Near ridge gives the scene depth without competing with the timer.
    final near = Path()
      ..moveTo(4, 132)
      ..lineTo(42, 105)
      ..lineTo(72, 126)
      ..lineTo(112, 91)
      ..lineTo(145, 123)
      ..lineTo(180, 101)
      ..lineTo(211, 128)
      ..lineTo(236, 112)
      ..lineTo(236, 169)
      ..lineTo(4, 169)
      ..close();
    canvas.drawPath(
      near,
      Paint()
        ..color = isDark
            ? const Color(0xFF26394B)
            : const Color(0xFF9D6D5F),
    );

    // A quiet foreground desk/horizon band.
    canvas.drawRect(
      const Rect.fromLTWH(4, 139, 232, 30),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const [Color(0xFF243644), Color(0xFF182632)]
              : const [Color(0xFFC17A5B), Color(0xFF8F5847)],
        ).createShader(const Rect.fromLTWH(4, 139, 232, 30)),
    );

    if (isDark) {
      final star = Paint()..color = const Color(0xFFFFE1B4).withOpacity(.75);
      for (final point in const [
        Offset(28, 28),
        Offset(60, 42),
        Offset(119, 25),
        Offset(210, 31),
        Offset(226, 56),
      ]) {
        canvas.drawCircle(point, 1.25, star);
      }
    }
    canvas.restore();

    // Soft ambient glow, kept within the illustration so it never obscures text.
    canvas.drawCircle(
      const Offset(138, 72),
      92,
      Paint()
        ..shader = RadialGradient(
          colors: [glow, glow.withOpacity(0)],
        ).createShader(
          Rect.fromCircle(center: Offset(138, 72), radius: 92),
        ),
    );

    // Desk shadow.
    canvas.drawOval(
      const Rect.fromLTRB(12, 151, 225, 174),
      Paint()..color = Colors.black.withOpacity(isDark ? .20 : .09),
    );

    // Plant stems.
    final stems = Paint()
      ..color = leaf
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final stemPath = Path()
      ..moveTo(190, 133)
      ..quadraticBezierTo(189, 91, 167, 48)
      ..moveTo(190, 133)
      ..quadraticBezierTo(190, 86, 206, 54)
      ..moveTo(190, 133)
      ..quadraticBezierTo(174, 102, 145, 83)
      ..moveTo(190, 133)
      ..quadraticBezierTo(209, 103, 224, 89)
      ..moveTo(190, 133)
      ..quadraticBezierTo(190, 76, 189, 34);
    canvas.drawPath(stemPath, stems);

    _drawLeaf(canvas, const Offset(164, 62), -.72, leaf, 34, 16);
    _drawLeaf(canvas, const Offset(176, 85), .52, leafLight, 31, 15);
    _drawLeaf(canvas, const Offset(205, 68), -.82, leafLight, 34, 16);
    _drawLeaf(canvas, const Offset(215, 101), .55, leaf, 29, 14);
    _drawLeaf(canvas, const Offset(149, 91), .40, leaf, 30, 14);
    _drawLeaf(canvas, const Offset(188, 45), -.10, leafLight, 30, 14);
    _drawLeaf(canvas, const Offset(197, 108), -.26, leafLight, 27, 13);

    // Rounded terracotta planter.
    final planter = Path()
      ..moveTo(170, 119)
      ..lineTo(211, 119)
      ..lineTo(205, 158)
      ..quadraticBezierTo(204, 164, 197, 164)
      ..lineTo(184, 164)
      ..quadraticBezierTo(177, 164, 176, 158)
      ..close();
    canvas.drawPath(planter, Paint()..color = isDark
        ? const Color(0xFFB96B42)
        : const Color(0xFFC97A4D));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(167, 115, 47, 9),
        const Radius.circular(4),
      ),
      Paint()..color = isDark ? const Color(0xFFD08A5A) : const Color(0xFFE4A06B),
    );
    canvas.drawLine(
      const Offset(181, 132),
      const Offset(180, 151),
      Paint()
        ..color = Colors.white.withOpacity(.18)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    // A small stack of reading books, using the brand's warm paper colours.
    _drawBook(
      canvas,
      left: 14,
      top: 135,
      width: 136,
      height: 20,
      cover: isDark ? const Color(0xFFB65B32) : const Color(0xFFC86B35),
      page: cream,
      spine: isDark ? const Color(0xFF8E432A) : const Color(0xFFA94E2B),
    );
    _drawBook(
      canvas,
      left: 25,
      top: 114,
      width: 120,
      height: 20,
      cover: isDark ? const Color(0xFFDED0B8) : const Color(0xFFE8D8C1),
      page: isDark ? const Color(0xFFF5EBDD) : const Color(0xFFFFFAF1),
      spine: isDark ? const Color(0xFFB9A68A) : const Color(0xFFC7B398),
    );
    _drawBook(
      canvas,
      left: 39,
      top: 94,
      width: 95,
      height: 19,
      cover: isDark ? const Color(0xFF536779) : const Color(0xFF526B7B),
      page: const Color(0xFFF4EBDD),
      spine: isDark ? const Color(0xFF35495B) : const Color(0xFF3C5362),
    );

    // Fine book-spine details add texture without introducing fake labels.
    final detail = Paint()
      ..color = cream.withOpacity(.76)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(51, 100), const Offset(51, 106), detail);
    canvas.drawLine(const Offset(62, 100), const Offset(112, 100), detail);
    canvas.drawLine(const Offset(35, 121), const Offset(35, 127), detail);
    canvas.drawLine(const Offset(47, 120), const Offset(128, 120), detail);
    canvas.drawLine(const Offset(25, 142), const Offset(25, 149), detail);
    canvas.drawLine(const Offset(39, 142), const Offset(137, 142), detail);

    // A small reading light gives the scene a warm, lived-in finish.
    final lampStem = Paint()
      ..color = isDark ? const Color(0xFF77818B) : const Color(0xFF7D7469)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(88, 91), const Offset(105, 57), lampStem);
    canvas.drawCircle(
      const Offset(105, 56),
      4,
      Paint()..color = isDark ? const Color(0xFF9AA5AF) : const Color(0xFF9A8A76),
    );
    final shade = Path()
      ..moveTo(81, 52)
      ..quadraticBezierTo(100, 35, 121, 49)
      ..lineTo(113, 66)
      ..quadraticBezierTo(99, 60, 88, 67)
      ..close();
    canvas.drawPath(
      shade,
      Paint()..color = isDark ? const Color(0xFFE4A65B) : const Color(0xFFF2B65F),
    );
    canvas.drawPath(
      Path()
        ..moveTo(90, 67)
        ..quadraticBezierTo(102, 78, 114, 67)
        ..lineTo(121, 89)
        ..quadraticBezierTo(106, 83, 94, 91)
        ..close(),
      Paint()..color = glow.withOpacity(.55),
    );

    // Little highlight on the desk edge.
    canvas.drawLine(
      const Offset(14, 160),
      const Offset(225, 160),
      Paint()
        ..color = ink.withOpacity(.12)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );

    canvas.restore();
  }

  void _drawLeaf(
    Canvas canvas,
    Offset center,
    double rotation,
    Color color,
    double width,
    double height,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: width, height: height),
      Paint()..color = color,
    );
    canvas.drawLine(
      Offset(-width * .34, 0),
      Offset(width * .34, 0),
      Paint()
        ..color = Colors.white.withOpacity(.27)
        ..strokeWidth = 1,
    );
    canvas.restore();
  }

  void _drawBook(
    Canvas canvas, {
    required double left,
    required double top,
    required double width,
    required double height,
    required Color cover,
    required Color page,
    required Color spine,
  }) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left + 2, top + 3, width, height),
        const Radius.circular(4),
      ),
      Paint()..color = Colors.black.withOpacity(isDark ? .20 : .10),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, width, height - 3),
        const Radius.circular(4),
      ),
      Paint()..color = cover,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left + 5, top + 2, width - 10, height - 8),
        const Radius.circular(2),
      ),
      Paint()..color = page,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left + 2, top + height - 7, width - 4, 5),
        const Radius.circular(2),
      ),
      Paint()..color = spine,
    );
    canvas.drawLine(
      Offset(left + 8, top + 4),
      Offset(left + width - 9, top + 4),
      Paint()
        ..color = Colors.black.withOpacity(.07)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _ReadingDeskPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
