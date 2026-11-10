# PageClock Fix & Stabilization Report

**Author / Architect:** Antigravity AI Engineering Assistant  
**Date:** November 8, 2026  
**Target Repository:** `koushik4475/pageclock`  
**Branch:** `fix/persistence-and-settings`  

---

## Executive Summary

This engineering stabilization pass resolved all 17 audited problems catalogued in `pageclock-agy-fix-prompt.md`. PageClock now features full offline-first persistence across Android, iOS, Desktop, and Web with zero cloud sync, zero paid services, and zero analytics.

---

## Audit Matrix: Status of Problems #1 through #17

| # | Problem Description | Status | Files Changed | How Verified |
|---|---------------------|--------|---------------|--------------|
| **1** | Dummy settings without persistence | **FIXED** | `lib/core/settings/app_settings.dart`, `lib/features/settings/toggl_settings_screen.dart`, `lib/main.dart` | Built `AppSettings` model with `SharedPreferences` write-through via `SettingsNotifier`. Tested round-trip in unit tests and hot restart. |
| **2** | Theme resets to default on cold start | **FIXED** | `lib/core/theme/theme_provider.dart`, `lib/core/settings/app_settings.dart`, `lib/main.dart` | `appThemeIdProvider` and `themeModeProvider` now read directly from `settingsProvider.themeId`. Injected into `ProviderScope` bootstrap. |
| **3** | Unrealistic hardcoded user details in profile card | **FIXED** | `lib/features/settings/toggl_settings_screen.dart`, `lib/main.dart` | Replaced hardcoded names and emails with anonymous local device tokens, dynamic device timezone offsets, and offline badges. |
| **4** | Fake 28-day sample data seeded on fresh install | **FIXED** | `lib/core/repository/session_repository.dart`, `lib/core/repository/web_session_repository.dart` | Cleared hardcoded seeding from repository initializers. Fresh installs now show true 0-session empty states. |
| **5** | In-memory session repository on Web losing all data | **FIXED** | `lib/core/repository/web_session_repository.dart`, `lib/core/repository/session_repository.dart` | Created `WebSessionRepository` with JSON storage in `SharedPreferences`, implementing real CRUD and reactive streams on Web. |
| **6** | No complete data export & lossy schema | **FIXED** | `lib/core/services/export_service.dart`, `lib/core/services/pdf_service.dart` | Implemented JSON v2 backup format (`schema: 2`) capturing all sessions, settings snapshot, and subjects. Added CSV & comprehensive PDF export. |
| **7** | Mac flip clock disconnected from live timer engine | **FIXED** | `lib/features/timer/widgets/fullscreen_ambient_focus_screen.dart` | Converted `AppleMacFlipClockScreen` to `ConsumerStatefulWidget` consuming `stopwatchEngineProvider` and `stopwatchProvider` live. |
| **8** | Flip clock keeps ticking after session stopped | **FIXED** | `lib/features/timer/widgets/fullscreen_ambient_focus_screen.dart`, `lib/core/engine/stopwatch_engine.dart` | Flip clock displays live status and binds controls directly to `stopwatchNotifier`. Ticker stops when session is idle. |
| **9** | Screen dims/locks during fullscreen flip clock mode | **FIXED** | `lib/features/timer/widgets/fullscreen_ambient_focus_screen.dart`, `pubspec.yaml` | Integrated `wakelock_plus` to keep screen awake in fullscreen flip clock mode with manual toggle and auto-release on exit. |
| **10** | Tapping start while paused creates orphan sessions | **FIXED** | `lib/core/engine/stopwatch_engine.dart`, `lib/core/db/app_database.dart` | `StopwatchNotifier.start()` detects existing active or paused sessions and calls `resume()` instead of inserting a duplicate row. |
| **11** | Short sessions (< 60s) silently deleted | **FIXED** | `lib/core/engine/stopwatch_engine.dart`, `lib/core/settings/app_settings.dart` | Lowered default threshold to 10s and introduced `forceSave` support so deliberate user logs are never silently deleted. |
| **12** | Database schema lacks paused duration tracking | **FIXED** | `lib/core/db/tables.dart`, `lib/core/db/app_database.dart`, `lib/core/models/reading_session.dart` | Added `pausedAtUtc` integer column and updated `calculateCurrentDurationMs` to accurately compute net focus time. |
| **13** | Multiple open sessions in database on force-close | **FIXED** | `lib/core/db/app_database.dart`, `lib/core/repository/web_session_repository.dart` | Implemented self-healing in `getActiveSession()`: automatically detects orphan rows, caps their durations, and seals them. |
| **14** | Reports export button dead (`onPressed: () {}`) | **FIXED** | `lib/features/reports/reports_screen.dart`, `lib/core/services/pdf_service.dart` | Wired header Export button to generate and share the complete PDF report with streaks and charts. |
| **15** | CI generates throwaway keystore breaking updates | **FIXED** | `.github/workflows/ci.yml` | Tagged releases (`v*`) now strictly gate on `ANDROID_KEYSTORE_BASE64` secrets. Throwaway keystore fallback removed for releases. |
| **16** | Releases triggered on every branch push | **FIXED** | `.github/workflows/ci.yml` | Publishing step now strictly gates on `startsWith(github.ref, 'refs/tags/v')`. |
| **17** | No Danger Zone typed confirmation | **FIXED** | `lib/features/settings/toggl_settings_screen.dart` | Implemented typed `"confirm"` verification dialogues for both "Clear All Sessions" and "Reset App to Defaults". |

---

## New Dependencies Added

- `shared_preferences: ^2.3.2` — Local key-value persistence for settings and web repository.
- `file_picker: ^8.1.4` — Native file picker for importing JSON/CSV backup files.
- `wakelock_plus: ^1.2.8` — Prevents display sleep in fullscreen Mac flip clock mode.
- `flutter_local_notifications: ^17.2.3` — Notification capability for Pomodoro interval triggers.

---

## Architectural Decisions & Governance

1. **Web Persistence Strategy**: Because Drift native SQLite uses FFI and cannot execute in standard web workers without custom WebAssembly assets, we created `WebSessionRepository`. It shares the identical `SessionRepository` interface using `SharedPreferences`, guaranteeing full testability and instant execution across web previews.
2. **Strict Release Gate**: If `ANDROID_KEYSTORE_BASE64` is missing from repository secrets, CI will compile a debug APK for verification and fail release publication on tag builds, preventing signature mismatch bricks.
3. **Application ID Note (`com.example.pageclock`)**: The Android package name remains `com.example.pageclock`. **Do NOT modify this value** if end users have installed existing builds signed with this package ID; changing `applicationId` forces Android OS to treat updates as a distinct application, requiring users to uninstall first and lose their local SQLite data.

---

## Test Verification

- `test/button_interaction_test.dart` — Verified Toggl Track timer screen, mode switches, flip clock presentation, and theme switching.
- `test/stabilization_regression_test.dart` — Verified settings round-trip across independent containers, clean 0-session state on launch, JSON v2 export/import with duplicate merge, malformed backup error handling, and hard-delete wiping.
- `test/export_import_test.dart`, `test/hourly_stats_test.dart`, `test/stats_engine_test.dart` — All legacy tests preserved and green.
