import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../core/engine/stopwatch_engine.dart';
import '../../../core/settings/app_settings.dart';
import '../../../core/theme/theme_provider.dart';

/// Apple Mac Retro Flip Clock & Fullscreen Focus Countdown Screen (Fliqlo Screensaver Style)
/// Matches Toggl Track & Apple StandBy aesthetic:
/// - True OLED deep pitch black backdrop (#000000 / #0A0A0A)
/// - Twin realistic matte-black flip plates (#141416 / #17171A) with soft bevel & center dividing slit
/// - Bold, high-contrast, rounded retro typography (e.g. 24 : 56 or 09 : 41)
/// - AM / PM / FOCUS indicator badge
/// - Authentic horizontal dividing slit and side hinge notches
/// - Minimalist calm controls: Pause/Resume, Stop, Toggle Mode (Countdown vs Mac Clock), Wakelock, and Close
class AppleMacFlipClockScreen extends ConsumerStatefulWidget {
  final int? targetMinutes;
  final String description;
  final String projectName;
  final bool isSpecial1;
  final Future<bool> Function()? onStop;
  final VoidCallback? onTogglePlay;

  const AppleMacFlipClockScreen({
    super.key,
    this.targetMinutes,
    this.description = '',
    this.projectName = 'General Focus',
    this.isSpecial1 = false,
    this.onStop,
    this.onTogglePlay,
  });

  @override
  ConsumerState<AppleMacFlipClockScreen> createState() => _AppleMacFlipClockScreenState();
}

class _AppleMacFlipClockScreenState extends ConsumerState<AppleMacFlipClockScreen> {
  bool _showWallClock = false; // Toggle between Focus Countdown and Live Mac Standby Clock
  late bool _usePastelBackdrop;
  bool _wakelockActive = true;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _usePastelBackdrop = widget.isSpecial1;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Keep screen awake while in fullscreen flip clock
    WakelockPlus.enable().catchError((_) {});

    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WakelockPlus.disable().catchError((_) {});
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleWakelock() {
    setState(() => _wakelockActive = !_wakelockActive);
    if (_wakelockActive) {
      WakelockPlus.enable().catchError((_) {});
    } else {
      WakelockPlus.disable().catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final stopwatchState = ref.watch(stopwatchEngineProvider);
    final stopwatchNotifier = ref.read(stopwatchEngineProvider.notifier);

    final colorScheme = Theme.of(context).colorScheme;
    final isOledBackdrop = widget.isSpecial1 && !_usePastelBackdrop;
    final isDark = Theme.of(context).brightness == Brightness.dark || isOledBackdrop;
    final backgroundColor =
        isOledBackdrop ? Colors.black : Theme.of(context).scaffoldBackgroundColor;
    final surfaceColor = isOledBackdrop
        ? const Color(0xFF141416)
        : colorScheme.surface;
    final borderColor = isOledBackdrop
        ? const Color(0xFF27272A)
        : colorScheme.outline;
    final primaryTextColor = isOledBackdrop ? Colors.white : colorScheme.onSurface;
    final mutedTextColor =
        isOledBackdrop ? Colors.white70 : colorScheme.onSurfaceVariant;
    final now = DateTime.now();

    final targetMins = widget.targetMinutes ?? settings.pomodoroFocusMinutes;
    final targetMs = targetMins * 60 * 1000;
    final elapsedMs = stopwatchState.elapsedMs;

    // Time calculations
    String leftVal;
    String rightVal;
    String? subBadge;

    if (_showWallClock) {
      // 12-hour or 24-hour Mac Standby Flip Clock
      int hour = now.hour;
      final isPm = hour >= 12;
      subBadge = isPm ? 'PM' : 'AM';

      if (!settings.use24HourClock) {
        hour = hour % 12;
        if (hour == 0) hour = 12;
      }
      leftVal = hour.toString().padLeft(2, '0');
      rightVal = now.minute.toString().padLeft(2, '0');
    } else {
      // Focus Countdown Mode (Target - Elapsed) or Counting Up if past target
      subBadge = 'FOCUS';
      final remainingMs = targetMs - elapsedMs;

      if (remainingMs >= 0) {
        final totalSec = remainingMs ~/ 1000;
        final m = totalSec ~/ 60;
        final s = totalSec % 60;
        leftVal = m.toString().padLeft(2, '0');
        rightVal = s.toString().padLeft(2, '0');
      } else {
        // Overtime counter
        final overtimeSec = (-remainingMs) ~/ 1000;
        final m = overtimeSec ~/ 60;
        final s = overtimeSec % 60;
        leftVal = '+${m.toString().padLeft(2, '0')}';
        rightVal = s.toString().padLeft(2, '0');
      }
    }

    final isRunning = stopwatchState.isRunning;
    final isPaused = stopwatchState.isPaused;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // Ambient Waves if pastel enabled
          if (_usePastelBackdrop)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 200,
              child: CustomPaint(
                painter: Special1WavesPainter(),
              ),
            ),

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
                    color: mutedTextColor,
                    size: 28,
                  ),
                  tooltip: 'Exit fullscreen',
                  onPressed: () => Navigator.pop(context),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Screen awake toggle
                    IconButton(
                      icon: Icon(
                        _wakelockActive ? Icons.screen_lock_portrait_rounded : Icons.screen_lock_rotation_rounded,
                        color: _wakelockActive
                            ? const Color(0xFF10B981)
                            : mutedTextColor,
                        size: 20,
                      ),
                      tooltip: _wakelockActive ? 'Screen keep-alive ON' : 'Screen keep-alive OFF',
                      onPressed: _toggleWakelock,
                    ),
                    const SizedBox(width: 4),

