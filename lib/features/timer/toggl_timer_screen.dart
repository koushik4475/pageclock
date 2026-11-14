import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/engine/stopwatch_engine.dart';
import '../../core/engine/pomodoro_clock.dart';
import '../../core/engine/pomodoro_break_snapshot.dart';
import '../../core/format/formatters.dart';
import '../../core/models/reading_session.dart';
import '../../core/repository/session_repository.dart';
import '../../core/settings/app_settings.dart';
import '../../core/services/notification_service.dart';
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
  int? _pomodoroBreakEndsAtUtcMs;
  Timer? _pomodoroBreakTicker;
  Future<void> _pomodoroPersistenceQueue = Future<void>.value();

  static const _pomodoroBreakStateKey = 'pageclock_pomodoro_break_state_v1';
  static const _pomodoroCompletedSessionsKey = 'pageclock_pomodoro_completed_focus_sessions_v1';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_restorePomodoroState());
    });
  }

  @override
  void dispose() {
    _pomodoroBreakTicker?.cancel();
    _taskController.dispose();
    super.dispose();
  }

  void _showAddEntryModal(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final descCtrl = TextEditingController();
    final minsCtrl = TextEditingController(text: '30');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String selectedProj = ref.read(focusSelectedProjectProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
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
                      labelStyle: TextStyle(color: isDark ? Theme.of(context).colorScheme.onSurfaceVariant : Theme.of(context).colorScheme.onSurfaceVariant),
                      filled: true,
                      fillColor: isDark ? Theme.of(context).colorScheme.surface : const Color(0xFFF3F4F6),
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
                      labelStyle: TextStyle(color: isDark ? Theme.of(context).colorScheme.onSurfaceVariant : Theme.of(context).colorScheme.onSurfaceVariant),
                      filled: true,
                      fillColor: isDark ? Theme.of(context).colorScheme.surface : const Color(0xFFF3F4F6),
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
                      color: isDark ? Theme.of(context).colorScheme.onSurfaceVariant : Theme.of(context).colorScheme.onSurfaceVariant,
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
                        selectedColor: accent,
                        backgroundColor: isDark ? Theme.of(context).colorScheme.surface : Theme.of(context).colorScheme.outline,
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
                        backgroundColor: accent,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        final mins = int.tryParse(minsCtrl.text.trim());
                        if (mins == null || mins <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Enter a duration greater than zero minutes.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                          return;
                        }
                        final desc = descCtrl.text.trim();
                        final now = DateTime.now();
                        final durationMs = mins * 60 * 1000;
                        final session = ReadingSession(
                          id: now.microsecondsSinceEpoch.toString(),
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

  void _showEditEntryModal(BuildContext context, ReadingSession session) {
    var description = session.note ?? '';
    var durationText =
        (session.durationMs / 60000).round().clamp(1, 525600).toString();
    final projects = <String>{
      ..._availableProjects,
      session.subjectName,
    }.toList();
    var selectedProject = session.subjectName;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.of(sheetContext).viewInsets.bottom + 24,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Edit Time Entry',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close editor',
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: description,
                      onChanged: (value) => description = value,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: durationText,
                      onChanged: (value) => durationText = value,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Duration (minutes)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The original end time is kept. The start time is adjusted to match the new duration.',
                      style: Theme.of(sheetContext).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'PROJECT',
                      style: Theme.of(sheetContext).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: projects.map((project) {
                        final selected = selectedProject == project;
                        return ChoiceChip(
                          label: Text(project),
                          selected: selected,
                          onSelected: (_) =>
                              setSheetState(() => selectedProject = project),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: () async {
                          final minutes =
                              int.tryParse(durationText.trim());
                          if (minutes == null || minutes <= 0 || minutes > 525600) {
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Enter a duration between 1 minute and 1 year.',
                                ),
                              ),
                            );
                            return;
                          }

                          // Dismiss the keyboard before the bottom sheet removes
                          // its editable fields; this avoids a pending caret callback
                          // targeting a detached RenderEditable during route teardown.
                          FocusScope.of(sheetContext).unfocus();
                          // Let any scheduled EditableText caret/scroll work
                          // finish while the editor is still attached.
                          await WidgetsBinding.instance.endOfFrame;
                          final now =
                              DateTime.now().toUtc().millisecondsSinceEpoch;
                          final durationMs = minutes * 60000;
                          final descriptionText = description.trim();
                          final updated = session.copyWith(
                            subjectId: selectedProject,
                            note: descriptionText,
                            clearNote: descriptionText.isEmpty,
                            durationMs: durationMs,
                            startedAtUtc:
                                session.endedAtUtc! -
                                session.pausedTotalMs -
                                durationMs,
                            updatedAt: now,
                          );

                          try {
                            await ref
                                .read(sessionRepositoryProvider)
                                .updateSession(updated);
                            if (sheetContext.mounted) {
                              Navigator.pop(sheetContext);
                            }
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Time entry updated.'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } catch (_) {
                            if (sheetContext.mounted) {
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Could not save this entry. Please try again.',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        child: const Text('Save Changes'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteSessionWithUndo(
    BuildContext context,
    ReadingSession session,
  ) async {
    // Capture the screen-level messenger before deleting. The list stream
    // removes this row immediately, so the row's BuildContext may be unmounted
    // by the time the repository write completes.
    final messenger = ScaffoldMessenger.of(context);
    final deletedAt = DateTime.now().toUtc().millisecondsSinceEpoch;

    try {
      await ref
          .read(sessionRepositoryProvider)
          .softDeleteSession(session.id, deletedAt: deletedAt);
    } catch (_) {
      if (messenger.mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Could not delete this entry. Please try again.'),
          ),
        );
      }
      return;
    }

    if (!messenger.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: const Text('Time entry deleted.'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () {
            unawaited(_restoreDeletedSession(
              messenger,
              session,
              deletedAt,
            ));
          },
        ),
      ),
    );
  }

  Future<void> _restoreDeletedSession(
    ScaffoldMessengerState messenger,
    ReadingSession session,
    int expectedDeletedAt,
  ) async {
    try {
      final restored = await ref
          .read(sessionRepositoryProvider)
          .restoreSoftDeletedSession(
            session: session,
            expectedDeletedAt: expectedDeletedAt,
          );
      if (!restored && messenger.mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'This entry changed after deletion and could not be restored.',
            ),
          ),
        );
      }
    } catch (_) {
      if (messenger.mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Could not restore this entry. Please try again.'),
          ),
        );
      }
    }
  }

  void _showProjectPicker(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
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
                    color: Theme.of(ctx).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                ..._availableProjects.map((p) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.circle, color: accent, size: 14),
                    title: Text(
                      p,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    trailing: ref.read(focusSelectedProjectProvider) == p
                        ? Icon(Icons.check_rounded, color: accent)
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
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "What's Included in Productivity",
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Theme.of(ctx).colorScheme.onSurface,
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
            child: Text('Got it', style: TextStyle(color: Theme.of(ctx).colorScheme.primary, fontWeight: FontWeight.w700)),
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
    _triggerHaptic();
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
    _triggerHaptic();
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
    _triggerHaptic();
    return true;
  }


  Future<void> _restorePomodoroState() async {
    final preferences = ref.read(sharedPreferencesProvider);
    final completedSessions = preferences.getInt(_pomodoroCompletedSessionsKey);
    if (completedSessions != null && completedSessions >= 0) {
      _pomodoroCompletedFocusSessions = completedSessions;
    }

    final snapshot = PomodoroBreakSnapshot.tryParse(
      preferences.getString(_pomodoroBreakStateKey),
    );
    if (snapshot == null || !mounted) return;

    final nowUtcMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    final remainingMs = snapshot.remainingAt(nowUtcMs);
    setState(() {
      _isPomodoroBreak = true;
      _isLongBreak = snapshot.isLongBreak;
      _pomodoroBreakDurationMs = snapshot.durationMs;
      _pomodoroBreakRemainingMs = remainingMs;
      _pomodoroBreakRunning = snapshot.isRunning && remainingMs > 0;
      _pomodoroBreakEndsAtUtcMs =
          snapshot.isRunning ? snapshot.deadlineUtcMs : null;
    });

    if (remainingMs <= 0) {
      _completePomodoroBreak(context);
    } else if (snapshot.isRunning) {
      // Recreate the ticker from the persisted deadline. The deadline, not
      // the number of callbacks, remains the source of truth after a restart.
      _startPomodoroBreak(context);
    }
  }

  Future<void> _persistPomodoroBreakState() {
    final preferences = ref.read(sharedPreferencesProvider);
    final serialized = !_isPomodoroBreak || _pomodoroBreakDurationMs <= 0
        ? null
        : PomodoroBreakSnapshot(
            isLongBreak: _isLongBreak,
            durationMs: _pomodoroBreakDurationMs,
            remainingMs: _pomodoroBreakRemainingMs,
            isRunning: _pomodoroBreakRunning,
            deadlineUtcMs: _pomodoroBreakEndsAtUtcMs,
          ).toJson();

    // Serialize preference writes so a rapid start/pause sequence cannot let
    // an older asynchronous write overwrite the newest break state.
    _pomodoroPersistenceQueue = _pomodoroPersistenceQueue.then((_) async {
      if (serialized == null) {
        await preferences.remove(_pomodoroBreakStateKey);
      } else {
        await preferences.setString(_pomodoroBreakStateKey, serialized);
      }
    }).catchError((Object error) {
      debugPrint('[Pomodoro] Failed to persist break state: $error');
    });
    return _pomodoroPersistenceQueue;
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
    await ref.read(sharedPreferencesProvider).setInt(
          _pomodoroCompletedSessionsKey,
          _pomodoroCompletedFocusSessions,
        );
    if (!mounted) return;
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
    await _persistPomodoroBreakState();
    if (!mounted) return;

    unawaited(NotificationService.showPomodoroComplete(
      settings,
      title: 'Focus session complete',
      body: 'Time for a ${longBreakDue ? 'long' : 'short'} break.',
    ));
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
    // Use an absolute deadline so delayed callbacks (for example after the
    // app resumes from the background) do not make the break run slow.
    _pomodoroBreakEndsAtUtcMs ??= PomodoroClock.deadlineAfter(
      nowUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch,
      remainingMs: _pomodoroBreakRemainingMs,
    );
    setState(() => _pomodoroBreakRunning = true);
    unawaited(_persistPomodoroBreakState());
    _pomodoroBreakTicker = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        final deadline = _pomodoroBreakEndsAtUtcMs;
        if (deadline == null) {
          timer.cancel();
          return;
        }
        final remaining = PomodoroClock.remaining(
          deadlineUtcMs: deadline,
          nowUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch,
          maximumMs: _pomodoroBreakDurationMs,
        );
        if (remaining <= 0) {
          timer.cancel();
          _pomodoroBreakRemainingMs = 0;
          _pomodoroBreakEndsAtUtcMs = null;
          _completePomodoroBreak(context);
        } else {
          setState(() => _pomodoroBreakRemainingMs = remaining);
        }
      },
    );
  }

  void _pausePomodoroBreak() {
    _pomodoroBreakTicker?.cancel();
    final deadline = _pomodoroBreakEndsAtUtcMs;
    if (deadline != null) {
      _pomodoroBreakRemainingMs = PomodoroClock.remaining(
        deadlineUtcMs: deadline,
        nowUtcMs: DateTime.now().toUtc().millisecondsSinceEpoch,
        maximumMs: _pomodoroBreakDurationMs,
      );
    }
    _pomodoroBreakEndsAtUtcMs = null;
    setState(() => _pomodoroBreakRunning = false);
    unawaited(_persistPomodoroBreakState());
  }

  void _completePomodoroBreak(BuildContext context) {
    final settings = ref.read(settingsProvider);
    final autoStart = settings.pomodoroAutoStart;
    unawaited(NotificationService.showPomodoroComplete(
      settings,
      title: 'Break complete',
      body: 'Ready for another focus session?',
    ));
    if (settings.pomodoroSoundEnabled) {
      SystemSound.play(SystemSoundType.alert);
    }
    setState(() {
      _isPomodoroBreak = false;
      _isLongBreak = false;
      _pomodoroBreakRunning = false;
      _pomodoroBreakDurationMs = 0;
      _pomodoroBreakRemainingMs = 0;
      _pomodoroBreakEndsAtUtcMs = null;
    });
    unawaited(_persistPomodoroBreakState());
    final stopwatchState = ref.read(stopwatchProvider);
    if (autoStart &&
        stopwatchState.status == StopwatchStatus.idle &&
        stopwatchState.currentSession == null) {
      _startNewSession(
        context,
        project: ref.read(focusSelectedProjectProvider),
        description: _taskController.text,
      );
    }
  }

  void _triggerHaptic() {
    if (ref.read(settingsProvider).enableHaptics) {
      HapticFeedback.selectionClick();
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
    final colorScheme = Theme.of(context).colorScheme;
    final accent = colorScheme.primary;
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
      unawaited(
        NotificationService.syncTimer(next, ref.read(settingsProvider)),
      );
      if (_selectedMode != 1 || _isPomodoroBreak || previous == null) return;
      final focusTargetMs = ref.read(settingsProvider).pomodoroFocusMinutes * 60000;
      if (previous.elapsedMs < focusTargetMs &&
          next.elapsedMs >= focusTargetMs &&
          next.status == StopwatchStatus.running) {
        _completePomodoroFocus(context);
      }
    });
    ref.listen<AppSettings>(settingsProvider, (previous, next) {
      unawaited(
        NotificationService.syncTimer(ref.read(stopwatchProvider), next),
      );
      final reminderChanged = previous == null ||
          previous.notificationsEnabled != next.notificationsEnabled ||
          previous.smartDailyReminder != next.smartDailyReminder ||
          previous.dailyReminderHour != next.dailyReminderHour ||
          previous.dailyReminderMinute != next.dailyReminderMinute;
      if (reminderChanged) {
        unawaited(NotificationService.scheduleDailyReminder(next));
      }
    });
    final appThemeId = ref.watch(appThemeIdProvider);
    final isSpecial1 = appThemeId == AppThemeId.special1;

    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    final headerIconColor = isSpecial1
        ? Special1Palette.primaryText
        : colorScheme.onSurfaceVariant;

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
                : colorScheme.onSurface,
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
                        : (isDark ? Theme.of(context).colorScheme.surface : Theme.of(context).colorScheme.outline),
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
                                        : (isDark ? Theme.of(context).colorScheme.surface : Colors.white),
                                    borderRadius: BorderRadius.circular(10),
                                    border: isSpecial1
                                        ? null
                                        : Border.all(
                                            color: accent.withOpacity(0.4),
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
                                        : accent)
                                    : (isSpecial1
                                        ? Special1Palette.secondaryText
                                        : (isDark ? Theme.of(context).colorScheme.onSurfaceVariant : Theme.of(context).colorScheme.onSurfaceVariant)),
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
                                        : (isDark ? Theme.of(context).colorScheme.surface : Colors.white),
                                    borderRadius: BorderRadius.circular(10),
                                    border: isSpecial1
                                        ? null
                                        : Border.all(
                                            color: accent.withOpacity(0.4),
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
                                        : accent)
                                    : (isSpecial1
                                        ? Special1Palette.secondaryText
                                        : (isDark ? Theme.of(context).colorScheme.onSurfaceVariant : Theme.of(context).colorScheme.onSurfaceVariant)),
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
                        colorScheme,
                        accent,
                      )
                    : _buildListView(
                        context,
                        isDark,
                        stopwatchState,
                        isSpecial1,
                        todaySessions,
                        settings.groupSimilar,
                        todayTotalMs,
                        settings.dailyGoalMinutes,
                        settings.durationFormat,
                        colorScheme,
                        accent,
                      ),
              ),

              // Persistent Running Mini-Player Bottom Bar (like Toggl Track)
              if (stopwatchState.status == StopwatchStatus.running ||
                  stopwatchState.status == StopwatchStatus.paused)
                _buildRunningBottomBar(context, isDark, stopwatchState, taskDescription, selectedProject, isSpecial1, colorScheme, accent),
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
    ColorScheme colorScheme,
    Color accent,
  ) {
    final targetMs = focusMinutes * 60 * 1000;
    final isFocusOvertime = !_isPomodoroBreak &&
        stopwatchState.status != StopwatchStatus.idle &&
        stopwatchState.elapsedMs >= targetMs;
    final remainingMs = _isPomodoroBreak
        ? _pomodoroBreakRemainingMs
        : (isFocusOvertime
            ? stopwatchState.elapsedMs - targetMs
            : (targetMs - stopwatchState.elapsedMs).clamp(0, targetMs));
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
                  : (isDark ? colorScheme.surface : Colors.white),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSpecial1
                    ? Special1Palette.inputBorder
                    : (isDark ? colorScheme.outline.withOpacity(0.25) : colorScheme.outline),
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
                            : (isDark ? colorScheme.onSurfaceVariant : colorScheme.onSurfaceVariant),
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
                        : accent,
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
                        : (isDark ? colorScheme.outline : colorScheme.outline),
                    color: isSpecial1
                        ? Special1Palette.accentRose
                        : accent,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isPomodoroBreak
                          ? (_isLongBreak ? 'LONG BREAK' : 'SHORT BREAK')
                          : (isFocusOvertime
                              ? 'OVERTIME'
                              : (isSpecial1 ? 'Focus' : 'FOCUS INTERVAL')),
                      style: TextStyle(
                        fontSize: isSpecial1 ? 16 : 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: isSpecial1 ? 0.2 : 1.5,
                        color: isSpecial1
                            ? Special1Palette.primaryText
                            : accent,
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
                            : (isDark ? Colors.white : colorScheme.onSurface),
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
                            : accent,
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
                color: _soundEnabled ? accent : colorScheme.onSurfaceVariant,
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
                    : accent,
                foregroundColor: isSpecial1
                    ? Special1Palette.primaryText
                    : colorScheme.onPrimary,
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
                  color: isSpecial1 ? Special1Palette.primaryText : colorScheme.onPrimary,
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
                        : accent,
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
    BuildContext context,
    bool isDark,
    StopwatchState stopwatchState,
    bool isSpecial1,
    List<ReadingSession> todaySessions,
    bool groupSimilar,
    int todayTotalMs,
    int dailyGoalMinutes,
    String durationFormat,
    ColorScheme colorScheme,
    Color accent,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Daily focus goal reflects actual tracked time, including
          // the currently running session, instead of a static onboarding value.
          Builder(
            builder: (context) {
              final goalMinutes = dailyGoalMinutes.clamp(1, 1440).toInt();
              final goalMs = goalMinutes * 60 * 1000;
              final progress = (todayTotalMs / goalMs).clamp(0.0, 1.0).toDouble();
              final percent = (progress * 100).round();
              final remainingMs = (goalMs - todayTotalMs).clamp(0, goalMs).toInt();
              final achieved = todayTotalMs >= goalMs;
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colorScheme.outline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Daily focus goal',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          '$percent%',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: accent,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: colorScheme.outline.withOpacity(0.22),
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(todayTotalMs / 60000).floor()} / $goalMinutes min tracked',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      achieved
                          ? 'Daily goal achieved. Great work!'
                          : '${AppFormatters.formatDuration(remainingMs, format: durationFormat)} left to reach your goal.',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            },
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
                  color: isDark ? Colors.white : Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Text(
                AppFormatters.formatDuration(todayTotalMs, format: durationFormat),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: isDark ? Theme.of(context).colorScheme.onSurfaceVariant : Theme.of(context).colorScheme.onSurfaceVariant,
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
                color: isDark ? Theme.of(context).colorScheme.surface : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? Theme.of(context).colorScheme.outline
                      : Theme.of(context).colorScheme.outline,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.menu_book_outlined,
                    size: 28,
                    color: isDark
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No reading sessions today',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Start a focus session to see it here.',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? Theme.of(context).colorScheme.onSurfaceVariant
                          : Theme.of(context).colorScheme.onSurfaceVariant,
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
              durationFormat: durationFormat,
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
                    color: isDark ? Colors.white : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Make sure to explore all the features available.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Theme.of(context).colorScheme.onSurfaceVariant : Theme.of(context).colorScheme.onSurfaceVariant,
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
    required String durationFormat,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = colorScheme.primary;
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
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? Theme.of(context).colorScheme.outline
                  : Theme.of(context).colorScheme.outline,
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
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      group.length > 1
                          ? '$project • ${group.length} similar entries'
                          : project,
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                AppFormatters.formatDuration(durationMs, format: durationFormat),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              if (group.length == 1 && latest.endedAtUtc != null)
                PopupMenuButton<String>(
                  tooltip: 'Entry actions',
                  onSelected: (action) {
                    if (action == 'edit') {
                      _showEditEntryModal(context, latest);
                    } else if (action == 'delete') {
                      unawaited(_deleteSessionWithUndo(context, latest));
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit entry'),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete entry'),
                    ),
                  ],
                ),
              IconButton(
                tooltip: 'Start this session again',
                icon: Icon(
                  Icons.play_arrow_rounded,
                  color: accent,
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
    BuildContext context,
    bool isDark,
    StopwatchState stopwatchState,
    String description,
    String project,
    bool isSpecial1,
    ColorScheme colorScheme,
    Color accent,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isSpecial1
            ? Special1Palette.background
            : colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: isSpecial1
                ? Special1Palette.inputBorder
                : colorScheme.outline,
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
                          : colorScheme.onSurface,
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
                          : colorScheme.onSurface,
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
                              : accent,
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
                              : colorScheme.onSurfaceVariant,
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
                      : colorScheme.error,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: isSpecial1
                          ? Special1Palette.primaryText
                          : colorScheme.onError,
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
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark ? Theme.of(context).colorScheme.onSurface : const Color(0xFF374151),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
