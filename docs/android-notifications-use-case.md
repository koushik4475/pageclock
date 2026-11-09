# PageClock Android notifications and update flow

## Purpose

This document records the end-to-end Android use case implemented in PageClock, its platform boundaries, and the acceptance checks required before calling it production-verified.

## User journey

1. **Enable notifications.** In Settings → Notifications, the user enables PageClock notifications. Android's notification permission is requested at runtime. The app stores the user's preference locally.
2. **Start a focus timer.** The user starts a timer from PageClock. When the running-timer notification setting is enabled, PageClock starts an Android foreground-service notification for the active session.
3. **Keep the timer visible outside the app.** The notification is ongoing and low priority, uses Android's native chronometer for elapsed time, and exposes Pause/Resume and Stop actions. Those actions are routed back to the stopwatch state handler. The Android service is declared with `stopWithTask="false"` so removing the app's task from Recents is not intended to stop the user-started timer service.
4. **Receive Pomodoro alerts.** When the in-app Pomodoro focus interval or break interval completes, PageClock can post a completion notification. The corresponding setting controls these alerts.
5. **Schedule a daily reminder.** The user can enable a daily focus reminder and pick a local wall-clock time. The app resolves the device timezone and schedules a repeating notification using an inexact, idle-allowed schedule.
6. **Check for a new app version.** Settings → App Updates → Check for updates forces a GitHub Releases lookup rather than relying on the normal update-check cache. The update flow downloads and verifies the release asset before handing the APK to Android's package installer. The user must approve installation in Android's system UI.

## Implementation map

| Area | Implementation |
| --- | --- |
| Notification setup and Android permission | `lib/core/services/notification_service.dart` |
| Persistent timer notification and action buttons | `NotificationService.syncTimer` |
| Pomodoro completion notifications | `NotificationService.showPomodoroComplete` and the timer screen completion callbacks |
| Daily reminder and device timezone | `NotificationService.scheduleDailyReminder` |
| Persisted user preferences | `lib/core/settings/app_settings.dart` |
| Notification controls and manual update check | `lib/features/settings/toggl_settings_screen.dart` |
| Timer state/action integration | `lib/main.dart` and `lib/features/timer/toggl_timer_screen.dart` |
| Android permissions, receivers and service declaration | `android/app/src/main/AndroidManifest.xml` |
| Plugin/Gradle requirements | `pubspec.yaml`, `android/app/build.gradle`, `android/settings.gradle` |
| APK update and installer messaging | `lib/features/app_update/` |

## Platform and reliability boundaries

- Notifications are currently implemented for Android. Other platforms must not be assumed to have equivalent behavior.
- Android 13+ requires runtime notification permission for ordinary notifications. A user can deny or later revoke it in system settings.
- The running-timer notification is tied to a user-started timer and is intended to make that ongoing work visible. Android 14+ requires foreground-service types. PageClock declares `specialUse` with a descriptive subtype because the timer use case does not map cleanly to the standard media/location/sync categories. Google Play reviews special-use foreground-service declarations; the manifest description is not a substitute for the Play Console declaration and review.
- CI resolves dependencies from Pub on each clean runner. The app now explicitly selects a fixed, compatible `image` package version because `image 4.11.0` accepted an `archive` version that did not expose the `decodeLazy` method required by its source; `image 4.11.1` fixed that dependency constraint. Keep the generated `pubspec.lock` under version control for an application once it is regenerated and reviewed.
- The daily reminder is deliberately inexact to avoid requesting exact-alarm privileges for a convenience reminder. Android may batch or delay it during Doze or power-saving conditions. Device manufacturers can add background restrictions.
- A user force-stopping the app is different from dismissing its task from Recents. Do not promise reminders, timer actions, or Pomodoro completion alerts after a force-stop. Pomodoro completion is detected by the running app's timer-state listener; it is not a separately persisted native alarm at the focus boundary.
- Android's installer always retains final control. Updating an existing installation requires the same application ID and signing certificate and a higher version code. PageClock must never attempt to bypass the system confirmation or Play Protect.
- Foreground-service use is justified only while the user has an active timer and can see an accurate persistent notification. Stop it promptly when the session ends or the user disables the feature.

## Manual acceptance checklist

Run this on a physical Android device for each supported Android generation before publishing a release:

- [ ] Fresh install; allow notification permission; verify the settings persist after app restart.
- [ ] Deny notification permission; verify PageClock explains that alerts are unavailable and does not claim they are active.
- [ ] Start a timer; verify an ongoing notification appears with the correct elapsed chronometer and task/project text.
- [ ] Press Pause, Resume and Stop from the notification; verify the persisted session state and in-app UI match each action.
- [ ] Send PageClock to the background and remove its task from Recents; verify the timer service/notification behaves as intended.
- [ ] Complete a Pomodoro focus interval and a break; verify the correct completion alerts and sound preference.
- [ ] Schedule a daily reminder a few minutes ahead; verify delivery, disable it, and verify cancellation.
- [ ] Reboot the device and verify the configured reminder is restored by the boot receiver.
- [ ] Change the device timezone and verify a rescheduled reminder follows the new local timezone.
- [ ] Force-stop the app and document the expected Android restriction; reopen it and verify the saved timer/session is reconstructed.
- [ ] Check for an update; verify HTTPS/checksum validation, package/signature compatibility, installer launch and user confirmation.
- [ ] Verify the old app's local data survives an in-place signed update.

## CI and release gate

The pipeline runs code generation, Dart analysis, Flutter tests, a web build, and an Android arm64 release APK build. A GitHub Release is published only for a version tag after both verification and Android build jobs pass. CI success is necessary but does not replace the physical-device acceptance checklist above.