                    // Backdrop theme switcher if in special1
                    if (widget.isSpecial1)
                      IconButton(
                        icon: Icon(
                          _usePastelBackdrop ? Icons.dark_mode_outlined : Icons.palette_outlined,
                          color: primaryTextColor,
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
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: borderColor,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _showWallClock ? Icons.hourglass_empty_rounded : Icons.access_time_rounded,
                              size: 14,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _showWallClock ? 'Focus Countdown' : 'Mac Wall Clock',
                              style: TextStyle(
                                color: primaryTextColor,
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
                            colorScheme: colorScheme,
                            isOledBackdrop: isOledBackdrop,
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
                            colorScheme: colorScheme,
                            isOledBackdrop: isOledBackdrop,
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // Task Description & Project Badge
                      if (widget.description.isNotEmpty || widget.projectName.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: borderColor,
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
                                  color: colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.description.isNotEmpty
                                    ? widget.description
                                    : widget.projectName,
                                style: TextStyle(
                                  color: primaryTextColor,
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
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Play / Pause Button
                  InkWell(
                    onTap: () {
                      if (widget.onTogglePlay != null) {
                        widget.onTogglePlay!();
                      } else {
                        if (isRunning) {
                          stopwatchNotifier.pause();
                        } else if (isPaused) {
                          stopwatchNotifier.resume();
                        } else {
                          stopwatchNotifier.start(
                            subjectId: widget.projectName,
                            note: widget.description,
                          );
                        }
                      }
                    },
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: borderColor,
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
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            size: 18,
                            color: primaryTextColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isRunning ? 'Pause' : (isPaused ? 'Resume' : 'Start'),
                            style: TextStyle(
                              color: isDark ? Colors.white : Special1Palette.primaryText,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (isRunning || isPaused) ...[
                    const SizedBox(width: 12),
                    // Stop Button
                    InkWell(
                      onTap: () async {
                        final minDurationMs =
                            ref.read(settingsProvider).minSessionSeconds * 1000;
                        bool shouldClose;
                        if (widget.onStop != null) {
                          shouldClose = await widget.onStop!();
                        } else {
                          final state = ref.read(stopwatchEngineProvider);
                          if (state.elapsedMs < minDurationMs) {
                            final decision = await showDialog<bool>(
                              context: context,
                              builder: (dialogContext) => AlertDialog(
                                title: const Text('Short session'),
                                content: const Text(
                                  'Save this short session or discard it?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, null),
                                    child: const Text('Continue'),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, false),
                                    child: const Text('Discard'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(dialogContext, true),
                                    child: const Text('Save anyway'),
                                  ),
                                ],
                              ),
                            );
                            if (decision == null) return;
                            if (decision) {
                              await stopwatchNotifier.stop(
                                minSessionDurationMs: minDurationMs,
                                forceSave: true,
                              );
                            } else {
                              await stopwatchNotifier.cancel();
                            }
                          } else {
                            await stopwatchNotifier.stop(
                              minSessionDurationMs: minDurationMs,
                            );
                          }
                          shouldClose = true;
                        }
                        if (shouldClose && mounted) {
                          Navigator.maybePop(context);
                        }
                      },
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: colorScheme.error.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: colorScheme.error.withOpacity(0.4),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.stop_rounded, size: 18, color: colorScheme.error),
                            const SizedBox(width: 6),
                            Text(
                              'Stop',
                              style: TextStyle(
                                color: colorScheme.error,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlipPlate({
    required String value,
    required String? badge,
    required bool isLeft,
    required bool isDark,
    required double plateWidth,
    required double plateHeight,
    required double fontSize,
    required ColorScheme colorScheme,
    required bool isOledBackdrop,
  }) {
    final plateBg = isOledBackdrop
        ? const Color(0xFF141416)
        : colorScheme.surface;
    final plateBorder = isOledBackdrop
        ? const Color(0xFF222227)
        : colorScheme.outline;

    return Container(
      width: plateWidth,
      height: plateHeight,
      decoration: BoxDecoration(
        color: plateBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: plateBorder,
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
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                color: isOledBackdrop
                    ? Colors.white
                    : colorScheme.onSurface,
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                letterSpacing: -4,
                height: 1.0,
                fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 1.2,
                  color: plateBorder.withOpacity(0.7),
                ),
                Container(
                  height: 1.0,
                  color: plateBorder,
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            top: (plateHeight / 2) - 3,
            child: Container(
              width: 3,
              height: 6,
              decoration: const BoxDecoration(
                color: plateBorder,
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
