import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../engine/stopwatch_engine.dart';
import '../settings/app_settings.dart';

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static const _timerId = 4242;
  static const _reminderId = 4243;
  static const _pomodoroId = 4244;
  static bool _initialized = false;
  static bool _timezoneReady = false;
  static String? _lastTimerState;
  static String? _pendingAction;
  static Future<void> Function(String action)? _actionHandler;

  static bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> initialize() async {
    if (!_android || _initialized) return;
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: _onResponse,
    );
    _initialized = true;
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final action = launch?.notificationResponse?.actionId;
    if (launch?.didNotificationLaunchApp == true &&
        _validAction(action)) {
      _pendingAction = action;
    }
  }

  static bool _validAction(String? action) =>
      action == 'pause' || action == 'resume' || action == 'stop';

  static void setTimerActionHandler(
    Future<void> Function(String action) handler,
  ) {
    _actionHandler = handler;
    final pending = _pendingAction;
    if (pending != null) {
      _pendingAction = null;
      handler(pending);
    }
  }

  static void _onResponse(NotificationResponse response) {
    final action = response.actionId;
    if (!_validAction(action)) return;
    final handler = _actionHandler;
    if (handler == null) {
      _pendingAction = action;
    } else {
      handler(action!);
    }
  }

  static Future<bool> requestPermission() async {
    if (!_android || !_initialized) return false;
    final plugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (plugin == null) return false;
    final requested = await plugin.requestNotificationsPermission();
    if (requested == true) return true;
    return await plugin.areNotificationsEnabled() ?? requested ?? false;
  }

  static Future<void> syncTimer(
    StopwatchState state,
    AppSettings settings,
  ) async {
    if (!_android || !_initialized) return;
    final plugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (plugin == null) return;

    final session = state.currentSession;
    final enabled = settings.notificationsEnabled &&
        settings.runningTimerNotification &&
        session != null &&
        state.status != StopwatchStatus.idle;
    final signature = enabled
        ? '${session.id}:${state.status.index}:${session.note ?? ''}:${session.subjectId ?? ''}'
        : 'inactive';
    if (_lastTimerState == signature) return;

    if (!enabled) {
      await plugin.stopForegroundService();
      _lastTimerState = signature;
      return;
    }
    // Do not cache an active state until Android accepts the notification.
    // If permission is denied or the foreground-service start fails, a later
    // sync (for example after the user enables notifications in system
    // settings) must retry instead of being skipped as an unchanged state.
    if (await plugin.areNotificationsEnabled() == false) {
      _lastTimerState = null;
      return;
    }

    final running = state.status == StopwatchStatus.running;
    final project = session.subjectId?.trim().isNotEmpty == true
        ? session.subjectId!.trim()
        : 'Focus session';
    final note = session.note?.trim() ?? '';
    final title = running ? 'PageClock • Focus running' : 'PageClock • Paused';
    final body = running
        ? (note.isEmpty ? project : '$note • $project')
        : 'Paused • ${_formatElapsed(state.elapsedMs)} • $project';
    final details = AndroidNotificationDetails(
      'pageclock_running_timer',
      'Running focus timer',
      channelDescription: 'Ongoing PageClock focus timer controls.',
      importance: Importance.low,
      priority: Priority.low,
      category: AndroidNotificationCategory.service,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      showWhen: true,
      usesChronometer: running,
      when: running
          ? DateTime.now().millisecondsSinceEpoch - state.elapsedMs
          : null,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          running ? 'pause' : 'resume',
          running ? 'Pause' : 'Resume',
          showsUserInterface: true,
        ),
        AndroidNotificationAction('stop', 'Stop', showsUserInterface: true),
      ],
    );
    await plugin.startForegroundService(
      _timerId,
      title,
      body,
      notificationDetails: details,
    );
    _lastTimerState = signature;
  }

  static Future<void> showPomodoroComplete(
    AppSettings settings, {
    required String title,
    required String body,
  }) async {
    if (!_android ||
        !_initialized ||
        !settings.notificationsEnabled ||
        !settings.pomodoroNotificationsEnabled) {
      return;
    }
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null || await android.areNotificationsEnabled() == false) {
      return;
    }
    await _plugin.show(
      _pomodoroId,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'pageclock_pomodoro',
          'Pomodoro alerts',
          channelDescription: 'Focus and break completion notifications.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          category: AndroidNotificationCategory.reminder,
          autoCancel: true,
        ),
      ),
    );
  }

  static Future<void> scheduleDailyReminder(AppSettings settings) async {
    if (!_android || !_initialized) return;
    if (!settings.notificationsEnabled || !settings.smartDailyReminder) {
      await cancelDailyReminder();
      return;
    }
    await _ensureTimezone();
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      settings.dailyReminderHour,
      settings.dailyReminderMinute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    await _plugin.zonedSchedule(
      _reminderId,
      'Time for a reading session',
      'Take a few minutes to focus with PageClock.',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'pageclock_daily_reminder',
          'Daily reading reminder',
          channelDescription: 'Your scheduled PageClock reminder.',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          category: AndroidNotificationCategory.reminder,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static Future<void> _ensureTimezone() async {
    if (_timezoneReady) return;
    tzdata.initializeTimeZones();
    final timezoneInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
    _timezoneReady = true;
  }

  static Future<void> cancelDailyReminder() async {
    if (_initialized) await _plugin.cancel(_reminderId);
  }

  static Future<void> disableNotifications() async {
    if (!_initialized) return;
    _lastTimerState = 'inactive';
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.stopForegroundService();
    await _plugin.cancel(_reminderId);
    await _plugin.cancel(_pomodoroId);
  }

  static String _formatElapsed(int milliseconds) {
    final d = Duration(milliseconds: milliseconds);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0
        ? '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
        : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
