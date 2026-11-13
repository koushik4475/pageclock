import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class AppSettings {
  final String themeId; // 'default_dark', 'default_light', 'special1'
  final String clockStyleId;
  final String clockAccentColor;
  final bool clockShowSeconds;
  final bool clockShowDate;
  final int dailyGoalMinutes;
  final int streakThresholdMinutes;
  final int consistencyWindowDays; // 7, 30, 90
  final int weekStartDay; // DateTime.monday (1) or DateTime.sunday (7)
  final String dateFormat; // 'MM/DD/YYYY', 'DD/MM/YYYY', 'YYYY-MM-DD'
  final bool use24HourClock;
  final String durationFormat; // 'human', 'digital'
  final bool groupSimilar;
  final bool enableHaptics;
  final bool smartDailyReminder;
  final bool runningTimerNotification;
  final bool notificationsEnabled;
  final bool pomodoroNotificationsEnabled;
  final int dailyReminderHour;
  final int dailyReminderMinute;
  final int pomodoroFocusMinutes;
  final int pomodoroShortBreakMinutes;
  final int pomodoroLongBreakMinutes;
  final int pomodoroLongBreakInterval;
  final bool pomodoroSoundEnabled;
  final bool pomodoroAutoStart;
  final int selectedTimerMode; // 0: List view, 1: Pomodoro
  final String lastSelectedProject;
  final int minSessionSeconds; // default 10 seconds
  final bool promptRunningEntryOverride;
  final String profileName;
  final String profileEmail;

  const AppSettings({
    this.themeId = 'default_dark',
    this.clockStyleId = 'mac_flip',
    this.clockAccentColor = '#F5A623',
    this.clockShowSeconds = false,
    this.clockShowDate = true,
    this.dailyGoalMinutes = 30,
    this.streakThresholdMinutes = 10,
    this.consistencyWindowDays = 7,
    this.weekStartDay = DateTime.monday,
    this.dateFormat = 'YYYY-MM-DD',
    this.use24HourClock = false,
    this.durationFormat = 'digital',
    this.groupSimilar = false,
    this.enableHaptics = true,
    this.smartDailyReminder = false,
    this.runningTimerNotification = false,
    this.notificationsEnabled = false,
    this.pomodoroNotificationsEnabled = true,
    this.dailyReminderHour = 20,
    this.dailyReminderMinute = 0,
    this.pomodoroFocusMinutes = 25,
    this.pomodoroShortBreakMinutes = 5,
    this.pomodoroLongBreakMinutes = 15,
    this.pomodoroLongBreakInterval = 4,
    this.pomodoroSoundEnabled = true,
    this.pomodoroAutoStart = false,
    this.selectedTimerMode = 0,
    this.lastSelectedProject = 'General Focus',
    this.minSessionSeconds = 10,
    this.promptRunningEntryOverride = true,
    this.profileName = '',
    this.profileEmail = '',
  });

  AppSettings copyWith({
    String? themeId,
    String? clockStyleId,
    String? clockAccentColor,
    bool? clockShowSeconds,
    bool? clockShowDate,
    int? dailyGoalMinutes,
    int? streakThresholdMinutes,
    int? consistencyWindowDays,
    int? weekStartDay,
    String? dateFormat,
    bool? use24HourClock,
    String? durationFormat,
    bool? groupSimilar,
    bool? enableHaptics,
    bool? smartDailyReminder,
    bool? runningTimerNotification,
    bool? notificationsEnabled,
    bool? pomodoroNotificationsEnabled,
    int? dailyReminderHour,
    int? dailyReminderMinute,
    int? pomodoroFocusMinutes,
    int? pomodoroShortBreakMinutes,
    int? pomodoroLongBreakMinutes,
    int? pomodoroLongBreakInterval,
    bool? pomodoroSoundEnabled,
    bool? pomodoroAutoStart,
    int? selectedTimerMode,
    String? lastSelectedProject,
    int? minSessionSeconds,
    bool? promptRunningEntryOverride,
    String? profileName,
    String? profileEmail,
  }) {
    return AppSettings(
      themeId: themeId ?? this.themeId,
      clockStyleId: clockStyleId ?? this.clockStyleId,
      clockAccentColor: clockAccentColor ?? this.clockAccentColor,
      clockShowSeconds: clockShowSeconds ?? this.clockShowSeconds,
      clockShowDate: clockShowDate ?? this.clockShowDate,
      dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
      streakThresholdMinutes: streakThresholdMinutes ?? this.streakThresholdMinutes,
      consistencyWindowDays: consistencyWindowDays ?? this.consistencyWindowDays,
      weekStartDay: weekStartDay ?? this.weekStartDay,
      dateFormat: dateFormat ?? this.dateFormat,
      use24HourClock: use24HourClock ?? this.use24HourClock,
      durationFormat: durationFormat ?? this.durationFormat,
      groupSimilar: groupSimilar ?? this.groupSimilar,
      enableHaptics: enableHaptics ?? this.enableHaptics,
      smartDailyReminder: smartDailyReminder ?? this.smartDailyReminder,
      runningTimerNotification: runningTimerNotification ?? this.runningTimerNotification,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      pomodoroNotificationsEnabled: pomodoroNotificationsEnabled ?? this.pomodoroNotificationsEnabled,
      dailyReminderHour: dailyReminderHour ?? this.dailyReminderHour,
      dailyReminderMinute: dailyReminderMinute ?? this.dailyReminderMinute,
      pomodoroFocusMinutes: pomodoroFocusMinutes ?? this.pomodoroFocusMinutes,
      pomodoroShortBreakMinutes: pomodoroShortBreakMinutes ?? this.pomodoroShortBreakMinutes,
      pomodoroLongBreakMinutes: pomodoroLongBreakMinutes ?? this.pomodoroLongBreakMinutes,
      pomodoroLongBreakInterval: pomodoroLongBreakInterval ?? this.pomodoroLongBreakInterval,
      pomodoroSoundEnabled: pomodoroSoundEnabled ?? this.pomodoroSoundEnabled,
      pomodoroAutoStart: pomodoroAutoStart ?? this.pomodoroAutoStart,
      selectedTimerMode: selectedTimerMode ?? this.selectedTimerMode,
      lastSelectedProject: lastSelectedProject ?? this.lastSelectedProject,
      minSessionSeconds: minSessionSeconds ?? this.minSessionSeconds,
      promptRunningEntryOverride: promptRunningEntryOverride ?? this.promptRunningEntryOverride,
      profileName: profileName ?? this.profileName,
      profileEmail: profileEmail ?? this.profileEmail,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'themeId': themeId,
      'clockStyleId': clockStyleId,
      'clockAccentColor': clockAccentColor,
      'clockShowSeconds': clockShowSeconds,
      'clockShowDate': clockShowDate,
      'dailyGoalMinutes': dailyGoalMinutes,
      'streakThresholdMinutes': streakThresholdMinutes,
      'consistencyWindowDays': consistencyWindowDays,
      'weekStartDay': weekStartDay,
      'dateFormat': dateFormat,
      'use24HourClock': use24HourClock,
      'durationFormat': durationFormat,
      'groupSimilar': groupSimilar,
      'enableHaptics': enableHaptics,
      'smartDailyReminder': smartDailyReminder,
      'runningTimerNotification': runningTimerNotification,
      'notificationsEnabled': notificationsEnabled,
      'pomodoroNotificationsEnabled': pomodoroNotificationsEnabled,
      'dailyReminderHour': dailyReminderHour,
      'dailyReminderMinute': dailyReminderMinute,
      'pomodoroFocusMinutes': pomodoroFocusMinutes,
      'pomodoroShortBreakMinutes': pomodoroShortBreakMinutes,
      'pomodoroLongBreakMinutes': pomodoroLongBreakMinutes,
      'pomodoroLongBreakInterval': pomodoroLongBreakInterval,
      'pomodoroSoundEnabled': pomodoroSoundEnabled,
      'pomodoroAutoStart': pomodoroAutoStart,
      'selectedTimerMode': selectedTimerMode,
      'lastSelectedProject': lastSelectedProject,
      'minSessionSeconds': minSessionSeconds,
      'promptRunningEntryOverride': promptRunningEntryOverride,
      'profileName': profileName,
      'profileEmail': profileEmail,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      themeId: json['themeId'] as String? ?? 'default_dark',
      clockStyleId: json['clockStyleId'] as String? ?? 'mac_flip',
      clockAccentColor: json['clockAccentColor'] as String? ?? '#F5A623',
      clockShowSeconds: json['clockShowSeconds'] as bool? ?? false,
      clockShowDate: json['clockShowDate'] as bool? ?? true,
      dailyGoalMinutes: (json['dailyGoalMinutes'] as num?)?.toInt() ?? 30,
      streakThresholdMinutes: (json['streakThresholdMinutes'] as num?)?.toInt() ?? 10,
      consistencyWindowDays: (json['consistencyWindowDays'] as num?)?.toInt() ?? 7,
      weekStartDay: (json['weekStartDay'] as num?)?.toInt() ?? DateTime.monday,
      dateFormat: json['dateFormat'] as String? ?? 'YYYY-MM-DD',
      use24HourClock: json['use24HourClock'] as bool? ?? false,
      durationFormat: json['durationFormat'] as String? ?? 'digital',
      groupSimilar: json['groupSimilar'] as bool? ?? false,
      enableHaptics: json['enableHaptics'] as bool? ?? true,
      smartDailyReminder: json['smartDailyReminder'] as bool? ?? false,
      runningTimerNotification: json['runningTimerNotification'] as bool? ?? false,
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? false,
      pomodoroNotificationsEnabled: json['pomodoroNotificationsEnabled'] as bool? ?? true,
      dailyReminderHour: (json['dailyReminderHour'] as num?)?.toInt() ?? 20,
      dailyReminderMinute: (json['dailyReminderMinute'] as num?)?.toInt() ?? 0,
      pomodoroFocusMinutes: (json['pomodoroFocusMinutes'] as num?)?.toInt() ?? 25,
      pomodoroShortBreakMinutes: (json['pomodoroShortBreakMinutes'] as num?)?.toInt() ?? 5,
      pomodoroLongBreakMinutes: (json['pomodoroLongBreakMinutes'] as num?)?.toInt() ?? 15,
      pomodoroLongBreakInterval: (json['pomodoroLongBreakInterval'] as num?)?.toInt() ?? 4,
      pomodoroSoundEnabled: json['pomodoroSoundEnabled'] as bool? ?? true,
      pomodoroAutoStart: json['pomodoroAutoStart'] as bool? ?? false,
      selectedTimerMode: (json['selectedTimerMode'] as num?)?.toInt() ?? 0,
      lastSelectedProject: json['lastSelectedProject'] as String? ?? 'General Focus',
      minSessionSeconds: (json['minSessionSeconds'] as num?)?.toInt() ?? 10,
      promptRunningEntryOverride: json['promptRunningEntryOverride'] as bool? ?? true,
      profileName: json['profileName'] as String? ?? '',
      profileEmail: json['profileEmail'] as String? ?? '',
    );
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  final SharedPreferences _prefs;
  static const _storageKey = 'pageclock_app_settings_v1';

  SettingsNotifier(this._prefs) : super(_loadInitial(_prefs));

  static AppSettings _loadInitial(SharedPreferences prefs) {
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return const AppSettings();
    try {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      return AppSettings.fromJson(decoded);
    } catch (e) {
      debugPrint('[SettingsNotifier] Error reading stored settings: $e');
      return const AppSettings();
    }
  }

  Future<void> update(AppSettings Function(AppSettings current) updater) async {
    final updated = updater(state);
    state = updated;
    await _save();
  }

  Future<void> setSettings(AppSettings newSettings) async {
    state = newSettings;
    await _save();
  }

  Future<void> resetToDefaults() async {
    state = const AppSettings();
    await _prefs.remove(_storageKey);
  }

  Future<void> _save() async {
    try {
      final raw = json.encode(state.toJson());
      await _prefs.setString(_storageKey, raw);
    } catch (e) {
      debugPrint('[SettingsNotifier] Error saving settings: $e');
    }
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden in ProviderScope');
});

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsNotifier(prefs);
});
