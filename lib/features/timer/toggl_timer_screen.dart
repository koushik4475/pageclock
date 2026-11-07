import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/engine/stopwatch_engine.dart';
import '../../core/models/reading_session.dart';
import '../../core/repository/session_repository.dart';
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

  @override
  void initState() {
    super.initState();
    _taskController = TextEditingController(
      text: ref.read(focusTaskDescriptionProvider),
    );
  }

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }

  void _showAddEntryModal(BuildContext context) {
    final descCtrl = TextEditingController();
    final minsCtrl = TextEditingController(text: '30');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF140E20) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
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
                    subjectId: 'General Focus',
                    note: desc.isNotEmpty ? desc : 'Manual Time Log',
                    source: 'manual',
                    createdAt: now.millisecondsSinceEpoch,
                    updatedAt: now.millisecondsSinceEpoch,
                  );
                  await ref.read(sessionRepositoryProvider).insertSession(session);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save Entry', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stopwatchState = ref.watch(stopwatchProvider);
    final taskDescription = ref.watch(focusTaskDescriptionProvider);
    final selectedProject = ref.watch(focusSelectedProjectProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0B15) : const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F0B15) : const Color(0xFFF9FAFB),
        elevation: 0,
        title: Text(
          'Timer',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add_circle_outline_rounded,
                color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A)),
            tooltip: 'Add Manual Time Entry',
            onPressed: () => _showAddEntryModal(context),
          ),
          IconButton(
            icon: Icon(Icons.fullscreen_rounded,
                color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A)),
            tooltip: 'Mac Retro Flip Clock Mode',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AppleMacFlipClockScreen(
                    elapsedMs: stopwatchState.elapsedMs,
                    targetMinutes: _selectedMode == 1 ? 25 : null,
                    description: taskDescription,
                    projectName: selectedProject,
                    isRunning: stopwatchState.status == StopwatchStatus.running,
                    onStop: () => ref.read(stopwatchProvider.notifier).stop(),
                    onTogglePlay: () {
                      if (stopwatchState.status == StopwatchStatus.running) {
                        ref.read(stopwatchProvider.notifier).pause();
                      } else {
                        ref.read(stopwatchProvider.notifier).start();
                      }
                    },
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.settings_outlined,
                color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A)),
            tooltip: 'Settings',
            onPressed: () {
              ref.read(mainTabNavigationIndexProvider.notifier).state = 3;
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Segmented Tabs: List view | Pomodoro
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1B1426) : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedMode = 0),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: _selectedMode == 0
                            ? BoxDecoration(
                                color: isDark ? const Color(0xFF2C1B42) : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
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
                                ? const Color(0xFFE040FB)
                                : (isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedMode = 1),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: _selectedMode == 1
                            ? BoxDecoration(
                                color: isDark ? const Color(0xFF2C1B42) : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
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
                                ? const Color(0xFFE040FB)
                                : (isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A)),
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
                ? _buildPomodoroView(isDark, stopwatchState)
                : _buildListView(isDark, stopwatchState),
          ),

          // Persistent Running Mini-Player Bottom Bar (like Toggl Track)
          if (stopwatchState.status == StopwatchStatus.running ||
              stopwatchState.status == StopwatchStatus.paused)
            _buildRunningBottomBar(isDark, stopwatchState, taskDescription, selectedProject),
        ],
      ),
    );
  }

  Widget _buildPomodoroView(bool isDark, StopwatchState stopwatchState) {
    const targetMs = 25 * 60 * 1000;
    final remainingMs = (targetMs - stopwatchState.elapsedMs).clamp(0, targetMs);
    final progress = (stopwatchState.elapsedMs / targetMs).clamp(0.0, 1.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          // "I'm focusing on..." Input Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161122) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? const Color(0xFF281F3B) : const Color(0xFFE5E7EB),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _taskController,
                    onChanged: (val) =>
                        ref.read(focusTaskDescriptionProvider.notifier).state = val,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: "I'm focusing on...",
                      hintStyle: TextStyle(
                        color: isDark ? const Color(0xFF71717A) : const Color(0xFFA1A1AA),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                Icon(
                  Icons.local_offer_outlined,
                  size: 18,
                  color: const Color(0xFFE040FB),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),

          // Circular Ring Progress Timer
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 240,
                height: 240,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 4,
                  backgroundColor: isDark ? const Color(0xFF281F3B) : const Color(0xFFE5E7EB),
                  color: const Color(0xFFE040FB),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatElapsed(remainingMs),
                    style: TextStyle(
                      fontSize: 54,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.5,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    stopwatchState.status == StopwatchStatus.running
                        ? 'FOCUS INTERVAL'
                        : 'READY TO FOCUS',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: Color(0xFFE040FB),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 36),

          // Sound Toggle Button
          IconButton(
            icon: const Icon(Icons.volume_up_outlined, color: Colors.white60, size: 26),
            onPressed: () {},
          ),
          const SizedBox(height: 20),

          // Big "Start session" Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE040FB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 4,
              ),
              onPressed: () {
                if (stopwatchState.status == StopwatchStatus.running) {
                  ref.read(stopwatchProvider.notifier).pause();
                } else if (stopwatchState.status == StopwatchStatus.paused) {
                  ref.read(stopwatchProvider.notifier).resume();
                } else {
                  ref.read(stopwatchProvider.notifier).start();
                }
              },
              child: Text(
                stopwatchState.status == StopwatchStatus.running ? 'Pause session' : 'Start session',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // "Pomodoro settings" Link
          TextButton(
            onPressed: () {},
            child: const Text(
              'Pomodoro settings',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFFE040FB),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListView(bool isDark, StopwatchState stopwatchState) {
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
                _formatElapsed(stopwatchState.elapsedMs),
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

          // Time entry card
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
                      'Deep Work & Focus',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '0:45:00',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.play_arrow_rounded, color: Color(0xFFE040FB), size: 22),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      '@ reading a project',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFFE040FB),
                      ),
                    ),
                  ],
                ),
              ],
            ),
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
                  onPressed: () {},
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

  Widget _buildRunningBottomBar(
    bool isDark,
    StopwatchState stopwatchState,
    String description,
    String project,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181126) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF2E2242) : const Color(0xFFE5E7EB),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
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
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description.isNotEmpty ? description : '+ Add description',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE040FB),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        project,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Red Square Stop Button matching Toggl Track UI
            InkWell(
              onTap: () => ref.read(stopwatchProvider.notifier).stop(),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFFF87171), // Salmon red Toggl stop button
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white,
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
