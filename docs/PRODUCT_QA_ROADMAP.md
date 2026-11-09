# PageClock Product QA Review and Roadmap

Review date: 9 November 2026

## Product assessment

PageClock has the foundations of an offline-first focus tracker: timer and Pomodoro modes, a fullscreen flip clock, calendar timeline, reports, local persistence, backup/export, themes, and Android update support.

The code review found important gaps between the intended product experience and the implemented workflows. This review is based on repository code and automated CI evidence; physical-device and hosted-browser exploratory testing are still required.

## Addressed in the current QA hardening change

- Replaced the hard-coded Today sample entry with persisted sessions and an empty state.
- Connected timer descriptions and project labels to saved sessions, and restored the last selected project and timer mode.
- Applied the minimum-session setting with explicit save/discard/continue choices.
- Applied the configured Pomodoro focus duration and added long-break interval and auto-start controls.
- Made date, time, duration, week-start and haptic settings effective in key timer/calendar/report workflows.
- Added a database migration for the paused timestamp column.
- Isolated native Drift/SQLite behind conditional imports so web builds do not compile native FFI code.
- Added strict SHA-256 and HTTPS checks to APK update downloads.
- Enabled CI analysis, tests, web compilation and Android release compilation without masking build/code-generation failures.

## Product gaps still requiring a planned feature release

### P1 — Project and subject management

The timer still offers a fixed in-code list of projects. The database has a Subject model/table, but there is no complete user workflow to create, rename, recolour, archive or delete subjects. JSON backup currently emits an empty subjects collection, and import does not restore subject records.

Plan:
1. Add a subject repository contract for native and web storage.
2. Add a subject-management screen and create/edit/archive flows.
3. Replace hard-coded project choices in the timer with persisted subjects.
4. Include subject records in JSON export/import, with duplicate and conflict rules.
5. Test migration, web/native persistence and backup round-trips.

### P1 — Individual time-entry management

Users can add manual entries and clear all sessions, but cannot edit or delete one historical entry from the product UI.

Plan:
1. Add entry detail/edit UI for description, subject, start/end and duration.
2. Add single-entry soft delete with undo.
3. Ensure changes update calendar, totals, streaks, heatmap and PDF reports.
4. Validate negative/zero durations, overlapping timestamps and cross-midnight entries.

### P1 — Notifications and background tracking

Settings contain reminder and running-timer-notification fields, but there is no notification service or end-to-end platform implementation. A timer that only continues inside the app process is not equivalent to a robust background timer.

Plan:
1. Define Android notification permission and channel behaviour.
2. Add an ongoing notification with elapsed time and pause/stop deep links.
3. Add opt-in daily reminders with a user-controlled reminder time and quiet hours.
4. Persist timer state and reconcile it after process death, reboot and timezone changes.
5. Document web limitations rather than displaying non-functional switches.

### P2 — Data portability and recovery

The backup flow needs broader coverage for subjects and settings, plus stronger tests for old schema versions, malformed records and partial imports.

Plan:
1. Version the backup schema and document compatibility rules.
2. Export/import sessions, subjects and settings together.
3. Validate rows before writing and report skipped/invalid records.
4. Use a transactional import so failed imports cannot leave half-restored data.

### P2 — Accessibility and usability

Plan:
1. Add semantic labels and minimum touch targets for icon-only actions.
2. Verify text scaling, landscape layouts, tablets and keyboard navigation.
3. Add onboarding and clear first-run empty states.
4. Add localization coverage and verify date/time formatting across locales.

## Release acceptance gates

- `flutter analyze --no-fatal-infos` reports no errors or warnings.
- `flutter test` passes, including storage, timer lifecycle, migration, import/export and update-integrity tests.
- Web release build and Android release APK build both pass.
- A physical Android smoke test covers cold launch, timer start/pause/resume/stop, process termination/recovery, notification permission, APK update permission, and install-over-existing-app.
- A hosted web smoke test covers local persistence, reload recovery, timer workflows, reports, calendar, file import/export and responsive layouts.

## Explicitly not claimed by this source-level review

The automated workflow cannot prove real Android installer behaviour, notification delivery while backgrounded, iOS behaviour or usability on physical screen sizes. Those require device/browser execution and should remain visible QA sign-off items.