import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/theme_provider.dart';

/// Apple Mac Retro Flip Clock & Fullscreen Focus Countdown Screen (Fliqlo Screensaver Style)
/// Matches uploaded_media_2_1794050776776.png:
/// - True OLED deep pitch black backdrop (#000000 / #0A0A0A)
/// - Twin realistic matte-black flip plates (#141416 / #17171A) with soft bevel & center dividing slit
/// - Bold, high-contrast, rounded retro typography (e.g. 24 : 56 or 09 : 41)
/// - Top-left AM / PM / FOCUS indicator badge
/// - Authentic horizontal dividing slit and side hinge notches
/// - Minimalist calm controls: Pause/Resume, Stop, Toggle Mode (Countdown vs Mac Clock), and Close
class AppleMacFlipClockScreen extends StatefulWidget {
  final int elapsedMs;
  final int? targetMinutes;
  final String description;
  final String projectName;
  final bool isRunning;
  final bool isSpecial1;
  final VoidCallback onStop;
  final VoidCallback onTogglePlay;

  const AppleMacFlipClockScreen({
    super.key,
    required this.elapsedMs,
    this.targetMinutes,
    required this.description,
    required this.projectName,
    required this.isRunning,
    this.isSpecial1 = false,
    required this.onStop,
    required this.onTogglePlay,
  });

  @override
  State<AppleMacFlipClockScreen> createState() => _AppleMacFlipClockScreenState();
}

