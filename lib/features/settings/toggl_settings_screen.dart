import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/engine/stopwatch_engine.dart';
import '../../core/format/formatters.dart';
import '../../core/models/reading_session.dart';
import '../../core/repository/session_repository.dart';
import '../../core/services/export_service.dart';
import '../../core/services/pdf_service.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/theme_provider.dart';

/// Full Production Settings Screen matching Toggl Track UI
/// References:
/// - photo_2026-11-07_16-19-39.jpg
/// - photo_2026-11-07_16-19-45.jpg
/// - photo_2026-11-07_16-19-50.jpg
/// - photo_2026-11-07_16-19-55.jpg
class TogglSettingsScreen extends ConsumerStatefulWidget {
  const TogglSettingsScreen({super.key});

  @override
  ConsumerState<TogglSettingsScreen> createState() => _TogglSettingsScreenState();
}

class _TogglSettingsScreenState extends ConsumerState<TogglSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);

    final localTzName = DateTime.now().timeZoneName;
    final localTzOffset = DateTime.now().timeZoneOffset;
    final hoursOffset = localTzOffset.inHours;
    final minsOffset = (localTzOffset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    final sign = hoursOffset >= 0 ? '+' : '-';
    final tzFormatted = '(GMT$sign${hoursOffset.abs().toString().padLeft(2, '0')}:$minsOffset) $localTzName';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0B15) : const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F0B15) : const Color(0xFFF9FAFB),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          'Settings',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // WORKSPACE Section
            _buildSectionHeader('WORKSPACE', isDark),
            _buildCard(
              isDark,
              [
                _buildTile(
                  title: 'Workspace',
                  subtitle: 'Personal Workspace',
                  isDark: isDark,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Personal offline workspace is active.'),
                        duration: Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                _buildDivider(isDark),
                _buildTile(
                  title: 'Your Plan',
                  subtitle: 'Offline First (Local Storage)',
                  isDark: isDark,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Offline First plan active. 100% private with no paid tiers.'),
                        duration: Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            // GOALS & CONSISTENCY Section
            _buildSectionHeader('GOALS & CONSISTENCY', isDark),
            _buildCard(
              isDark,
              [
                _buildTile(
                  title: 'Daily reading goal',
                  subtitle: '${settings.dailyGoalMinutes} minutes / day',
                  isDark: isDark,
                  onTap: () => _showGoalDialog(context, settings),
                ),
                _buildDivider(isDark),
                _buildTile(
                  title: 'Streak threshold',
                  subtitle: '${settings.streakThresholdMinutes} minutes minimum to count toward streak',
                  isDark: isDark,
                  onTap: () => _showStreakThresholdDialog(context, settings),
                ),
                _buildDivider(isDark),
                _buildTile(
                  title: 'Consistency window',
                  subtitle: '${settings.consistencyWindowDays} days',
                  isDark: isDark,
                  onTap: () => _showConsistencyWindowPicker(context, settings),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // YOUR PROFILE Section
            _buildSectionHeader('YOUR PROFILE', isDark),
            _buildCard(
              isDark,
              [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Device details and environment',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildProfileRow('Account Mode', 'Local / Anonymous', isDark),
                      const SizedBox(height: 10),
                      _buildProfileRow('Device Timezone', tzFormatted, isDark),
                      const SizedBox(height: 10),
                      _buildProfileRow('Cloud Sync', 'None (100% Private)', isDark),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // DATE AND TIME Section
            _buildSectionHeader('DATE AND TIME', isDark),
            _buildCard(
              isDark,
              [
                _buildTile(
                  title: 'Date format',
                  subtitle: settings.dateFormat,
                  isDark: isDark,
                  onTap: () => _showDateFormatPicker(context, settings),
                ),
                _buildDivider(isDark),
                _buildSwitchTile(
                  title: 'Use 24-hour clock',
                  value: settings.use24HourClock,
                  onChanged: (v) => settingsNotifier.update((s) => s.copyWith(use24HourClock: v)),
                  isDark: isDark,
                ),
                _buildDivider(isDark),
                _buildTile(
                  title: 'Duration format',
                  subtitle: settings.durationFormat == 'digital' ? 'Digital (0:47:06)' : 'Human (47m 6s)',
                  isDark: isDark,
                  onTap: () => _showDurationFormatPicker(context, settings),
                ),
                _buildDivider(isDark),
                _buildTile(
                  title: 'First day of the week',
                  subtitle: settings.weekStartDay == DateTime.sunday ? 'Sunday' : 'Monday',
                  isDark: isDark,
                  onTap: () => _showWeekStartPicker(context, settings),
                ),
                _buildDivider(isDark),
                _buildSwitchTile(
                  title: 'Group similar time entries',
                  value: settings.groupSimilar,
                  onChanged: (v) => settingsNotifier.update((s) => s.copyWith(groupSimilar: v)),
                  isDark: isDark,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // TIMER DEFAULTS Section
            _buildSectionHeader('TIMER DEFAULTS', isDark),
            _buildCard(
              isDark,
              [
                _buildTile(
                  title: 'Pomodoro intervals',
                  subtitle: '${settings.pomodoroFocusMinutes} min focus • ${settings.pomodoroShortBreakMinutes} min break • ${settings.pomodoroLongBreakMinutes} min long break',
                  isDark: isDark,
                  onTap: () => _showPomodoroSettingsDialog(context, settings),
                ),
                _buildDivider(isDark),
                _buildTile(
                  title: 'Minimum session duration',
                  subtitle: '${settings.minSessionSeconds} seconds (prompts to discard if stopped sooner)',
                  isDark: isDark,
                  onTap: () => _showMinDurationPicker(context, settings),
                ),
                _buildDivider(isDark),
                _buildSwitchTile(
                  title: 'Pomodoro sound & chime',
                  value: settings.pomodoroSoundEnabled,
                  onChanged: (v) => settingsNotifier.update((s) => s.copyWith(pomodoroSoundEnabled: v)),
                  isDark: isDark,
                ),
                _buildDivider(isDark),
                _buildSwitchTile(
                  title: 'Prompt running entry override',
                  subtitle: 'Warn before starting a new timer when one is active',
                  value: settings.promptRunningEntryOverride,
                  onChanged: (v) => settingsNotifier.update((s) => s.copyWith(promptRunningEntryOverride: v)),
                  isDark: isDark,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // GENERAL Section
            _buildSectionHeader('GENERAL', isDark),
            _buildCard(
              isDark,
              [
                _buildTile(
                  title: 'App theme',
                  subtitle: ref.watch(appThemeIdProvider).displayName,
                  isDark: isDark,
                  onTap: () => _showThemeSelector(context),
                ),
                _buildDivider(isDark),
                _buildSwitchTile(
                  title: 'Haptic feedback',
                  value: settings.enableHaptics,
                  onChanged: (v) => settingsNotifier.update((s) => s.copyWith(enableHaptics: v)),
                  isDark: isDark,
                ),
                _buildDivider(isDark),
                _buildTile(
                  title: 'About PageClock',
                  subtitle: '1.0.0 (Offline-First Edition)',
                  isDark: isDark,
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'PageClock',
                      applicationVersion: '1.0.0',
                      applicationLegalese: '100% Offline-First Focus & Reading Tracker\nZero analytics • Zero cloud sync • Your data is yours.',
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            // DATA & BACKUP Section
            _buildSectionHeader('DATA & BACKUP', isDark),
            _buildCard(
              isDark,
              [
                _buildTile(
                  title: 'Export full PDF report',
                  subtitle: 'Formatted report of all sessions, charts & logs',
                  isDark: isDark,
                  onTap: () => _handlePdfExport(context),
                ),
                _buildDivider(isDark),
                _buildTile(
                  title: 'Export JSON backup (v2)',
                  subtitle: 'Complete database + settings export',
                  isDark: isDark,
                  onTap: () => _handleJsonExport(context),
                ),
                _buildDivider(isDark),
                _buildTile(
                  title: 'Export CSV',
                  subtitle: 'Spreadsheet compatible data export',
                  isDark: isDark,
                  onTap: () => _handleCsvExport(context),
                ),
                _buildDivider(isDark),
                _buildTile(
                  title: 'Import backup file',
                  subtitle: 'Restore or merge JSON/CSV data safely',
                  isDark: isDark,
                  onTap: () => _handleImportBackup(context),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // DANGER ZONE Section
            _buildSectionHeader('DANGER ZONE', isDark, isDanger: true),
            _buildCard(
              isDark,
              [
                _buildDangerTile(
                  title: 'Clear all sessions',
                  subtitle: 'Permanently deletes all recorded sessions. Preserves settings.',
                  isDark: isDark,
                  onTap: () => _showClearSessionsConfirmation(context),
                ),
                _buildDivider(isDark),
                _buildDangerTile(
                  title: 'Reset app to defaults',
                  subtitle: 'Wipes all sessions, subjects, and resets all settings to factory state.',
                  isDark: isDark,
                  onTap: () => _showResetAppConfirmation(context),
                ),
              ],
              borderColor: const Color(0xFFEF4444).withOpacity(0.3),
            ),
            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark, {bool isDanger = false}) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: isDanger
              ? const Color(0xFFEF4444)
              : (isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A)),
        ),
      ),
    );
  }

  Widget _buildCard(bool isDark, List<Widget> children, {Color? borderColor}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF15101E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor ?? (isDark ? const Color(0xFF261D36) : const Color(0xFFE5E7EB)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      color: isDark ? const Color(0xFF261D36) : const Color(0xFFF3F4F6),
    );
  }

  Widget _buildTile({
    required String title,
    required String subtitle,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDangerTile({
    required String title,
    required String subtitle,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFEF4444),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF111827),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFFE040FB),
            activeTrackColor: const Color(0xFFE040FB).withOpacity(0.35),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF111827),
          ),
        ),
      ],
    );
  }

  // --- Dialogs & Pickers ---

  void _showGoalDialog(BuildContext context, AppSettings settings) {
    int selected = settings.dailyGoalMinutes;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Daily Goal (Minutes)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [15, 30, 45, 60, 90, 120].map((m) {
            return RadioListTile<int>(
              title: Text('$m minutes'),
              value: m,
              groupValue: selected,
              onChanged: (val) {
                if (val != null) {
                  ref.read(settingsProvider.notifier).update((s) => s.copyWith(dailyGoalMinutes: val));
                  Navigator.pop(ctx);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showStreakThresholdDialog(BuildContext context, AppSettings settings) {
    int selected = settings.streakThresholdMinutes;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Streak Minimum Threshold'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [5, 10, 15, 20, 30].map((m) {
            return RadioListTile<int>(
              title: Text('$m minutes / day'),
              value: m,
              groupValue: selected,
              onChanged: (val) {
                if (val != null) {
                  ref.read(settingsProvider.notifier).update((s) => s.copyWith(streakThresholdMinutes: val));
                  Navigator.pop(ctx);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showConsistencyWindowPicker(BuildContext context, AppSettings settings) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Consistency Window'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [7, 30, 90].map((d) {
            return RadioListTile<int>(
              title: Text('$d days'),
              value: d,
              groupValue: settings.consistencyWindowDays,
              onChanged: (val) {
                if (val != null) {
                  ref.read(settingsProvider.notifier).update((s) => s.copyWith(consistencyWindowDays: val));
                  Navigator.pop(ctx);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showDateFormatPicker(BuildContext context, AppSettings settings) {
    const formats = ['YYYY-MM-DD', 'MM/DD/YYYY', 'DD/MM/YYYY'];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Date Format'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: formats.map((fmt) {
            return RadioListTile<String>(
              title: Text(fmt),
              value: fmt,
              groupValue: settings.dateFormat,
              onChanged: (val) {
                if (val != null) {
                  ref.read(settingsProvider.notifier).update((s) => s.copyWith(dateFormat: val));
                  Navigator.pop(ctx);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showDurationFormatPicker(BuildContext context, AppSettings settings) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Duration Format'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Digital (0:47:06)'),
              value: 'digital',
              groupValue: settings.durationFormat,
              onChanged: (val) {
                if (val != null) {
                  ref.read(settingsProvider.notifier).update((s) => s.copyWith(durationFormat: val));
                  Navigator.pop(ctx);
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('Human (47m 6s)'),
              value: 'human',
              groupValue: settings.durationFormat,
              onChanged: (val) {
                if (val != null) {
                  ref.read(settingsProvider.notifier).update((s) => s.copyWith(durationFormat: val));
                  Navigator.pop(ctx);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showWeekStartPicker(BuildContext context, AppSettings settings) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('First Day of the Week'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<int>(
              title: const Text('Monday'),
              value: DateTime.monday,
              groupValue: settings.weekStartDay,
              onChanged: (val) {
                if (val != null) {
                  ref.read(settingsProvider.notifier).update((s) => s.copyWith(weekStartDay: val));
                  Navigator.pop(ctx);
                }
              },
            ),
            RadioListTile<int>(
              title: const Text('Sunday'),
              value: DateTime.sunday,
              groupValue: settings.weekStartDay,
              onChanged: (val) {
                if (val != null) {
                  ref.read(settingsProvider.notifier).update((s) => s.copyWith(weekStartDay: val));
                  Navigator.pop(ctx);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMinDurationPicker(BuildContext context, AppSettings settings) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Minimum Session Duration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [5, 10, 30, 60].map((sec) {
            return RadioListTile<int>(
              title: Text('$sec seconds'),
              value: sec,
              groupValue: settings.minSessionSeconds,
              onChanged: (val) {
                if (val != null) {
                  ref.read(settingsProvider.notifier).update((s) => s.copyWith(minSessionSeconds: val));
                  Navigator.pop(ctx);
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showPomodoroSettingsDialog(BuildContext context, AppSettings settings) {
    int focus = settings.pomodoroFocusMinutes;
    int shortB = settings.pomodoroShortBreakMinutes;
    int longB = settings.pomodoroLongBreakMinutes;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Pomodoro Intervals'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Focus Duration:'),
                    DropdownButton<int>(
                      value: focus,
                      items: [15, 20, 25, 30, 45, 50, 60].map((v) => DropdownMenuItem(value: v, child: Text('$v min'))).toList(),
                      onChanged: (v) { if (v != null) setDialogState(() => focus = v); },
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Short Break:'),
                    DropdownButton<int>(
                      value: shortB,
                      items: [3, 5, 10, 15].map((v) => DropdownMenuItem(value: v, child: Text('$v min'))).toList(),
                      onChanged: (v) { if (v != null) setDialogState(() => shortB = v); },
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Long Break:'),
                    DropdownButton<int>(
                      value: longB,
                      items: [10, 15, 20, 25, 30].map((v) => DropdownMenuItem(value: v, child: Text('$v min'))).toList(),
                      onChanged: (v) { if (v != null) setDialogState(() => longB = v); },
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  ref.read(settingsProvider.notifier).update((s) => s.copyWith(
                    pomodoroFocusMinutes: focus,
                    pomodoroShortBreakMinutes: shortB,
                    pomodoroLongBreakMinutes: longB,
                  ));
                  Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- Data & Backup Actions ---

  Future<void> _handlePdfExport(BuildContext context) async {
    try {
      final sessions = await ref.read(sessionRepositoryProvider).getAllSessions();
      await SessionPdfService.printOrSharePdf(sessions);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF report generated successfully.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleJsonExport(BuildContext context) async {
    try {
      final sessions = await ref.read(sessionRepositoryProvider).getAllSessions();
      final settingsJson = ref.read(settingsProvider).toJson();
      final jsonStr = SessionExportService.exportJsonBackupV2(
        sessions: sessions,
        settings: settingsJson,
      );

      await Clipboard.setData(ClipboardData(text: jsonStr));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('JSON v2 Backup with ${sessions.length} sessions copied to clipboard.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('JSON Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleCsvExport(BuildContext context) async {
    try {
      final sessions = await ref.read(sessionRepositoryProvider).getAllSessions();
      final csvData = SessionExportService.exportToCsv(sessions);
      await Clipboard.setData(ClipboardData(text: csvData));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('CSV with ${sessions.length} sessions copied to clipboard.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleImportBackup(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'csv'],
        withData: true,
      );

      String? content;
      if (result != null && result.files.isNotEmpty) {
        final bytes = result.files.first.bytes;
        if (bytes != null) {
          content = utf8.decode(bytes);
        }
      }

      if (content == null || content.isEmpty) {
        // Fallback: offer pasted text input dialog
        if (mounted) {
          _showPasteImportDialog(context);
        }
        return;
      }

      await _processImportContent(context, content);
    } catch (e) {
      if (mounted) {
        _showPasteImportDialog(context);
      }
    }
  }

  void _showPasteImportDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import Backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Paste JSON or CSV backup content below:'),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText: '{"schema": 2, ...} or id,started_at_utc,...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              Navigator.pop(ctx);
              if (text.isNotEmpty) {
                _processImportContent(context, text);
              }
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  Future<void> _processImportContent(BuildContext context, String rawData) async {
    final repo = ref.read(sessionRepositoryProvider);
    final existingSessions = await repo.getAllSessions();
    final existingIds = existingSessions.map((s) => s.id).toSet();

    List<ReadingSession> importedSessions = [];
    Map<String, dynamic>? importedSettings;

    if (rawData.trim().startsWith('{') || rawData.trim().startsWith('[')) {
      final parsed = SessionExportService.parseBackup(rawData);
      if (!parsed.isValid) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Import failed: ${parsed.errorMessage}'), backgroundColor: Colors.red),
          );
        }
        return;
      }
      importedSessions = parsed.sessions;
      importedSettings = parsed.settings;
    } else {
      importedSessions = SessionExportService.importFromCsv(rawData);
    }

    if (importedSessions.isEmpty && importedSettings == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No valid records found in import.')),
        );
      }
      return;
    }

    int newCount = 0;
    int dupCount = 0;

    for (final s in importedSessions) {
      if (existingIds.contains(s.id)) {
        dupCount++;
      } else {
        await repo.saveSession(s);
        newCount++;
      }
    }

    if (importedSettings != null && mounted) {
      final restoreSettings = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Restore Settings?'),
          content: const Text('This backup contains configuration preferences. Would you like to restore them?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Skip')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restore')),
          ],
        ),
      );

      if (restoreSettings == true) {
        try {
          final s = AppSettings.fromJson(importedSettings);
          await ref.read(settingsProvider.notifier).setSettings(s);
        } catch (_) {}
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import complete: $newCount added, $dupCount duplicates skipped.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // --- Danger Zone Typed Confirmations ---

  Future<void> _showClearSessionsConfirmation(BuildContext context) async {
    final sessions = await ref.read(sessionRepositoryProvider).getAllSessions();
    final totalMs = sessions.fold<int>(0, (sum, s) => sum + s.durationMs);
    final hours = totalMs ~/ 3600000;
    final mins = (totalMs % 3600000) ~/ 60000;

    if (!mounted) return;

    final controller = TextEditingController();
    bool canConfirm = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Clear All Sessions?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This will permanently delete ${sessions.length} sessions ($hours h $mins m). Active timer will be cancelled. App settings will remain intact.',
                  style: const TextStyle(fontSize: 13, color: Color(0xFFEF4444)),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Export backup first'),
                  onPressed: () => _handleJsonExport(context),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Type confirm to continue:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'confirm',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (text) {
                    final matches = text.trim().toLowerCase() == 'confirm';
                    if (matches != canConfirm) {
                      setDialogState(() => canConfirm = matches);
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                onPressed: canConfirm
                    ? () async {
                        Navigator.pop(ctx);
                        await ref.read(stopwatchEngineProvider.notifier).cancel();
                        await ref.read(sessionRepositoryProvider).hardDeleteAll();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('All sessions have been permanently cleared.')),
                          );
                        }
                      }
                    : null,
                child: const Text('Clear All'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showResetAppConfirmation(BuildContext context) async {
    if (!mounted) return;

    final controller = TextEditingController();
    bool canConfirm = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Reset App to Defaults?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'WARNING: This wipes all sessions, custom subjects, and resets all settings (theme, goals, pomodoro) to default factory state.',
                  style: TextStyle(fontSize: 13, color: Color(0xFFEF4444), fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Export backup first'),
                  onPressed: () => _handleJsonExport(context),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Type confirm to continue:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'confirm',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (text) {
                    final matches = text.trim().toLowerCase() == 'confirm';
                    if (matches != canConfirm) {
                      setDialogState(() => canConfirm = matches);
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                onPressed: canConfirm
                    ? () async {
                        Navigator.pop(ctx);
                        await ref.read(stopwatchEngineProvider.notifier).cancel();
                        await ref.read(sessionRepositoryProvider).hardDeleteAll();
                        await ref.read(settingsProvider.notifier).resetToDefaults();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('App has been reset to defaults.')),
                          );
                        }
                      }
                    : null,
                child: const Text('Reset App'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showThemeSelector(BuildContext context) {
    final currentTheme = ref.read(appThemeIdProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF140E20) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Choose Theme',
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
                const SizedBox(height: 12),
                _buildThemeOption(
                  ctx: ctx,
                  themeId: AppThemeId.defaultDark,
                  title: 'Default Dark',
                  subtitle: 'Obsidian & Vercel titanium aesthetic',
                  colorPreview: const [Color(0xFF0F0B15), Color(0xFFE040FB), Color(0xFF2E1B46)],
                  isSelected: currentTheme == AppThemeId.defaultDark,
                ),
                _buildThemeOption(
                  ctx: ctx,
                  themeId: AppThemeId.defaultLight,
                  title: 'Default Light',
                  subtitle: 'Minimalist clean white layout',
                  colorPreview: const [Color(0xFFF9FAFB), Color(0xFFE040FB), Color(0xFFE5E7EB)],
                  isSelected: currentTheme == AppThemeId.defaultLight,
                ),
                _buildThemeOption(
                  ctx: ctx,
                  themeId: AppThemeId.special1,
                  title: 'special1',
                  subtitle: 'Pastel Waves (Cream, Soft Rose, Butter Yellow & Sky Blue)',
                  colorPreview: const [
                    Special1Palette.background,
                    Special1Palette.accentRose,
                    Special1Palette.waveYellow,
                    Special1Palette.waveBlue,
                  ],
                  isSelected: currentTheme == AppThemeId.special1,
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeOption({
    required BuildContext ctx,
    required AppThemeId themeId,
    required String title,
    required String subtitle,
    required List<Color> colorPreview,
    required bool isSelected,
  }) {
    final isDark = Theme.of(ctx).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: InkWell(
        onTap: () {
          ref.read(settingsProvider.notifier).update((s) => s.copyWith(themeId: themeId.name));
          Navigator.pop(ctx);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF281F3B) : const Color(0xFFFDF2F8))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFE040FB)
                  : (isDark ? const Color(0xFF221832) : const Color(0xFFE5E7EB)),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: colorPreview.map((c) {
                  return Container(
                    width: 14,
                    height: 14,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.black12,
                        width: 1,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle_rounded, color: Color(0xFFE040FB), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
