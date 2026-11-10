# PageClock Product QA Review and Roadmap

Review date: 10 November 2026  
Reviewed main commit: `8821332eef9564714cd1b63270bd1ffbe9482e0e`  
Latest published release: `v1.0.0+122`

## Current product baseline

PageClock is an offline-first personal reading/focus tracker. The current main branch includes:

- A persistent stopwatch with start, pause, resume, stop, active-session recovery and a minimum-duration prompt.
- Manual time-entry creation and a fixed project picker.
- Pomodoro focus/break intervals, configurable focus duration, break settings and completion notifications.
- A fullscreen flip clock / ambient focus screen.
- Eleven locally persisted themes.
- A 24-hour calendar timeline and reports with filters, project/category breakdowns, heatmap and PDF export.
- Local settings, daily focus goal, running-timer notification, Pomodoro notifications and scheduled daily reminders.
- SQLite/Drift persistence on native platforms and a separate web persistence implementation.
- CSV export, JSON v2 backup, JSON/CSV import and destructive reset controls.
- Android GitHub Releases update checks, mandatory SHA-256 verification and a user-mediated share-sheet installer handoff.

The latest main-branch workflow (run [42634687436](https://github.com/koushik4475/pageclock/actions/runs/42634687436)) completed successfully, and the release workflow (run [42634768498](https://github.com/koushik4475/pageclock/actions/runs/42634768498)) published [v1.0.0+122](https://github.com/koushik4475/pageclock/releases/tag/v1.0.0%2B122) with an APK and SHA-256 sidecar. These are CI/release facts, not proof of physical-device installation, Play Protect acceptance, notification delivery or upgrade continuity.

## Findings from the current source review

### P1 — Subject/project management is incomplete

The timer still uses a hard-coded five-item `_availableProjects` list. A `Subjects` table exists in the database, but the current repository contract has no subject CRUD API and the UI has no create, rename, recolour, archive or delete flow.

The JSON v2 exporter accepts a `subjects` collection but the Settings screen calls it without one, so it exports an empty list. The parser can read subjects, but the import handler currently imports sessions/settings only and ignores `parsed.subjects`.

**Recommendation:** implement a small local subject repository and management flow, then wire the timer picker and JSON backup round-trip to it. Keep it fully offline; do not add accounts or cloud sync.

### P1 — Historical time-entry correction is missing

The UI can create manual entries and clear all sessions, but it does not expose a complete edit/delete/undo workflow for one historical entry. This makes correction of an accidental duration, description or project difficult.

**Recommendation:** add a focused entry detail sheet with edit and soft-delete/undo. Validate zero/negative duration, end-before-start, cross-midnight entries and timezone changes.

### P1 — APK updater origin and size hardening is still pending

The current main-branch downloader requires a valid SHA-256 and HTTPS, but it accepts any HTTPS host and has no maximum streamed download size. Open draft PR [#21](https://github.com/koushik4475/pageclock/pull/21) adds an exact GitHub release-host allowlist and a 200 MiB cap, with passing PR CI. Because this changes a security boundary, it remains pending explicit maintainer/security review and must not be auto-merged by the maintenance loop.

The current installer intentionally avoids `REQUEST_INSTALL_PACKAGES` and hands the already-verified APK to the Android share sheet. This is safer than silently granting PageClock permission to install unknown apps, but the real save-to-Downloads/open-installer sequence still needs device verification.

### P1 — Android signing, Play Protect and foreground-service acceptance need device/console evidence

The release workflow successfully built and published the latest APK, but the repository review did not independently compare the APK signing-certificate fingerprint against earlier releases. Keep the existing application ID (`com.example.pageclock`) and release keystore continuity intact; changing either can break install-over-existing-app updates.

The manifest declares an Android `specialUse` foreground service with a user-started focus-timer explanation. For Android 14+ and Google Play distribution, this must be supported by an accurate Play Console foreground-service declaration and a demonstration video. The timer notification must remain user-visible, stoppable and limited to the active user-started focus session.

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
| P1 | Physical Android release/update smoke suite | Catch Play Protect, signing, notification, FileProvider and installer handoff failures | Medium QA effort | Device-local test; no telemetry required | CI cannot prove device installer or Play Protect behaviour |
| P2 | Transactional backup preview/restore | Make recovery predictable and prevent partial imports | Medium | Local-only; no cloud backup | Current import is sequential and omits subjects |
| P2 | Accessibility and responsive polish | Improve usability across font scales, tablets and keyboard/screen-reader users | Medium | No privacy impact | Needs browser/device exploration beyond compilation |
| P3 | Optional native iOS distribution | Reach iPhone/iPad users | Large | App Store/TestFlight distribution; no new data required | Draft PR #22 is not ready: see current CI blockers below; requires explicit product approval before expanding scope |

Do not add activity surveillance, automatic app/site monitoring, team administration, cloud sync, social feeds or AI-generated productivity scoring without explicit product approval. These would add complexity and/or undermine PageClock's offline-first privacy position.

## 2026 competitor/product evidence

The useful patterns are lightweight organization, reliable time data and understandable history—not copying enterprise feature breadth:

- [Toggl Product Hub — 20 October 2026](https://toggl.com/product/toggl-flagship-product) describes a broader planning experience with a visual calendar, capacity/workload views and project dashboards, while confirming Toggl Track remains supported. PageClock should borrow only the clarity of project context and progress summaries, not team capacity administration.
- [Toggl Product Hub release feed](https://toggl.com/product) lists October/November 2026 work including role-based time classification, activity-derived draft logs and shareable reports. Activity-derived logs are deliberately not recommended for PageClock because they introduce monitoring/privacy complexity.
- [Clockify changelog](https://clockify.me/help/whats-new) documents 2026 improvements around consistent duration modes, timezone-aware aggregation, offline operation and timer start/stop behaviour. PageClock already prioritizes offline use; the relevant takeaway is stronger timezone and duration correctness tests.
- [Forest on the App Store](https://apps.apple.com/in/app/forest-focus-for-productivity/id866450515) highlights custom tags, weekly/monthly/yearly focus history, milestones and visual progress. PageClock can adopt the useful low-friction parts—custom subjects/tags and clearer history—without adding gamified social mechanics.

## Android policy and release checks

- [Android foreground-service type requirements](https://developer.android.com/about/versions/14/changes/fgs-types-required) require an appropriate service type and permission for Android 14+.
- [Google Play foreground-service policy](https://support.google.com/googleplay/android-developer/answer/18265346?hl=en) requires a core, user-beneficial, user-initiated/perceptible and stoppable use case.
- [Google Play foreground-service declaration guidance](https://support.google.com/googleplay/android-developer/answer/13392821?hl=en-GB) calls for a description, user-impact explanation and demonstration video for each declared type.
- [Android notification runtime permission guidance](https://developer.android.com/develop/ui/compose/notifications/notification-permission) explains the Android 13+ permission flow and why denied notifications affect what users see.

Keep SHA-256 verification mandatory, preserve the signing key and application ID, use HTTPS only, and never bypass Play Protect or signing checks.

## Open pull-request triage at review time

- [#20 — Node 24 GitHub Actions upgrades](https://github.com/koushik4475/pageclock/pull/20): draft; its web PR checks pass, but the PR run does not exercise Android artifact upload/download or release publishing. Third-party action and release-token changes require maintainer supply-chain review.
- [#21 — APK download hardening](https://github.com/koushik4475/pageclock/pull/21): draft; web analysis/tests/build pass. Security-boundary change; keep pending manual review.
- [#22 — Native iOS and mobile CI](https://github.com/koushik4475/pageclock/pull/22): draft; current run fails because PR refs are parsed as release versions in the Android job and Flutter rejects `--release` for iOS Simulator builds. More seriously, the PR-enabled Android job receives release keystore secrets; PR validation must use debug signing and must never receive production signing credentials. This PR must not merge until fixed and explicitly approved.
- Timer restoration race fix is tracked separately in [#23](https://github.com/koushik4475/pageclock/pull/23); merge only after its complete checks pass.

## QA evidence and remaining sign-off

Latest successful release evidence:

- Main push run [42634687436](https://github.com/koushik4475/pageclock/actions/runs/42634687436): analysis, tests, web build and Android main-branch workflow completed successfully.
- Release run [42634768498](https://github.com/koushik4475/pageclock/actions/runs/42634768498): Android release APK build, checksum packaging and GitHub release publication completed successfully.
- Latest release [v1.0.0+122](https://github.com/koushik4475/pageclock/releases/tag/v1.0.0%2B122) contains the APK and matching `.sha256` sidecar. GitHub exposes a SHA-256 digest for the APK asset; the APK bytes were not independently downloaded and re-hashed in this source review.

Automated tests cover version comparison, release metadata/checksum parsing, redirect/checksum behaviour, eleven theme palettes and contrast, selected button flows, settings persistence, JSON/CSV round-trips, reports/statistics and update pressure. The newly opened timer restoration regression PR adds delayed-restore and concurrent-start tests.

Still required on real Android hardware:

1. Cold launch with and without an active session; start, pause, resume, stop and process-kill recovery.
2. Android 13+ notification permission granted/denied/re-enabled; ongoing timer notification actions; reminder delivery after reboot/timezone change.
3. Install-over-existing-app and signing-certificate continuity; Play Protect scan and installer handoff from the verified APK.
4. Update check, redirect restrictions, checksum failure, cancellation, low storage and retry behaviour.
5. All eleven themes, large font scale, landscape and narrow-screen layouts.
6. Backup export, destructive import/restore, malformed backup and recovery from interruption.

A successful Flutter build is not a physical-device test. No Play Protect approval, real installer launch, physical notification delivery, iOS device run or hosted-browser end-to-end pass is claimed by this review.