class _AppleMacFlipClockScreenState extends State<AppleMacFlipClockScreen> {
  bool _showWallClock = false; // Toggle between Focus Countdown and Live Mac Standby Clock
  late bool _usePastelBackdrop;
  Timer? _ticker;
  late int _localElapsedMs;
  late bool _localIsRunning;
  DateTime _lastTickTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _usePastelBackdrop = widget.isSpecial1;
    _localElapsedMs = widget.elapsedMs;
    _localIsRunning = widget.isRunning;
    _lastTickTime = DateTime.now();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _startTicker();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final now = DateTime.now();
      if (mounted) {
        setState(() {
          if (_localIsRunning) {
            final diff = now.difference(_lastTickTime).inMilliseconds;
            _localElapsedMs += diff;
          }
          _lastTickTime = now;
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant AppleMacFlipClockScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isRunning != widget.isRunning) {
      _localIsRunning = widget.isRunning;
      _lastTickTime = DateTime.now();
    }
    if ((widget.elapsedMs - _localElapsedMs).abs() > 1000) {
      _localElapsedMs = widget.elapsedMs;
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    // Determine values for left & right plates
    String leftVal;
    String rightVal;
    String subBadge;

    if (_showWallClock) {
      // Wall clock mode (Fliqlo 12-hour live time)
      final hour12 = now.hour % 12 == 0 ? 12 : now.hour % 12;
      leftVal = hour12.toString().padLeft(2, '0');
      rightVal = now.minute.toString().padLeft(2, '0');
      subBadge = now.hour >= 12 ? 'PM' : 'AM';
    } else {
      // Focus countdown mode (e.g. 25:00 countdown) or stopwatch
      int displayMs = _localElapsedMs;
      if (widget.targetMinutes != null && widget.targetMinutes! > 0) {
        final totalTargetMs = widget.targetMinutes! * 60000;
        displayMs = (totalTargetMs - _localElapsedMs).clamp(0, totalTargetMs);
      }
      final duration = Duration(milliseconds: displayMs);
      final minutes = duration.inMinutes;
      final seconds = duration.inSeconds.remainder(60);

      leftVal = minutes.toString().padLeft(2, '0');
      rightVal = seconds.toString().padLeft(2, '0');
      subBadge = widget.targetMinutes != null ? 'FOCUS' : 'ELAPSED';
    }

    final isDark = !_usePastelBackdrop;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : Special1Palette.background,
      body: SafeArea(
        child: Stack(
          children: [
            // Optional Pastel Waves for special1 theme
            if (!isDark) ...[
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFFDE8E8),
                      Special1Palette.background,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 200,
                child: CustomPaint(
                  painter: Special1WavesPainter(),
                ),
              ),
            ],

            // Top Bar: Exit button & Mode toggles
            Positioned(
              top: 16,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: isDark ? Colors.white38 : Special1Palette.primaryText,
                      size: 28,
                    ),
                    tooltip: 'Exit fullscreen',
                    onPressed: () => Navigator.pop(context),
                  ),

                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Backdrop theme switcher if in special1
                      if (widget.isSpecial1)
                        IconButton(
                          icon: Icon(
                            _usePastelBackdrop ? Icons.dark_mode_outlined : Icons.palette_outlined,
                            color: isDark ? Colors.white60 : Special1Palette.primaryText,
                            size: 20,
                          ),
                          tooltip: _usePastelBackdrop ? 'Switch to OLED Black' : 'Switch to Pastel',
                          onPressed: () => setState(() => _usePastelBackdrop = !_usePastelBackdrop),
                        ),

                      const SizedBox(width: 8),

                      // Mode Switcher: Focus Countdown ⇄ Mac Wall Clock
                      InkWell(
                        onTap: () => setState(() => _showWallClock = !_showWallClock),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF18181B) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark ? const Color(0xFF27272A) : Special1Palette.inputBorder,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _showWallClock ? Icons.hourglass_empty_rounded : Icons.access_time_rounded,
                                size: 14,
                                color: isDark ? const Color(0xFFA1A1AA) : Special1Palette.accentRoseDark,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _showWallClock ? 'Focus Countdown' : 'Mac Wall Clock',
                                style: TextStyle(
                                  color: isDark ? const Color(0xFFEDEDED) : Special1Palette.primaryText,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Center: Responsive Apple Mac Twin Flip Plates
            Center(
              child: LayoutBuilder(
                builder: (ctx, constraints) {
                  final isLandscape = constraints.maxWidth > constraints.maxHeight;
                  // Dynamic plate width fitting portrait phones, tablets, and wide screens
                  final double plateWidth = isLandscape
                      ? (constraints.maxWidth * 0.30).clamp(160.0, 320.0)
                      : ((constraints.maxWidth - 56) / 2).clamp(130.0, 220.0);
                  final double plateHeight = plateWidth * 1.25;
                  final double fontSize = plateWidth * 0.72;

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Twin Flip Plates
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildFlipPlate(
                              value: leftVal,
                              badge: subBadge,
                              isLeft: true,
                              isDark: isDark,
                              plateWidth: plateWidth,
                              plateHeight: plateHeight,
                              fontSize: fontSize,
                            ),
                            SizedBox(width: plateWidth * 0.08),
                            _buildFlipPlate(
                              value: rightVal,
                              badge: null,
                              isLeft: false,
                              isDark: isDark,
                              plateWidth: plateWidth,
                              plateHeight: plateHeight,
                              fontSize: fontSize,
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),

                        // Task Description & Project Badge
                        if (widget.description.isNotEmpty || widget.projectName.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF141416) : Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? const Color(0xFF26262B) : Special1Palette.inputBorder,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF10B981) : Special1Palette.accentRose,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  widget.description.isNotEmpty
                                      ? widget.description
                                      : widget.projectName,
                                  style: TextStyle(
                                    color: isDark ? const Color(0xFFA1A1AA) : Special1Palette.primaryText,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom Calm Controls: Pause / Resume and Stop
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Play / Pause Button
                    InkWell(
                      onTap: () {
                        setState(() {
                          _localIsRunning = !_localIsRunning;
                          _lastTickTime = DateTime.now();
                        });
                        widget.onTogglePlay();
                      },
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF18181B) : Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: isDark ? const Color(0xFF27272A) : Special1Palette.inputBorder,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _localIsRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              size: 18,
                              color: isDark ? Colors.white : Special1Palette.primaryText,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _localIsRunning ? 'Pause' : 'Resume',
                              style: TextStyle(
                                color: isDark ? Colors.white : Special1Palette.primaryText,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Stop & Save Button
                    InkWell(
                      onTap: () {
                        widget.onStop();
                        Navigator.pop(context);
                      },
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF27272A) : Special1Palette.stopButton,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.stop_rounded,
                              size: 18,
                              color: isDark ? const Color(0xFFF87171) : Special1Palette.primaryText,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Stop',
                              style: TextStyle(
                                color: isDark ? Colors.white : Special1Palette.primaryText,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Apple Mac Flip Plate with matte bevel, horizontal slit, side hinges, and bold retro digits
  Widget _buildFlipPlate({
    required String value,
    required String? badge,
    required bool isLeft,
    required bool isDark,
    required double plateWidth,
    required double plateHeight,
    required double fontSize,
  }) {
    final plateBg = isDark ? const Color(0xFF141416) : const Color(0xFF221F28);
    final borderColor = isDark ? const Color(0xFF26262B) : const Color(0xFF332F3D);

    return Container(
      width: plateWidth,
      height: plateHeight,
      decoration: BoxDecoration(
        color: plateBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: borderColor,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.9 : 0.25),
            blurRadius: 28,
            spreadRadius: 2,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.05),
            blurRadius: 1,
            spreadRadius: 0,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Top-left AM / PM / FOCUS badge (like real Mac Fliqlo)
          if (badge != null)
            Positioned(
              top: 14,
              left: 16,
              child: Text(
                badge,
                style: const TextStyle(
                  color: Color(0xFF8E8E93),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ),

          // Central High-Contrast Bold Retro Typography
          Center(
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFFEDEDED), // Authentic Fliqlo Warm White/Platinum
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                letterSpacing: -4,
                height: 1.0,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),

          // Authentic Center Horizontal Dividing Crease / Slit
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 1.2,
                  color: const Color(0xFF09090B), // Dark recessed gap
                ),
                Container(
                  height: 1.0,
                  color: const Color(0xFF27272A), // Shadow lip
                ),
              ],
            ),
          ),

          // Side Hinges (Little notches on the left and right edge of the slit)
          Positioned(
            left: 0,
            top: (plateHeight / 2) - 3,
            child: Container(
              width: 3,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFF09090B),
                borderRadius: BorderRadius.horizontal(right: Radius.circular(2)),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: (plateHeight / 2) - 3,
            child: Container(
              width: 3,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFF09090B),
                borderRadius: BorderRadius.horizontal(left: Radius.circular(2)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
