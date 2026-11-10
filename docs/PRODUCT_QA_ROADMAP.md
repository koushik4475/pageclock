# PageClock Product QA Review and Roadmap

Review date: 10 November 2026  
Reviewed main commit: `c0572869025a0efd8d1b38de3228e3aa61811f35`  
Latest published release: `v1.0.0+122`

## Current product baseline

PageClock is an offline-first personal reading/focus tracker. The current main branch includes:

- A persistent stopwatch with start, pause, resume, stop, race-safe cold-start restoration, active-session recovery and a minimum-duration prompt.
- Manual time-entry creation and a fixed project picker.
- Pomodoro focus/break intervals, configurable focus duration, break settings and completion notifications.
- A fullscreen flip clock / ambient focus screen.
- Eleven locally persisted themes.
- A 24-hour calendar timeline and reports with filters, project/category breakdowns, heatmap and PDF export.
- Local settings, daily focus goal, running-timer notification, Pomodoro notifications and scheduled daily reminders.
- SQLite/Drift persistence on native platforms and a separate web persistence implementation.
- CSV export, JSON v2 backup, JSON/CSV import and destructive reset controls.
- Android GitHub Releases update checks, mandatory SHA-256 verification and a user-mediated share-sheet installer handoff.

The latest main push, [workflow run #135](https://github.com/koushik4475/pageclock/actions/runs/42797075868), completed successfully on 10 November 2026 at commit `c0572869025a0efd8d1b38de3228e3aa61811f35`: analysis passed, **54 Flutter tests passed**, the web build succeeded, and Android produced a `1.0.0+135` APK build artifact with versionCode 135. The release-publishing job was skipped because this was a main-branch push; it did not publish a new release. The latest published release remains [v1.0.0+122](https://github.com/koushik4475/pageclock/releases/tag/v1.0.0%2B122). GitHub's APK asset digest is `sha256:9b110c8032dd3027dd17a3afb322c65917355bb988edff07d496f2331d6e6cc7`, matching the checksum emitted by the release workflow. The main build also generated a checksum for its unpublished +135 artifact. CI evidence does not prove physical-device installation, Play Protect acceptance, notification delivery or certificate continuity.

## Findings from the current source review

### P1 — Subject/project management is incomplete

The timer still uses a hard-coded five-item `_availableProjects` list. A `Subjects` table exists in the database, but the current repository contract has no subject CRUD API and the UI has no create, rename, recolour, archive or delete flow.

The JSON v2 exporter accepts a `subjects` collection but the Settings screen calls it without one, so it exports an empty list. The parser can read subjects, but the import handler currently imports sessions/settings only and ignores `parsed.subjects`.

**Recommendation:** implement a small local subject repository and management flow, then wire the timer picker and JSON backup round-trip to it. Keep it fully offline; do not add accounts or cloud sync.

### P1 — Historical time-entry correction is missing

The UI can create manual entries and clear all sessions, but it does not expose a complete edit/delete/undo workflow for one historical entry. This makes correction of an accidental duration, description or project difficult.

**Recommendation:** add a focused entry detail sheet with edit and soft-delete/undo, plus a deliberate start/end date-time editor for manual entries. Validate zero/negative duration, end-before-start, cross-midnight entries and timezone changes. Toggl's Android guide exposes start date, start/end time and delete controls on existing entries; PageClock currently only adds a new duration entry.

### P1 — APK updater origin and size hardening is still pending

The current main-branch downloader requires a valid SHA-256 and HTTPS, but it accepts any HTTPS host and has no maximum streamed download size. Draft PR [#21](https://github.com/koushik4475/pageclock/pull/21) adds an exact GitHub release-host allowlist, an initial 200 MiB content-length cap and a streamed-byte cap. The first streamed-overflow/cleanup run [#138](https://github.com/koushik4475/pageclock/actions/runs/42798654623) passed 58 tests. I then added checksum-sidecar host/redirect validation, a 4 KiB response cap and two sidecar regression tests. Run [#143](https://github.com/koushik4475/pageclock/actions/runs/42799492001) exposed a nullable-URI analyzer error; the follow-up fix passed in [run #145](https://github.com/koushik4475/pageclock/actions/runs/42799939532), with **60 tests passed** and the web build successful. The Android build job is skipped for this downloader-focused PR. This changes a security boundary, so it remains draft and must receive explicit maintainer/security review; do not auto-merge it.

The current installer intentionally avoids `REQUEST_INSTALL_PACKAGES` and hands the already-verified APK to the Android share sheet. This is safer than silently granting PageClock permission to install unknown apps, but the real save-to-Downloads/open-installer sequence still needs device verification.

### P1 — Android signing, Play Protect and foreground-service acceptance need device/console evidence

The release workflow built and published v1.0.0+122, and main CI run #135 built an unpublished +135 artifact. The workflow uses the configured keystore secrets, but no CI step currently records and compares the APK signing-certificate SHA-256 fingerprint across releases. Keep the existing application ID (`com.example.pageclock`) and release keystore continuity intact; changing either can break install-over-existing-app updates. Track the physical release gate in [issue #26](https://github.com/koushik4475/pageclock/issues/26).

The manifest declares an Android `specialUse` foreground service with a user-started focus-timer explanation. For Android 14+ and Google Play distribution, this must be supported by an accurate Play Console foreground-service declaration and a demonstration video. The timer notification must remain user-visible, stoppable and limited to the active user-started focus session.

Google's 2026 Android developer-verification rollout begins user-facing enforcement in selected countries on 30 September 2026 and broadens globally in 2027. Confirm the developer account, package ID and signing identity are registered before the global rollout; see Google's [developer-verification announcement](https://support.google.com/googleplay/android-developer/thread/421099111/android-developer-verification-rolling-out-to-all-devs-on-play-console-android-developer-console?hl=en-GB).

### P1 — Pause-aware calendar and reporting is inaccurate after resumed pauses

A completed session stores `pausedTotalMs`, but `pausedAtUtc` is cleared after resume, so the model loses the exact position of completed pause intervals. `StatsEngine.splitSessionByLocalDay` and `CalendarScreen` split from `startedAtUtc` to `endedAtUtc` using wall-clock time and therefore count paused time as focus time. `ReportsScreen` also filters week/month sessions by start timestamp and sums the full duration, so long sessions crossing a period boundary are not allocated accurately. This can distort daily goals, streaks, calendar blocks and reports. Tracking is in [issue #25](https://github.com/koushik4475/pageclock/issues/25). A correct fix needs versioned local pause-interval persistence and backward-compatible backup handling; do not infer pause locations for legacy sessions or merge a data-format change without explicit review.

### P2 — Backup recovery needs complete, atomic round-trips

JSON v2 currently handles sessions and settings but does not round-trip subjects. Import writes sessions one by one before asking whether to restore settings; there is no transaction/rollback boundary for the whole restore. A malformed or interrupted import can therefore leave a partial restore.

**Recommendation:** validate the complete payload first, preview counts and conflicts, then apply sessions, subjects and optional settings transactionally. Preserve legacy v1 JSON and CSV compatibility.

### P2 — Accessibility and responsive QA are not complete

Source code contains responsive width constraints in several dialogs, but no hosted-browser end-to-end run or physical tablet/phone accessibility sign-off was found in the latest CI evidence.

**Recommendation:** add semantic labels and minimum touch targets for icon-only controls; verify large text, landscape, narrow web widths, keyboard navigation and screen-reader order.

## Prioritized feature-gap shortlist

| Priority | Candidate | User value | Scope | Offline/privacy impact | Evidence / decision |
|---|---|---|---|---|---|
| P1 | Subject CRUD + subject-aware backup | Replace the fixed project list with the user's own reading/work categories; prevent orphaned subject references | Medium | Local-only; no additional collection or network | Existing Subjects table is unused by the UI and backup handler |
| P1 | Edit/delete one time entry with undo | Correct accidental or misclassified sessions without wiping history | Medium | Local-only; use existing soft-delete metadata | Current UI has manual add and bulk clear, not single-entry correction |
| P1 | APK host allowlist + streamed size cap | Reduce malicious redirect and unbounded-download exposure | Small/medium | No new personal data; network remains GitHub-only | Draft security PR #21; require maintainer review before merge |
| P1 | Physical Android release/update smoke suite | Catch Play Protect, signing, notification, FileProvider and installer handoff failures | Medium QA effort | Device-local test; no telemetry required | [Issue #26](https://github.com/koushik4475/pageclock/issues/26); CI cannot prove device installer or Play Protect behaviour |
| P1 | Android PR compile gate (debug-only, no secrets) | Catch Gradle, manifest and plugin regressions before merge without exposing production signing credentials | Small/medium | Debug signing only; no release secrets | Main CI skips Android on pull_request; PR #22 has a working no-secret job but is bundled with platform expansion |
| P1 | Pause-aware calendar, goals and reports | Stop counting paused wall-clock time as focus; allocate cross-midnight and cross-period sessions accurately | Medium/high | Local-only; requires versioned pause-interval persistence and legacy backup handling | [Issue #25](https://github.com/koushik4475/pageclock/issues/25); current model loses completed pause positions |
| P2 | Android quick-start widget / Quick Settings tile | Start/stop the active timer without opening PageClock | Medium | No new data collection; offline local action | Toggl's official Android guide documents timer widgets and quick-start tiles |
| P2 | Raise Android compileSdk to 36 | Remove current plugin compatibility warning and stay aligned with dependencies | Medium | No privacy/data impact | Main CI #135 builds on SDK 35 but warns two plugins require 36; Android Gradle Plugin 8.10 supports API 36 and requires Gradle 8.11.1 |
| P2 | Transactional backup preview/restore | Make recovery predictable and prevent partial imports | Medium | Local-only; no cloud backup | Current import is sequential and omits subjects |
| P2 | Accessibility and responsive polish | Improve usability across font scales, tablets and keyboard/screen-reader users | Medium | No privacy impact | Needs browser/device exploration beyond compilation |
| P3 | Optional native iOS/macOS distribution | Reach iPhone/iPad/Mac users | Large | App Store/notarized distribution; no new data required | Draft PR #22 passed simulator/macOS CI run #140 but is not a signed/distributable release and requires explicit product approval |

Do not add activity surveillance, automatic app/site monitoring, team administration, account/authentication services, cloud sync, social feeds or AI-generated productivity scoring without explicit product approval. These would add complexity and/or undermine PageClock's offline-first privacy position.

## 2026 competitor/product evidence

The useful patterns are lightweight organization, reliable time data and understandable history—not copying enterprise feature breadth:

- [Toggl Track's Android guide](https://support.toggl.com/en-us/article/toggl-track-timer-for-android-1v3i5g8/) documents a compact Timer/Calendar/Reports/Settings flow, manual entry with editable start date/time, create/edit/archive projects, a currently-running timer widget, quick-start tiles, Pomodoro and offline-sync status. The highest-value PageClock takeaways are editable historical entries, user-managed subjects and one-tap Android start/stop controls—not account sync or paid team features.
- [Toggl Product Hub — 20 October 2026](https://toggl.com/product/toggl-flagship-product) describes a broader planning experience with a visual calendar, capacity/workload views and project dashboards, while confirming Toggl Track remains supported. PageClock should borrow only the clarity of project context and progress summaries, not team capacity administration.
- [Clockify's feature overview](https://clockify.me/features/) emphasizes start/stop, manual entry and editing, one-click continue, calendar blocks, filtered reports and project/task organization. Its [mobile app overview](https://clockify.me/apps) lists offline mode and default projects on Android/iOS. PageClock should keep the offline-first model and add stronger local editing and subject defaults rather than copy team administration or activity surveillance.
- [Forest on the App Store](https://apps.apple.com/in/app/forest-focus-for-productivity/id866450515) highlights custom tags, weekly/monthly/yearly focus history, milestones and visual progress. PageClock can adopt the useful low-friction parts—custom subjects/tags and clearer history—without adding gamified social mechanics.

## Android policy and release checks

- [Android foreground-service type requirements](https://developer.android.com/about/versions/14/changes/fgs-types-required) require an appropriate service type and permission for Android 14+.
- [Google Play foreground-service policy](https://support.google.com/googleplay/android-developer/answer/18265346?hl=en) requires a core, user-beneficial, user-initiated/perceptible and stoppable use case.
- [Google Play foreground-service declaration guidance](https://support.google.com/googleplay/android-developer/answer/13392821?hl=en-GB) calls for a description, user-impact explanation and demonstration video for each declared type.
- [Android notification runtime permission guidance](https://developer.android.com/develop/ui/compose/notifications/notification-permission) explains the Android 13+ permission flow and why denied notifications affect what users see.
- [Android developer verification (2026 announcement)](https://support.google.com/googleplay/android-developer/thread/421099111/android-developer-verification-rolling-out-to-all-devs-on-play-console-android-developer-console?hl=en-GB) describes the initial 30 September 2026 enforcement in Brazil, Indonesia, Singapore and Thailand, with broader global rollout in 2027.

Keep SHA-256 verification mandatory, preserve the signing key and application ID, use HTTPS only, and never bypass Play Protect or signing checks.

## Open pull-request triage at review time

- [#20 — Node 24 GitHub Actions upgrades](https://github.com/koushik4475/pageclock/pull/20): draft; the web PR workflow passes. All five third-party action commit SHAs in the branch are GitHub-verified, but the PR run does not exercise Android artifact upload/download or the release publisher. The publisher token input and action supply-chain change require maintainer review before making it ready.
- [#21 — APK download hardening](https://github.com/koushik4475/pageclock/pull/21): draft; latest run #138 is in progress after adding streamed-overflow and partial-file-cleanup coverage. It changes a security boundary; keep pending explicit security review.
- [#22 — iOS/macOS and responsive layout work](https://github.com/koushik4475/pageclock/pull/22): draft; previous CI exposed two build blockers (a double-escaped semantic-version regex and Flutter's unsupported iOS Simulator `--release` mode) and showed release signing secrets in the PR Android job. The branch now separates a no-secret Android debug PR build from trusted release builds, uses a debug Android artifact and fixes the version regex. Run [#140](https://github.com/koushik4475/pageclock/actions/runs/42798757116) passed analysis/tests/web, Android PR debug build, iOS Simulator debug build and macOS debug build. The branch has also expanded from iOS CI into macOS desktop and responsive-navigation changes without product approval; keep it draft until the platform scope is explicitly approved. No PR job should receive production keystore secrets, and no physical iOS/macOS device or App Store signing test has run.
- [#29 — optional client accounts/admin foundation](https://github.com/koushik4475/pageclock/pull/29): draft; this adds Supabase auth, profiles, device/consent/audit tables, RLS and admin UI. It is a substantial cloud/account and privacy-scope expansion with no product approval. CI run [#148](https://github.com/koushik4475/pageclock/actions/runs/42800578140) failed analysis on a missing closing parenthesis in `account_portal.dart:136`; it also reports the deprecated `anonKey` argument. Static review found unguarded Supabase initialization (could block offline startup), mutable consent history and no account-deletion flow or RLS integration tests. Keep draft and do not merge or configure production until the account feature is explicitly approved and those controls are tested.
- Timer restoration race fix [#23](https://github.com/koushik4475/pageclock/pull/23) and the first QA roadmap refresh [#24](https://github.com/koushik4475/pageclock/pull/24) are merged; main workflow run #135 passed after #23.
- This documentation-only refresh is [PR #27](https://github.com/koushik4475/pageclock/pull/27); its latest workflow run [#144](https://github.com/koushik4475/pageclock/actions/runs/42799670703) passed.

## QA evidence and remaining sign-off

Repository governance finding: GitHub reports `main`, `release/v1.0.0+57` and `release/v1.0.0+58` as unprotected, and the rulesets endpoint returns an empty list. `release/v1.0.0+57` is 22 commits behind main and still carries a legacy workflow with workflow-wide `contents: write` and skipped tests on release refs; `release/v1.0.0+58` is 2 commits behind main. Do not push, fast-forward or delete either release branch as part of routine maintenance because its workflow can publish. Administrative remediation is tracked in [issue #19](https://github.com/koushik4475/pageclock/issues/19); required status checks, force-push protection and approved bypass actors need repository-admin review.

Latest successful CI/release evidence:

- Main push [run #135](https://github.com/koushik4475/pageclock/actions/runs/42797075868): analysis passed, 54 Flutter tests passed, web built, and Android generated a +135 APK/checksum artifact. The release-publishing job was skipped; no new release was created.
- Published release [v1.0.0+122](https://github.com/koushik4475/pageclock/releases/tag/v1.0.0%2B122), published 9 November 2026: APK and `.sha256` sidecar are present. GitHub's APK asset digest matches the checksum printed by the release workflow. This verifies the release pipeline's checksum consistency, not the signing certificate.
- The Android build log warns that `flutter_plugin_android_lifecycle` and `shared_preferences_android` require compileSdk 36 while the project compiles against SDK 35. This is not a one-line bump: the project currently uses AGP 8.6.1 and Gradle 8.10.2, while [AGP 8.10 supports API 36 and requires Gradle 8.11.1](https://developer.android.com/build/releases/agp-8-10-0-release-notes?hl=en). Treat the toolchain upgrade as a focused medium-scope Android PR and verify it on the Android PR build before release.
- Android workflow logs show masked keystore secrets are present, but no fingerprint comparison is automated. No physical device or Play Protect evidence is available.

Automated tests cover version comparison, release metadata/checksum parsing, redirect/checksum behaviour, eleven theme palettes and contrast, selected button flows, settings persistence, JSON/CSV round-trips, reports/statistics and update pressure. Main run #135 also passed the delayed-restore and concurrent-start regression tests merged in PR #23. There is still no full UI test for every settings/notification/backup recovery control, and no real-device or hosted-browser end-to-end pass.

Still required on real Android hardware:

1. Cold launch with and without an active session; start, pause, resume, stop and process-kill recovery.
2. Android 13+ notification permission granted/denied/re-enabled; ongoing timer notification actions; reminder delivery after reboot/timezone change.
3. Install-over-existing-app and signing-certificate continuity; Play Protect scan and installer handoff from the verified APK.
4. Update check, redirect restrictions, checksum failure, cancellation, low storage and retry behaviour.
5. All eleven themes, large font scale, landscape and narrow-screen layouts.
6. Backup export, destructive import/restore, malformed backup and recovery from interruption.
7. Compare APK signing-certificate fingerprints across the published +122 release and the next published APK; verify package/version metadata and install-over-existing-app continuity.
8. Complete Google Android developer verification registration for the exact package/signing identity ahead of the global 2027 rollout.

A successful Flutter build is not a physical-device test. No Play Protect approval, real installer launch, physical notification delivery, iOS device run or hosted-browser end-to-end pass is claimed by this review.
