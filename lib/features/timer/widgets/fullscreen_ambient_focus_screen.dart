import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Fullscreen Ambient Focus Mode matching photo_2026-11-07_16-19-02.jpg
/// Features:
/// 1. Deep OLED dark canvas with fluid ambient glowing waves
/// 2. Gigantic focus countdown / stopwatch digits (e.g. 24:57)
/// 3. Task description & Project pill ("• No Project")
/// 4. Stop button + "Exit full-screen"
class FullscreenAmbientFocusScreen extends StatefulWidget {
  final int elapsedMs;
  final int? targetMinutes;
  final String description;
  final String projectName;
  final bool isRunning;
  final VoidCallback onStop;
  final VoidCallback onTogglePlay;

  const FullscreenAmbientFocusScreen({
    super.key,
    required this.elapsedMs,
    this.targetMinutes,
    required this.description,
    required this.projectName,
    required this.isRunning,
    required this.onStop,
    required this.onTogglePlay,
  });

  @override
  State<FullscreenAmbientFocusScreen> createState() =>
      _FullscreenAmbientFocusScreenState();
}

class _FullscreenAmbientFocusScreenState
    extends State<FullscreenAmbientFocusScreen> with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _waveController.dispose();
    super.dispose();
  }

  String _formatTime() {
    int displayMs = widget.elapsedMs;
    if (widget.targetMinutes != null && widget.targetMinutes! > 0) {
      final totalTargetMs = widget.targetMinutes! * 60000;
      displayMs = (totalTargetMs - widget.elapsedMs).clamp(0, totalTargetMs);
    }

    final duration = Duration(milliseconds: displayMs);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0B12),
      body: Stack(
        children: [
          // Ambient Animated Wave Background
          AnimatedBuilder(
            animation: _waveController,
            builder: (context, _) {
              return CustomPaint(
                painter: _AmbientWavePainter(_waveController.value),
                size: Size.infinite,
              );
            },
          ),

          // Central Typography & Controls
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Exit Icon
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.fullscreen_exit_rounded,
                            color: Colors.white54, size: 28),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // Center Focus Time & Description
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 84,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -2,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Description text
                    Text(
                      widget.description.isNotEmpty
                          ? widget.description
                          : '+ Add description',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.75),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Project Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.12),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE040FB),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.projectName.isNotEmpty
                                ? widget.projectName
                                : 'No Project',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Bottom Actions: Stop & Exit Full-Screen
                Padding(
                  padding: const EdgeInsets.only(bottom: 36),
                  child: Column(
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE040FB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          elevation: 4,
                        ),
                        onPressed: () {
                          widget.onStop();
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'Stop',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Exit full-screen',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AmbientWavePainter extends CustomPainter {
  final double progress;
  _AmbientWavePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF6366F1).withOpacity(0.25),
          const Color(0xFFE040FB).withOpacity(0.18),
          Colors.transparent,
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path1 = Path();
    final waveHeight = 60.0;
    final yOffset = size.height * 0.45;

    path1.moveTo(0, yOffset);
    for (double x = 0; x <= size.width; x += 10) {
      final y = math.sin((x / size.width * 2 * math.pi) + (progress * 2 * math.pi)) *
              waveHeight +
          yOffset;
      path1.lineTo(x, y);
    }
    path1.lineTo(size.width, size.height);
    path1.lineTo(0, size.height);
    path1.close();

    canvas.drawPath(path1, paint1);

    // Secondary wave
    final paint2 = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFFEC4899).withOpacity(0.20),
          Colors.transparent,
        ],
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path2 = Path();
    final yOffset2 = size.height * 0.55;
    path2.moveTo(0, yOffset2);
    for (double x = 0; x <= size.width; x += 10) {
      final y = math.cos((x / size.width * 2 * math.pi) - (progress * 2 * math.pi)) *
              40.0 +
          yOffset2;
      path2.lineTo(x, y);
    }
    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();

    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant _AmbientWavePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
