# PageClock Product QA Review and Roadmap

Review date: 11 November 2026  
Reviewed main commit: `5bbdf6b765a926739a6535b88fd7064d420de593`  
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

The latest main push, [workflow run #159](https://github.com/koushik4475/pageclock/actions/runs/42805760700), completed successfully on 10 November 2026 at commit `5bbdf6b765a926739a6535b88fd7064d420de593`: Dart analysis, the full Flutter test suite and web build passed; the Android release job also passed. Its log shows the masked release-keystore secrets were supplied, PageClock was built as versionName `1.0.0` / versionCode `159`, and the APK checksum was `68a9eb6c2ec62352fd21171b0b1370dc469e36abf003a6a7a67959217f4778d7`. The release-publishing job was skipped on the main-branch push, so this is an unpublished CI artifact, not a new public release. The latest published release remains [v1.0.0+122](https://github.com/koushik4475/pageclock/releases/tag/v1.0.0%2B122), published 9 November 2026. Its tag resolves to commit `8821332eef9564714cd1b63270bd1ffbe9482e0e`, five commits behind current main. GitHub release metadata reports the APK SHA-256 digest `9b110c8032dd3027dd17a3afb322c65917355bb988edff07d496f2331d6e6cc7`, a 30,062,206-byte APK and a matching-name `.sha256` sidecar. This is GitHub asset/workflow metadata evidence, not an independent APK download and re-hash; it also does not prove certificate continuity or physical installation.

## Findings from the current source review

### P1 — Subject/project management is incomplete

The timer still uses a hard-coded five-item `_availableProjects` list. A `Subjects` table exists in the database, but the current repository contract has no subject CRUD API and the UI has no create, rename, recolour, archive or delete flow.

The JSON v2 exporter accepts a `subjects` collection but the Settings screen calls it without one, so it exports an empty list. The parser can read subjects, but the import handler currently imports sessions/settings only and ignores `parsed.subjects`.

**Recommendation:** implement a small local subject repository and management flow, then wire the timer picker and JSON backup round-trip to it. Keep it fully offline; do not add accounts or cloud sync.

### P1 — Historical time-entry correction is missing

The UI can create manual entries and clear all sessions, but it does not expose a complete edit/delete/undo workflow for one historical entry. This makes correction of an accidental duration, description or project difficult.

**Recommendation:** add a focused entry detail sheet with edit and soft-delete/undo, plus a deliberate start/end date-time editor for manual entries. Validate zero/negative duration, end-before-start, cross-midnight entries and timezone changes. Toggl's Android guide exposes start date, start/end time and delete controls on existing entries; PageClock currently only adds a new duration entry.

### P1 — APK updater origin and size hardening is still pending

The current main-branch downloader requires a valid SHA-256 and HTTPS, but it accepts any HTTPS host and has no maximum streamed download size. Draft PR [#21](https://github.com/koushik4475/pageclock/pull/21) adds an exact GitHub release-host allowlist, a 200 MiB declared and streamed-byte cap, redirect validation for APK and checksum-sidecar downloads, and a 4 KiB sidecar response cap. The early streamed-overflow/cleanup run [#138](https://github.com/koushik4475/pageclock/actions/runs/42798654623) passed 58 tests. Run [#143](https://github.com/koushik4475/pageclock/actions/runs/42799492001) exposed a nullable-URI analyzer error; the follow-up commits fixed it, and current PR head `7146670764ce92c9b3405b74138b5399e7a37a98` passed [run #145](https://github.com/koushik4475/pageclock/actions/runs/42799939532) with **60 tests passed** and the web build successful. Android build is skipped for this downloader-focused PR. Static review confirms mandatory SHA-256 is retained and each redirect is checked against the HTTPS GitHub asset-host allowlist. This changes a security boundary, so it remains draft for explicit maintainer/security review and must not be auto-merged.

The current installer intentionally avoids `REQUEST_INSTALL_PACKAGES` and hands the already-verified APK to the Android share sheet. This is safer than silently granting PageClock permission to install unknown apps, but the real save-to-Downloads/open-installer sequence still needs device verification.

### P1 — Android signing, Play Protect and foreground-service acceptance need device/console evidence

The release workflow built and published v1.0.0+122, and main CI run #135 built an unpublished +135 artifact. The workflow uses the configured keystore secrets, but no CI step currently records and compares the APK signing-certificate SHA-256 fingerprint across releases. Keep the existing application ID (`com.example.pageclock`) and release keystore continuity intact; changing either can break install-over-existing-app updates. Track the physical release gate in [issue #26](https://github.com/koushik4475/pageclock/issues/26).

The manifest declares an Android `specialUse` foreground service with a user-started focus-timer explanation. For Android 14+ and Google Play distribution, this must be supported by an accurate Play Console foreground-service declaration and a demonstration video. The timer notification must remain user-visible, stoppable and limited to the active user-started focus session.

Google's 2026 Android developer-verification rollout begins user-facing enforcement in selected countries on 30 September 2026 and broadens globally in 2027. Confirm the developer account, package ID and signing identity are registered before the global rollout; see Google's [developer-verification announcement](https://support.google.com/googleplay/android-developer/thread/421099111/android-developer-verification-rolling-out-to-all-devs-on-play-console-android-developer-console?hl=en-GB).

### P1 — Pause-aware calendar and reporting is inaccurate after resumed pauses

A completed session stores `pausedTotalMs`, but `pausedAtUtc` is cleared after resume, so the model loses the exact position of completed pause intervals. `StatsEngine.splitSessionByLocalDay` and `CalendarScreen` split from `startedAtUtc` to `endedAtUtc` using wall-clock time and therefore count paused time as focus time. `ReportsScreen` also filters week/month sessions by start timestamp and sums the full duration, so long sessions crossing a period boundary are not allocated accurately. This can distort daily goals, streaks, calendar blocks and reports. Tracking is in [issue #25](https://github.com/koushik4475/pageclock/issues/25). A correct fix needs versioned local pause-interval persistence and backward-compatible backup handling; do not infer pause locations for legacy sessions or merge a data-format change without explicit review.

### P2 — Pomodoro break/cadence state is lost or drifts

The Pomodoro break phase, remaining time and completed-focus count are held only in the timer screen's widget state. The break timer subtracts a fixed 1,000 ms for each `Timer.periodic` callback, so background suspension can make it drift; process death or widget recreation also loses the active break and long-break cadence. Track this in [issue #31](https://github.com/koushik4475/pageclock/issues/31). A correct fix should use a persisted UTC break deadline and a small versioned local Pomodoro state record, reconcile it with the active stopwatch session, and guard against duplicate completion/session creation. Keep it offline; review persistence compatibility before implementation.

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
| P1 | Android PR compile gate (debug-only, no secrets) | Catch Gradle, manifest and plugin regressions before merge without exposing production signing credentials | Small | Debug signing only; no release secrets | Merged in PR #30; PR run #154 passed the Android debug build without production secrets |
| P1 | Pause-aware calendar, goals and reports | Stop counting paused wall-clock time as focus; allocate cross-midnight and cross-period sessions accurately | Medium/high | Local-only; requires versioned pause-interval persistence and legacy backup handling | [Issue #25](https://github.com/koushik4475/pageclock/issues/25); current model loses completed pause positions |
| P2 | Android quick-start widget / Quick Settings tile | Start/stop the active timer without opening PageClock | Medium | No new data collection; offline local action | Toggl's official Android guide documents timer widgets and quick-start tiles |
| P2 | Raise Android compileSdk to 36 | Remove current plugin compatibility warning and stay aligned with dependencies | Medium | No privacy/data impact | Main CI #135 builds on SDK 35 but warns two plugins require 36; Android Gradle Plugin 8.10 supports API 36 and requires Gradle 8.11.1 |
| P2 | Transactional backup preview/restore | Make recovery predictable and prevent partial imports | Medium | Local-only; no cloud backup | Current import is sequential and omits subjects |
| P2 | Durable Pomodoro phase/deadline | Preserve break countdown and long-break cadence across backgrounding/restart | Medium | Local-only; small versioned state record | [Issue #31](https://github.com/koushik4475/pageclock/issues/31); current break ticker is callback-count based and state is widget-local |
| P2 | Accessibility and responsive polish | Improve usability across font scales, tablets and keyboard/screen-reader users | Medium | No privacy impact | Needs browser/device exploration beyond compilation |
| P3 | Optional native iOS/macOS distribution | Reach iPhone/iPad/Mac users | Large | App Store/notarized distribution; no new data required | Draft PR #22 passed simulator/macOS CI run #140 but is not a signed/distributable release and requires explicit product approval |

The basic account/sign-up/sign-in/password-reset and account-only admin foundation was explicitly requested and is being reviewed in PR #29. Do not extend it into cloud-sync of reading history, activity surveillance, automatic app/site monitoring, broad team administration, social feeds or AI-generated productivity scoring without separate product approval. Keep core timer, calendar, reports and backups usable offline.

## 2026 competitor/product evidence

The useful patterns are lightweight organization, reliable time data and understandable history—not copying enterprise feature breadth:

- [Toggl Track's Android guide](https://support.toggl.com/en-us/article/toggl-track-timer-for-android-1v3i5g8/) documents a compact Timer/Calendar/Reports/Settings flow, manual entry with editable start date/time, create/edit/archive projects, a currently-running timer widget, quick-start tiles, Pomodoro and offline-sync status. The highest-value PageClock takeaways are editable historical entries, user-managed subjects and one-tap Android start/stop controls—not account sync or paid team features.
- [Toggl My Activity — 2 November 2026](https://toggl.com/product/my-activity) drafts time logs from a local activity timeline, suggests labels from prior entries and can prepare a whole-day draft for review; Toggl says window titles, websites and calls stay on the computer and no audio is recorded. The useful PageClock pattern is optional local-only daily review and quick correction, not background surveillance.
- [Toggl Product Hub — 20 October 2026](https://toggl.com/product/toggl-flagship-product) describes a broader planning experience with a visual calendar, capacity/workload views and project dashboards, while confirming Toggl Track remains supported. PageClock should borrow only the clarity of project context and progress summaries, not team capacity administration.
- [Clockify's November 2026 changelog](https://clockify.me/help/whats-new) adds PDF dashboard export and user filters, while its October updates include timezone-aware aggregate reporting and offline-mode improvements. PageClock's immediate takeaway is accurate timezone/period allocation and reliable exports, not enterprise dashboard breadth.
- [Harvest's May 2026 update](https://www.getharvest.com/blog/inside-the-new-harvest) adds a calendar view that lets users track directly from their schedule. PageClock already has a calendar surface; the higher-value gap is correcting/editing entries from it and allocating paused sessions accurately.
- [Clockify's feature overview](https://clockify.me/features/) emphasizes start/stop, manual entry and editing, one-click continue, calendar blocks, filtered reports and project/task organization. Its [mobile app overview](https://clockify.me/apps) lists offline mode and default projects on Android/iOS. PageClock should keep the offline-first model and add stronger local editing and subject defaults rather than copy team administration or activity surveillance.
- [Clockify's idle-detection and reminder guide](https://clockify.me/help/track-time-and-expenses/idle-detection-reminders) documents scheduled reminders and configurable idle handling on desktop/browser surfaces. PageClock's useful version is a transparent, opt-in local reminder; background activity monitoring is unnecessary for a reading/focus tracker.
- [Foci's feature guide](https://usefoci.com/features) describes guest-first use, optional account sync, offline-first writes, keyboard shortcuts and accessible controls. PageClock should preserve its no-account/offline default and prioritize keyboard, screen-reader and touch-target polish before expanding account features.
- [Forest on the App Store](https://apps.apple.com/in/app/forest-focus-for-productivity/id866450515) highlights custom tags, weekly/monthly/yearly focus history, milestones and visual progress. PageClock can adopt the useful low-friction parts—custom subjects/tags and clearer history—without adding gamified social mechanics.

## Android policy and release checks

- [Android foreground-service type requirements](https://developer.android.com/about/versions/14/changes/fgs-types-required) require an appropriate service type and permission for Android 14+.
- [Google Play foreground-service policy](https://support.google.com/googleplay/android-developer/answer/18265346?hl=en) requires a core, user-beneficial, user-initiated/perceptible and stoppable use case.
- [Google Play foreground-service declaration guidance](https://support.google.com/googleplay/android-developer/answer/13392821?hl=en-GB) calls for a description, user-impact explanation and demonstration video for each declared type.
- [Android notification runtime permission guidance](https://developer.android.com/develop/ui/compose/notifications/notification-permission) explains the Android 13+ permission flow and why denied notifications affect what users see.
- [Android developer verification (2026 announcement)](https://support.google.com/googleplay/android-developer/thread/421099111/android-developer-verification-rolling-out-to-all-devs-on-play-console-android-developer-console?hl=en-GB) describes the initial 30 September 2026 enforcement in Brazil, Indonesia, Singapore and Thailand, with broader global rollout in 2027.

Keep SHA-256 verification mandatory, preserve the signing key and application ID, use HTTPS only, and never bypass Play Protect or signing checks.

## Pull-request triage at review time

- [#20 — Node 24 GitHub Actions upgrades](https://github.com/koushik4475/pageclock/pull/20): draft; current head `ae89541aee21c137260e632c10cac80eb4b0117f` passed PR workflow [run #124](https://github.com/koushik4475/pageclock/actions/runs/42752596724). Only the web verification job ran; Android release and publishing jobs were skipped on the PR ref. The branch pins five third-party actions to full commit SHAs and changes the release publisher token input. This is a supply-chain/release-path change, so retain draft status until maintainers validate the Android artifact and protected tag-release path.
- [#21 — APK download hardening](https://github.com/koushik4475/pageclock/pull/21): draft; current head `7146670764ce92c9b3405b74138b5399e7a37a98` passed [run #145](https://github.com/koushik4475/pageclock/actions/runs/42799939532), including analysis, 60 tests and web build. Static review confirms HTTPS GitHub-host allowlisting on the initial APK URL and each redirect, a 200 MiB declared/streamed byte cap, a 4 KiB checksum-sidecar cap, and mandatory SHA-256 before installation. Android release build is skipped. Keep draft pending explicit security review because it changes the updater's network trust boundary.
- [#33 — tag-only release publishing](https://github.com/koushik4475/pageclock/pull/33): draft; current head `d95940dddb2f94e5742826e27abbc7bcd7431ce1` passed [run #166](https://github.com/koushik4475/pageclock/actions/runs/42901984036). It restricts the current main workflow's signed APK/release jobs to main or an actual version-tag push and removes release-branch push publication from that workflow. This is a security-boundary change and must not be auto-merged. The legacy `release/v1.0.0+57` and `release/v1.0.0+58` branch workflows remain separate risks until those unprotected branches are safely retired and repository rulesets are configured.
- [#29 — optional client accounts and admin foundation](https://github.com/koushik4475/pageclock/pull/29): draft; current head `6ebd35a2af6a866879261df83312e8ebfd2647de` passed [run #165](https://github.com/koushik4475/pageclock/actions/runs/42826640054) for analysis/tests/web and the Android debug PR build. Static review now shows a paginated admin client directory, email search, an authenticated self-delete Edge Function, profile email synchronization from Supabase Auth, and append-only consent permissions in the second migration. Admin roles still require manual owner bootstrap; no production Supabase project, SMTP/redirect setup, RLS integration suite or staging sign-up/recovery/delete/admin-denial run is evidenced. Keep draft for security/privacy review and real backend validation. Reading sessions and notes remain local in the described design.
- [#35 — iOS-native navigation, cross-platform builds and pressure tests](https://github.com/koushik4475/pageclock/pull/35): draft; current head `2b65f9c0f728a809f1e4a208549bf1a71e26abaf` passed [run #168](https://github.com/koushik4475/pageclock/actions/runs/42978617705): analysis/tests/web, Android debug PR APK, unsigned iOS Simulator app and macOS build all succeeded. Earlier [run #167](https://github.com/koushik4475/pageclock/actions/runs/42974731168) failed because `flutter create` generated a starter `test/widget_test.dart` that referenced a missing `MyApp` constructor; the follow-up removes that generated starter test in the iOS job and the latest run passed. Keep draft until the expanded iOS/macOS product scope is explicitly approved; simulator/desktop CI is not physical iPhone testing, Apple signing or App Store validation. This refresh supersedes closed, unmerged cross-platform PR #22.
- Timer restoration race fix [#23](https://github.com/koushik4475/pageclock/pull/23) and the first QA roadmap refresh [#24](https://github.com/koushik4475/pageclock/pull/24) are merged; main workflow run #135 passed after #23.
- [#30 — Android PR compile gate](https://github.com/koushik4475/pageclock/pull/30): merged as `aaae2baaea64209a47ab7719a3cdfeb8fbb84461`. PR run [#154](https://github.com/koushik4475/pageclock/actions/runs/42802880101) passed the Android arm64 debug build and web checks; the job has only `contents: read`, no production signing secrets, and no release/artifact publishing.
- [#27 — Product QA roadmap refresh](https://github.com/koushik4475/pageclock/pull/27): merged as `5bdfec72e1d588fe0b1c65ddb6bdb98bbaf20a38`; PR run [#155](https://github.com/koushik4475/pageclock/actions/runs/42803126955) passed, followed by main push [#157](https://github.com/koushik4475/pageclock/actions/runs/42804115228).
- [#32 — post-merge roadmap sync](https://github.com/koushik4475/pageclock/pull/32): merged as current main commit `5bbdf6b765a926739a6535b88fd7064d420de593`; main push [#159](https://github.com/koushik4475/pageclock/actions/runs/42805760700) passed.

## QA evidence and remaining sign-off

Repository governance finding: GitHub reports `main`, `release/v1.0.0+57` and `release/v1.0.0+58` as unprotected, and the rulesets endpoint returns an empty list. The current main workflow still allows a push to `release/v*` to run the signed Android build and release publisher; draft PR #33 removes that path from the main workflow but is not merged. The legacy `release/v1.0.0+57` branch is 25 commits behind main and still carries a workflow with workflow-wide `contents: write` and skipped tests on release refs; `release/v1.0.0+58` is 5 commits behind main. All listed repository branches currently report `protected: false`. Do not push, fast-forward or delete either release branch as part of routine maintenance because its workflow can publish. Administrative remediation is tracked in [issue #19](https://github.com/koushik4475/pageclock/issues/19); required status checks, force-push protection, safe retirement of legacy release branches and approved bypass actors need repository-admin review.

Latest successful CI/release evidence:

- Main push [run #159](https://github.com/koushik4475/pageclock/actions/runs/42805760700): analysis/tests, web build and Android release APK/checksum packaging passed. The log supplied masked release-keystore secrets, built versionName 1.0.0 / versionCode 159 and emitted checksum `68a9eb6c2ec62352fd21171b0b1370dc469e36abf003a6a7a67959217f4778d7`. The release-publishing job was skipped; this artifact was not published.
- Published release [v1.0.0+122](https://github.com/koushik4475/pageclock/releases/tag/v1.0.0%2B122), published 9 November 2026: APK and `.sha256` sidecar are present. GitHub's APK asset digest matches the checksum printed by the release workflow. This verifies the release pipeline's checksum consistency, not the signing certificate.
- The Android build log warns that `flutter_plugin_android_lifecycle` and `shared_preferences_android` require compileSdk 36 while the project compiles against SDK 35. This is not a one-line bump: the project currently uses AGP 8.6.1 and Gradle 8.10.2, while [AGP 8.10 supports API 36 and requires Gradle 8.11.1](https://developer.android.com/build/releases/agp-8-10-0-release-notes?hl=en). Treat the toolchain upgrade as a focused medium-scope Android PR and verify it on the Android PR build before release.
- Android workflow logs show masked keystore secrets are present, but no fingerprint comparison is automated. No physical device or Play Protect evidence is available.

Automated tests cover version comparison, release metadata/checksum parsing, redirect/checksum behaviour, eleven theme palettes and contrast, selected button flows, settings persistence, JSON/CSV round-trips, reports/statistics and update pressure. Main run #135 passed the delayed-restore and concurrent-start regression tests merged in PR #23; the latest main run #159 also passed the full current workflow. There is still no full UI test for every settings/notification/backup recovery control, and no real-device or hosted-browser end-to-end pass.

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
