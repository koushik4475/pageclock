import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/engine/stopwatch_engine.dart';
import '../../core/models/reading_session.dart';
import '../../core/repository/session_repository.dart';
import '../../core/theme/theme_provider.dart';
import '../../main.dart';
import '../settings/toggl_settings_screen.dart';
import 'widgets/fullscreen_ambient_focus_screen.dart';

final focusTaskDescriptionProvider = StateProvider<String>((ref) => '');
final focusSelectedProjectProvider = StateProvider<String>((ref) => 'General Focus');

/// Dual-Mode Timer Screen matching Toggl Track UI
/// Features:
/// 1. Top Bar: "Timer", "+" Quick add, Fullscreen ambient wave icon, Settings icon
/// 2. Segmented Pill Tab: "List view" vs "Pomodoro"
/// 3. In Pomodoro Mode:
///    - "I'm focusing on..." input pill
///    - Big circular progress ring with remaining countdown (e.g. 25:00)
///    - Sound toggle button
///    - "Start session" primary button
///    - "Pomodoro settings" link
/// 4. In List View Mode:
///    - Getting started progress card
///    - TODAY grouped time entries with restart button
/// 5. Persistent Running Bottom Bar:
///    - Shows live running duration e.g. 0:00:07, description, project, red stop square
class TogglTimerScreen extends ConsumerStatefulWidget {
  const TogglTimerScreen({super.key});

  @override
  ConsumerState<TogglTimerScreen> createState() => _TogglTimerScreenState();
}

class _TogglTimerScreenState extends ConsumerState<TogglTimerScreen> {
  int _selectedMode = 0; // 0: List view, 1: Pomodoro
  late TextEditingController _taskController;
  bool _soundEnabled = true;
  bool _isPomodoroBreak = false;
  bool _isLongBreak = false;
  bool _pomodoroBreakRunning = false;
  int _pomodoroCompletedFocusSessions = 0;
  int _pomodoroBreakDurationMs = 0;
  int _pomodoroBreakRemainingMs = 0;
  Timer? _pomodoroBreakTicker;

