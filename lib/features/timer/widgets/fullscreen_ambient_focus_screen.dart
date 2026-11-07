import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/theme_provider.dart';

/// Mac Retro Flip Clock & Focus Screen (Inspired by Fliqlo / Mac Screensaver)
/// Matches uploaded_media_2_1794050776776.png:
/// - True OLED deep pitch black backdrop (#000000 / #0A0A0A)
/// - Twin realistic matte-black flip plates (#17171A) with soft bevel & center dividing slit
/// - Bold, high-contrast, perfectly rounded retro typography (9 : 41 / 24 : 56)
/// - Top-left AM / PM indicator badge
/// - Minimalist calm controls: Pause, Stop, Toggle Mode, and Exit
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
  bool _showWallClock = false; // Toggle between Focus Timer and Mac Standby Clock

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isSpecial1) {
      int displayMs = widget.elapsedMs;
      if (widget.targetMinutes != null && widget.targetMinutes! > 0) {
        final totalTargetMs = widget.targetMinutes! * 60000;
        displayMs = (totalTargetMs - widget.elapsedMs).clamp(0, totalTargetMs);
      }
      final duration = Duration(milliseconds: displayMs);
      final minutes = duration.inMinutes;
      final seconds = duration.inSeconds.remainder(60);
      final formattedTime = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

      return Scaffold(
        backgroundColor: Special1Palette.background,
        body: Stack(
          children: [
            // Soft gradient background
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
            // Bottom Organic Waves
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 220,
              child: CustomPaint(
                painter: Special1WavesPainter(),
              ),
            ),
            // Content
            SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.description.isNotEmpty ? widget.description : '+ Add description',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Special1Palette.primaryText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.circle, size: 8, color: Special1Palette.primaryText),
                        const SizedBox(width: 6),
                        Text(
                          widget.projectName.isNotEmpty ? widget.projectName : 'No Project',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Special1Palette.secondaryText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 36),
                    Text(
                      formattedTime,
                      style: const TextStyle(
                        fontSize: 88,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -2.0,
                        fontFeatures: [FontFeature.tabularFigures()],
                        color: Special1Palette.primaryText,
                      ),
                    ),
                    const SizedBox(height: 48),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Special1Palette.stopButton,
                            foregroundColor: Special1Palette.primaryText,
                            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          onPressed: () {
                            widget.onStop();
                            Navigator.pop(context);
                          },
                          child: const Text('Stop', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 20),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Exit full-screen',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Special1Palette.primaryText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final now = DateTime.now();

    // Determine values for left & right plates
    String leftVal;
    String rightVal;
    String subBadge;

    if (_showWallClock) {
      // Wall clock mode (Fliqlo 12-hour)
      final hour12 = now.hour % 12 == 0 ? 12 : now.hour % 12;
      leftVal = hour12.toString();
      rightVal = now.minute.toString().padLeft(2, '0');
      subBadge = now.hour >= 12 ? 'PM' : 'AM';
    } else {
      // Focus countdown or stopwatch
      int displayMs = widget.elapsedMs;
      if (widget.targetMinutes != null && widget.targetMinutes! > 0) {
        final totalTargetMs = widget.targetMinutes! * 60000;
        displayMs = (totalTargetMs - widget.elapsedMs).clamp(0, totalTargetMs);
      }
      final duration = Duration(milliseconds: displayMs);
      final minutes = duration.inMinutes;
      final seconds = duration.inSeconds.remainder(60);

      leftVal = minutes.toString().padLeft(2, '0');
      rightVal = seconds.toString().padLeft(2, '0');
      subBadge = widget.targetMinutes != null ? 'FOCUS' : 'ELAPSED';
    }

    final isWide = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      backgroundColor: const Color(0xFF000000), // Pure OLED True Black
      body: SafeArea(
        child: Stack(
          children: [
            // Top Bar: Exit button & Clock/Timer mode switch
            Positioned(
              top: 16,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                  InkWell(
                    onTap: () => setState(() => _showWallClock = !_showWallClock),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF18181B),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF27272A), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _showWallClock ? Icons.hourglass_empty_rounded : Icons.access_time_rounded,
                            size: 14,
                            color: const Color(0xFFA1A1AA),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _showWallClock ? 'Focus Timer' : 'Mac Wall Clock',
                            style: const TextStyle(
                              color: Color(0xFFEDEDED),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Center: Twin Flip Cards
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // The Two Flip Plates Side by Side
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildFlipPlate(
                          value: leftVal,
                          badge: subBadge,
                          isLeft: true,
                          isWide: isWide,
                        ),
                        SizedBox(width: isWide ? 20 : 12),
                        _buildFlipPlate(
                          value: rightVal,
                          badge: null,
                          isLeft: false,
                          isWide: isWide,
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Task & Project Info
                    if (widget.description.isNotEmpty || widget.projectName.isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981), // Calm emerald dot
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.description.isNotEmpty
                                ? widget.description
                                : widget.projectName,
                            style: const TextStyle(
                              color: Color(0xFFA1A1AA),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            // Bottom Calm Controls
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
                      onTap: widget.onTogglePlay,
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF18181B),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: const Color(0xFF27272A), width: 1),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              widget.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.isRunning ? 'Pause' : 'Resume',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
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
                          color: const Color(0xFF27272A),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.stop_rounded, size: 18, color: Color(0xFFF87171)),
                            SizedBox(width: 8),
                            Text(
                              'Stop',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
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

  Widget _buildFlipPlate({
    required String value,
    required String? badge,
    required bool isLeft,
    required bool isWide,
  }) {
    // Dynamic dimensions matching iPad / Mac proportions
    final plateWidth = isWide ? 220.0 : 155.0;
    final plateHeight = isWide ? 260.0 : 190.0;
    final fontSize = isWide ? 150.0 : 110.0;

    return Container(
      width: plateWidth,
      height: plateHeight,
      decoration: BoxDecoration(
        color: const Color(0xFF141416), // Deep matte titanium plate
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFF26262B),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.9),
            blurRadius: 30,
            spreadRadius: 2,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.04),
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
                  color: Color(0xFF71717A),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ),

          // Central High-Contrast Typography
          Center(
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFFE4E4E7), // Warm Platinum Grey
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
