import 'package:flutter/material.dart';

/// Compact PageClock mark: a clock dial above an open book.
class PageClockBrandMark extends StatelessWidget {
  final double size;
  final Color? inkColor;
  final Color? accentColor;

  const PageClockBrandMark({
    super.key,
    this.size = 36,
    this.inkColor,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ink = inkColor ?? scheme.onSurface;
    final accent = accentColor ?? scheme.primary;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 0,
            left: size * 0.04,
            right: size * 0.04,
            child: Icon(
              Icons.menu_book_rounded,
              size: size * 0.88,
              color: accent,
            ),
          ),
          Positioned(
            top: 0,
            left: size * 0.29,
            right: size * 0.29,
            child: Icon(
              Icons.schedule_rounded,
              size: size * 0.44,
              color: ink,
            ),
          ),
        ],
      ),
    );
  }
}