  final List<String> _availableProjects = const [
    'General Focus',
    'Coding',
    'Reading',
    'Deep Work',
    'Study',
  ];

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _selectedMode = settings.selectedTimerMode;
    _soundEnabled = settings.pomodoroSoundEnabled;
    ref.read(focusSelectedProjectProvider.notifier).state =
        settings.lastSelectedProject;
    _taskController = TextEditingController(
      text: ref.read(focusTaskDescriptionProvider),
    );
  }

  @override
  void dispose() {
    _pomodoroBreakTicker?.cancel();
    _taskController.dispose();
    super.dispose();
  }

  void _showAddEntryModal(BuildContext context) {
    final descCtrl = TextEditingController();
    final minsCtrl = TextEditingController(text: '30');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String selectedProj = ref.read(focusSelectedProjectProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF140E20) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Add Time Entry',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descCtrl,
                    autofocus: true,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Description',
                      hintText: 'What did you work on?',
                      labelStyle: TextStyle(color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A)),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1B1426) : const Color(0xFFF3F4F6),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: minsCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      labelText: 'Duration (minutes)',
                      labelStyle: TextStyle(color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A)),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1B1426) : const Color(0xFFF3F4F6),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'PROJECT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availableProjects.map((proj) {
                      final isSel = selectedProj == proj;
                      return ChoiceChip(
                        label: Text(proj),
                        selected: isSel,
                        onSelected: (val) {
                          if (val) {
                            setModalState(() => selectedProj = proj);
                          }
                        },
                        selectedColor: const Color(0xFFE040FB),
                        backgroundColor: isDark ? const Color(0xFF1F182C) : const Color(0xFFE5E7EB),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSel ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE040FB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        final mins = int.tryParse(minsCtrl.text) ?? 30;
                        final desc = descCtrl.text.trim();
                        final now = DateTime.now();
                        final durationMs = mins * 60 * 1000;
                        final session = ReadingSession(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          startedAtUtc: now.subtract(Duration(milliseconds: durationMs)).millisecondsSinceEpoch,
                          endedAtUtc: now.millisecondsSinceEpoch,
                          durationMs: durationMs,
                          tzOffsetMin: now.timeZoneOffset.inMinutes,
                          subjectId: selectedProj,
                          note: desc.isNotEmpty ? desc : 'Manual Time Log',
                          source: 'manual',
                          createdAt: now.millisecondsSinceEpoch,
                          updatedAt: now.millisecondsSinceEpoch,
                        );
                        await ref.read(sessionRepositoryProvider).saveSession(session);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Logged $mins mins for $selectedProj'),
                              backgroundColor: const Color(0xFF10B981),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      child: const Text('Save Entry', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showProjectPicker(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF140E20) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Project',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                ..._availableProjects.map((p) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.circle, color: Color(0xFFE040FB), size: 14),
                    title: Text(
                      p,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    trailing: ref.read(focusSelectedProjectProvider) == p
                        ? const Icon(Icons.check_rounded, color: Color(0xFFE040FB))
                        : null,
                    onTap: () {
                      ref.read(focusSelectedProjectProvider.notifier).state = p;
                      ref.read(settingsProvider.notifier).update(
                            (settings) =>
                                settings.copyWith(lastSelectedProject: p),
                          );
                      Navigator.pop(ctx);
                    },
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showWhatsIncludedDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF161122) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "What's Included in Productivity",
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            _FeatureRow(icon: Icons.timer_outlined, text: 'Precision Stopwatch & 25m Pomodoro Ring'),
            _FeatureRow(icon: Icons.crop_square_rounded, text: 'Apple Mac Fliqlo Retro Flip Clock'),
            _FeatureRow(icon: Icons.grid_view_rounded, text: 'GitHub-Style Contribution Activity Heatmap'),
            _FeatureRow(icon: Icons.view_timeline_rounded, text: '24-Hour Calendar Timeline with Needle Bar'),
            _FeatureRow(icon: Icons.storage_rounded, text: 'Offline-First SQLite Drift Engine'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it', style: TextStyle(color: Color(0xFFE040FB), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  String _formatElapsed(int ms) {
    final d = Duration(milliseconds: ms);
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(1, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
  }


  void _setSelectedMode(int mode) {
    setState(() => _selectedMode = mode);
    ref.read(settingsProvider.notifier).update(
          (settings) => settings.copyWith(selectedTimerMode: mode),
        );
  }

  Future<void> _startNewSession(BuildContext context, {
    required String project,
    required String description,
  }) async {
    final notifier = ref.read(stopwatchProvider.notifier);
    final current = ref.read(stopwatchProvider);
    final settings = ref.read(settingsProvider);
    if (current.currentSession != null &&
        current.status != StopwatchStatus.idle) {
      if (settings.promptRunningEntryOverride) {
        final replace = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('A session is already active'),
            content: const Text('Save the current session and start a new one?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Keep current'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Save and start'),
              ),
            ],
          ),
        );
        if (replace != true) return;
      }
      await notifier.stop(minSessionDurationMs: 0, forceSave: true);
    }
    await notifier.start(
      subjectId: project,
      note: description.trim().isEmpty ? null : description.trim(),
    );
  }

  Future<bool> _stopCurrentSession(BuildContext context) async {
    final state = ref.read(stopwatchProvider);
    if (state.currentSession == null) return false;
    final minDurationMs = ref.read(settingsProvider).minSessionSeconds * 1000;
    final notifier = ref.read(stopwatchProvider.notifier);
    if (state.elapsedMs < minDurationMs) {
      final decision = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Short session'),
          content: Text(
            'This session is only ${_formatElapsed(state.elapsedMs)}. Save it anyway or discard it?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, null),
              child: const Text('Continue session'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Discard'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save anyway'),
            ),
          ],
        ),
      );
      if (decision == null) return false;
      if (decision) {
        await notifier.stop(minSessionDurationMs: minDurationMs, forceSave: true);
      } else {
        await notifier.cancel();
      }
      return true;
    }
    await notifier.stop(minSessionDurationMs: minDurationMs);
    return true;
  }


  Future<void> _completePomodoroFocus(BuildContext context) async {
    final settings = ref.read(settingsProvider);
    final focusTargetMs = settings.pomodoroFocusMinutes * 60000;
    final current = ref.read(stopwatchProvider);
    if (current.elapsedMs < focusTargetMs ||
        current.status != StopwatchStatus.running ||
        _isPomodoroBreak) {
      return;
    }

    await ref.read(stopwatchProvider.notifier).stop(
          minSessionDurationMs: 0,
          forceSave: true,
        );
    if (!mounted) return;

    _pomodoroCompletedFocusSessions++;
    final longBreakDue = settings.pomodoroLongBreakInterval > 0 &&
        _pomodoroCompletedFocusSessions %
                settings.pomodoroLongBreakInterval ==
            0;
    final breakMinutes = longBreakDue
        ? settings.pomodoroLongBreakMinutes
        : settings.pomodoroShortBreakMinutes;

    setState(() {
      _isPomodoroBreak = true;
      _isLongBreak = longBreakDue;
      _pomodoroBreakDurationMs = breakMinutes * 60000;
      _pomodoroBreakRemainingMs = _pomodoroBreakDurationMs;
      _pomodoroBreakRunning = false;
    });

    if (settings.pomodoroSoundEnabled) {
      SystemSound.play(SystemSoundType.alert);
    }
    if (settings.pomodoroAutoStart) {
      _startPomodoroBreak(context);
    }
  }

  void _startPomodoroBreak(BuildContext context) {
    if (!_isPomodoroBreak || _pomodoroBreakDurationMs <= 0) return;
    _pomodoroBreakTicker?.cancel();
    setState(() => _pomodoroBreakRunning = true);
    _pomodoroBreakTicker = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        final nextRemaining = _pomodoroBreakRemainingMs - 1000;
        if (nextRemaining <= 0) {
          timer.cancel();
          _completePomodoroBreak(context);
        } else {
          setState(() => _pomodoroBreakRemainingMs = nextRemaining);
        }
      },
    );
  }

  void _pausePomodoroBreak() {
    _pomodoroBreakTicker?.cancel();
    setState(() => _pomodoroBreakRunning = false);
  }

  void _completePomodoroBreak(BuildContext context) {
    final autoStart = ref.read(settingsProvider).pomodoroAutoStart;
    setState(() {
      _isPomodoroBreak = false;
      _isLongBreak = false;
      _pomodoroBreakRunning = false;
      _pomodoroBreakDurationMs = 0;
      _pomodoroBreakRemainingMs = 0;
    });
    if (autoStart) {
      _startNewSession(
        context,
        project: ref.read(focusSelectedProjectProvider),
        description: _taskController.text,
      );
    }
  }

  void _togglePomodoroSound() {
    final enabled = !ref.read(settingsProvider).pomodoroSoundEnabled;
    ref.read(settingsProvider.notifier).update(
          (settings) => settings.copyWith(pomodoroSoundEnabled: enabled),
        );
    setState(() => _soundEnabled = enabled);
    if (enabled) SystemSound.play(SystemSoundType.alert);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stopwatchState = ref.watch(stopwatchProvider);
    final settings = ref.watch(settingsProvider);
    final allSessions = ref.watch(sessionsStreamProvider).value ?? [];
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final todaySessions = allSessions.where((session) {
      return session.deletedAt == null &&
          session.endedAtUtc != null &&
          session.startedAtUtc >= todayStart.millisecondsSinceEpoch &&
          session.startedAtUtc < todayEnd.millisecondsSinceEpoch;
    }).toList();
    final todayCompletedMs =
        todaySessions.fold<int>(0, (sum, session) => sum + session.durationMs);
    final activeSessionIsToday = stopwatchState.currentSession != null &&
        stopwatchState.currentSession!.startedAtUtc >=
            todayStart.millisecondsSinceEpoch;
    final todayTotalMs =
        todayCompletedMs + (activeSessionIsToday ? stopwatchState.elapsedMs : 0);
    final taskDescription = ref.watch(focusTaskDescriptionProvider);
    final selectedProject = ref.watch(focusSelectedProjectProvider);
    ref.listen<StopwatchState>(stopwatchProvider, (previous, next) {
      if (_selectedMode != 1 || _isPomodoroBreak || previous == null) return;
      final focusTargetMs = ref.read(settingsProvider).pomodoroFocusMinutes * 60000;
      if (previous.elapsedMs < focusTargetMs &&
          next.elapsedMs >= focusTargetMs &&
          next.status == StopwatchStatus.running) {
        _completePomodoroFocus(context);
      }
    });
    final appThemeId = ref.watch(appThemeIdProvider);
    final isSpecial1 = appThemeId == AppThemeId.special1;

    final bgColor = isSpecial1
        ? Special1Palette.background
        : (isDark ? const Color(0xFF0F0B15) : const Color(0xFFF9FAFB));

    final headerIconColor = isSpecial1
        ? Special1Palette.primaryText
        : (isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A));

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: Text(
          'Timer',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: isSpecial1
                ? Special1Palette.primaryText
                : (isDark ? Colors.white : const Color(0xFF111827)),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle_outline_rounded, color: headerIconColor),
            tooltip: 'Add Manual Time Entry',
            onPressed: () => _showAddEntryModal(context),
          ),
          IconButton(
            icon: Icon(Icons.fullscreen_rounded, color: headerIconColor),
            tooltip: 'Mac Retro Flip Clock Mode',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AppleMacFlipClockScreen(
                    targetMinutes: _selectedMode == 1
                        ? settings.pomodoroFocusMinutes
                        : null,
                    description: taskDescription,
                    projectName: selectedProject,
                    isSpecial1: isSpecial1,
                    onStop: () => _stopCurrentSession(context),
                    onTogglePlay: () {
                      if (ref.read(stopwatchProvider).status ==
                          StopwatchStatus.running) {
                        ref.read(stopwatchProvider.notifier).pause();
                      } else if (ref.read(stopwatchProvider).status ==
                          StopwatchStatus.paused) {
                        ref.read(stopwatchProvider.notifier).resume();
                      } else {
                        _startNewSession(
                          context,
                          project: selectedProject,
                          description: taskDescription,
                        );
                      }
                    },
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined, color: headerIconColor),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TogglSettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Bottom Organic Pastel Waves for special1
          if (isSpecial1)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 180,
              child: CustomPaint(
                painter: Special1WavesPainter(),
              ),
            ),
          Column(
            children: [
              // Segmented Tabs: List view | Pomodoro
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: isSpecial1
                        ? Colors.transparent
                        : (isDark ? const Color(0xFF1B1426) : const Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _setSelectedMode(0),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: _selectedMode == 0
                                ? BoxDecoration(
                                    color: isSpecial1
                                        ? Special1Palette.activePill
                                        : (isDark ? const Color(0xFF2C1B42) : Colors.white),
                                    borderRadius: BorderRadius.circular(10),
                                    border: isSpecial1
                                        ? null
                                        : Border.all(
                                            color: const Color(0xFFE040FB).withOpacity(0.4),
                                          ),
                                  )
                                : null,
                            child: Text(
                              'List view',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _selectedMode == 0
                                    ? (isSpecial1
                                        ? Special1Palette.primaryText
                                        : const Color(0xFFE040FB))
                                    : (isSpecial1
                                        ? Special1Palette.secondaryText
                                        : (isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A))),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => _setSelectedMode(1),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: _selectedMode == 1
                                ? BoxDecoration(
                                    color: isSpecial1
                                        ? Special1Palette.activePill
                                        : (isDark ? const Color(0xFF2C1B42) : Colors.white),
                                    borderRadius: BorderRadius.circular(10),
                                    border: isSpecial1
                                        ? null
                                        : Border.all(
                                            color: const Color(0xFFE040FB).withOpacity(0.4),
                                          ),
                                  )
                                : null,
                            child: Text(
                              'Pomodoro',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _selectedMode == 1
                                    ? (isSpecial1
                                        ? Special1Palette.primaryText
                                        : const Color(0xFFE040FB))
                                    : (isSpecial1
                                        ? Special1Palette.secondaryText
                                        : (isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A))),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Main View Body
              Expanded(
                child: _selectedMode == 1
                    ? _buildPomodoroView(
                        isDark,
                        stopwatchState,
                        isSpecial1,
                        settings.pomodoroFocusMinutes,
                      )
                    : _buildListView(
                        isDark,
                        stopwatchState,
                        isSpecial1,
                        todaySessions,
                        settings.groupSimilar,
                        todayTotalMs,
                      ),
              ),

              // Persistent Running Mini-Player Bottom Bar (like Toggl Track)
              if (stopwatchState.status == StopwatchStatus.running ||
                  stopwatchState.status == StopwatchStatus.paused)
                _buildRunningBottomBar(isDark, stopwatchState, taskDescription, selectedProject, isSpecial1),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPomodoroView(
    bool isDark,
    StopwatchState stopwatchState,
    bool isSpecial1,
    int focusMinutes,
  ) {
    final targetMs = focusMinutes * 60 * 1000;
    final remainingMs = _isPomodoroBreak
        ? _pomodoroBreakRemainingMs
        : (targetMs - stopwatchState.elapsedMs).clamp(0, targetMs);
    final progress = _isPomodoroBreak
        ? (_pomodoroBreakDurationMs == 0
            ? 0.0
            : (1 -
                    _pomodoroBreakRemainingMs /
                        _pomodoroBreakDurationMs)
                .clamp(0.0, 1.0))
        : (stopwatchState.elapsedMs / targetMs).clamp(0.0, 1.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          // "I'm focusing on..." Input Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSpecial1
                  ? Colors.white
                  : (isDark ? const Color(0xFF161122) : Colors.white),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSpecial1
                    ? Special1Palette.inputBorder
                    : (isDark ? const Color(0xFF281F3B) : const Color(0xFFE5E7EB)),
              ),
              boxShadow: isSpecial1
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _taskController,
                    onChanged: (val) =>
                        ref.read(focusTaskDescriptionProvider.notifier).state = val,
                    style: TextStyle(
                      color: isSpecial1
                          ? Special1Palette.primaryText
                          : (isDark ? Colors.white : Colors.black87),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: "I'm focusing on...",
                      hintStyle: TextStyle(
                        color: isSpecial1
                            ? Special1Palette.secondaryText
                            : (isDark ? const Color(0xFF71717A) : const Color(0xFFA1A1AA)),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.local_offer_outlined,
                    size: 20,
                    color: isSpecial1
                        ? Special1Palette.accentRose
                        : const Color(0xFFE040FB),
                  ),
                  tooltip: 'Choose Project',
                  onPressed: () => _showProjectPicker(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 44),

          // Circular Ring Progress Timer (Tap to toggle play/pause)
          GestureDetector(
            onTap: () {
              if (_isPomodoroBreak) {
                if (_pomodoroBreakRunning) {
                  _pausePomodoroBreak();
                } else {
                  _startPomodoroBreak(context);
                }
              } else if (stopwatchState.status == StopwatchStatus.running) {
                ref.read(stopwatchProvider.notifier).pause();
              } else if (stopwatchState.status == StopwatchStatus.paused) {
                ref.read(stopwatchProvider.notifier).resume();
              } else {
                _startNewSession(
                  context,
                  project: ref.read(focusSelectedProjectProvider),
                  description: _taskController.text,
                );
              }
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 250,
                  height: 250,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: isSpecial1 ? 8 : 4,
                    backgroundColor: isSpecial1
                        ? Special1Palette.ringTrack
                        : (isDark ? const Color(0xFF281F3B) : const Color(0xFFE5E7EB)),
                    color: isSpecial1
                        ? Special1Palette.accentRose
                        : const Color(0xFFE040FB),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isPomodoroBreak
                          ? (_isLongBreak ? 'LONG BREAK' : 'SHORT BREAK')
                          : (isSpecial1 ? 'Focus' : 'FOCUS INTERVAL'),
                      style: TextStyle(
                        fontSize: isSpecial1 ? 16 : 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: isSpecial1 ? 0.2 : 1.5,
                        color: isSpecial1
                            ? Special1Palette.primaryText
                            : const Color(0xFFE040FB),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatElapsed(remainingMs),
                      style: TextStyle(
                        fontSize: 54,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.5,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: isSpecial1
                            ? Special1Palette.primaryText
                            : (isDark ? Colors.white : const Color(0xFF111827)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _isPomodoroBreak
                          ? (_pomodoroBreakRunning
                              ? 'Break in progress'
                              : 'Ready for a break?')
                          : (isSpecial1
                              ? (stopwatchState.status == StopwatchStatus.running
                                  ? 'Focusing...'
                                  : 'Ready?')
                              : (stopwatchState.status == StopwatchStatus.running
                                  ? 'SESSION ACTIVE'
                                  : 'READY TO FOCUS')),
                      style: TextStyle(
                        fontSize: isSpecial1 ? 16 : 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: isSpecial1 ? 0.2 : 1.5,
                        color: isSpecial1
                            ? Special1Palette.secondaryText
                            : const Color(0xFFE040FB),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Sound Toggle Button (Matching uploaded image light blue circle)
          if (isSpecial1)
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Special1Palette.soundButton,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(
                  _soundEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                  color: Special1Palette.primaryText,
                  size: 20,
                ),
                tooltip: _soundEnabled ? 'Mute Pomodoro Sound' : 'Enable Pomodoro Sound',
                onPressed: _togglePomodoroSound,
              ),
            )
          else
            IconButton(
              icon: Icon(
                _soundEnabled ? Icons.volume_up_outlined : Icons.volume_off_outlined,
                color: _soundEnabled ? const Color(0xFFE040FB) : Colors.white38,
                size: 26,
              ),
              tooltip: _soundEnabled ? 'Mute Pomodoro Sound' : 'Enable Pomodoro Sound',
              onPressed: _togglePomodoroSound,
            ),
          const SizedBox(height: 20),

          // Big "Start session" Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isSpecial1
                    ? Special1Palette.accentRose
                    : const Color(0xFFE040FB),
                foregroundColor: isSpecial1
                    ? Special1Palette.primaryText
                    : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: isSpecial1 ? 0 : 4,
              ),
              onPressed: () {
                if (_isPomodoroBreak) {
                  if (_pomodoroBreakRunning) {
                    _pausePomodoroBreak();
                  } else {
                    _startPomodoroBreak(context);
                  }
                } else if (stopwatchState.status == StopwatchStatus.running) {
                  ref.read(stopwatchProvider.notifier).pause();
                } else if (stopwatchState.status == StopwatchStatus.paused) {
                  ref.read(stopwatchProvider.notifier).resume();
                } else {
                  _startNewSession(
                    context,
                    project: ref.read(focusSelectedProjectProvider),
                    description: _taskController.text,
                  );
                }
              },
              child: Text(
                _isPomodoroBreak
                    ? (_pomodoroBreakRunning ? 'Pause break' : 'Start break')
                    : (stopwatchState.status == StopwatchStatus.running
                        ? 'Pause session'
                        : (stopwatchState.status == StopwatchStatus.paused
                            ? 'Resume session'
                            : 'Start session')),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isSpecial1 ? Special1Palette.primaryText : Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // "Pomodoro settings ▶" Link
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TogglSettingsScreen()),
              );
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Pomodoro settings',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isSpecial1
                        ? Special1Palette.primaryText
                        : const Color(0xFFE040FB),
                  ),
                ),
                if (isSpecial1) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_right_rounded, size: 20, color: Special1Palette.primaryText),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListView(
    bool isDark,
    StopwatchState stopwatchState,
    bool isSpecial1,
    List<ReadingSession> todaySessions,
    bool groupSimilar,
    int todayTotalMs,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Getting Started Progress Card matching Toggl Track UI
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161122) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? const Color(0xFF281F3B) : const Color(0xFFE5E7EB),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Getting started!',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                    Icon(Icons.keyboard_arrow_down_rounded,
                        color: isDark ? Colors.white54 : Colors.black54),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: const LinearProgressIndicator(
                    value: 0.33,
                    minHeight: 4,
                    backgroundColor: Color(0xFF281F3B),
                    color: Color(0xFFE040FB),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '33% completed - You can do this!',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // TODAY Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TODAY',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
              Text(
                _formatElapsed(todayTotalMs),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (todaySessions.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161122) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF281F3B)
                      : const Color(0xFFE5E7EB),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.menu_book_outlined,
                    size: 28,
                    color: isDark
                        ? const Color(0xFFA1A1AA)
                        : const Color(0xFF9CA3AF),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No reading sessions today',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Start a focus session to see it here.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? const Color(0xFFA1A1AA)
                          : const Color(0xFF71717A),
                    ),
                  ),
                ],
              ),
            )
          else
            ..._buildTodaySessionCards(
              context,
              todaySessions,
              groupSimilar: groupSimilar,
              isDark: isDark,
            ),
          const SizedBox(height: 48),

          // "Keep tracking" Motivational Callout
          Center(
            child: Column(
              children: [
                const Text('👏', style: TextStyle(fontSize: 42)),
                const SizedBox(height: 12),
                Text(
                  'Keep tracking',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Make sure to explore all the features available.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => _showWhatsIncludedDialog(context, isDark),
                  child: const Text(
                    "What's included?",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      decoration: TextDecoration.underline,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  List<Widget> _buildTodaySessionCards(
    BuildContext context,
    List<ReadingSession> sessions, {
    required bool groupSimilar,
    required bool isDark,
  }) {
    final groups = <String, List<ReadingSession>>{};
    for (final session in sessions) {
      final key = groupSimilar
          ? '${session.subjectId ?? 'General Focus'}|${session.note ?? ''}'
          : session.id;
      groups.putIfAbsent(key, () => []).add(session);
    }
    return groups.values.map((group) {
      final latest = group.last;
      final durationMs =
          group.fold<int>(0, (sum, session) => sum + session.durationMs);
      final description = latest.note ?? '';
      final project = latest.subjectName;
      final title = description.isEmpty ? project : description;
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161122) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF281F3B)
                  : const Color(0xFFE5E7EB),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      group.length > 1
                          ? '$project • ${group.length} similar entries'
                          : project,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? const Color(0xFFA1A1AA)
                            : const Color(0xFF71717A),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _formatElapsed(durationMs),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              IconButton(
                tooltip: 'Start this session again',
                icon: const Icon(
                  Icons.play_arrow_rounded,
                  color: Color(0xFFE040FB),
                ),
                onPressed: () {
                  ref.read(focusTaskDescriptionProvider.notifier).state =
                      description;
                  ref.read(focusSelectedProjectProvider.notifier).state =
                      project;
                  _taskController.text = description;
                  _startNewSession(
                    context,
                    project: project,
                    description: description,
                  );
                },
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildRunningBottomBar(
    bool isDark,
    StopwatchState stopwatchState,
    String description,
    String project,
    bool isSpecial1,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isSpecial1
            ? Special1Palette.background
            : (isDark ? const Color(0xFF181126) : Colors.white),
        border: Border(
          top: BorderSide(
            color: isSpecial1
                ? Special1Palette.inputBorder
                : (isDark ? const Color(0xFF2E2242) : const Color(0xFFE5E7EB)),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatElapsed(stopwatchState.elapsedMs),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: isSpecial1
                          ? Special1Palette.primaryText
                          : (isDark ? Colors.white : const Color(0xFF111827)),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description.isNotEmpty ? description : '+ Add description',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isSpecial1
                          ? Special1Palette.primaryText
                          : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isSpecial1
                              ? Special1Palette.accentRose
                              : const Color(0xFFE040FB),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        project,
                        style: TextStyle(
                          fontSize: 11,
                          color: isSpecial1
                              ? Special1Palette.secondaryText
                              : (isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Stop Button (matching uploaded image pastel rose button)
            InkWell(
              onTap: () => _stopCurrentSession(context),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSpecial1
                      ? Special1Palette.stopButton
                      : const Color(0xFFF87171),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: isSpecial1
                          ? Special1Palette.primaryText
                          : Colors.white,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFFE040FB)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFFE4E4E7) : const Color(0xFF374151),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
