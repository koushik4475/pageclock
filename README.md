# PageClock (Reading Focus Tracker)

Built according to PRD v1.0 specifications: Offline-first, Flutter + Riverpod + Drift + fl_chart. Zero paid services required.

## Architecture

- **Core & Persistence (`lib/core/`)**:
  - `models/reading_session.dart`: UUID-v7 compatible model storing UTC start/end, timezone offset, accumulated pause time, and soft-delete support for future sync.
  - `db/tables.dart`: Drift SQLite schema definition for `ReadingSessions`, `Subjects`, and `Settings`.
  - `repository/session_repository.dart`: Reactive repository pattern driving Riverpod streams.
  - `engine/stopwatch_engine.dart`: Timestamp-based reading stopwatch. Accurately calculates elapsed time from persisted timestamps without tick counting, surviving app kill, backgrounding, and reboot.
  - `services/export_service.dart`: CSV & JSON export/import service matching PRD §5.4.

- **Stats Engine (`lib/stats/`)**:
  - Pure-Dart analytics engine:
    - Midnight split: sessions crossing local midnight are split across each local day for aggregation.
    - Consistency score & streaks (current and best streak).
    - 4-week linear regression slope with steady threshold (|slope| < 5% of mean) indicating ▲ / ▼ / —.
    - Daily trend comparison.

- **UI & Charts (`lib/main.dart`)**:
  - **Timer View**: Displays live timer, pause/resume, and today's progress towards daily goal.
  - **Analytics View**: Metric cards (Consistency %, Streaks, Trends) + fl_chart bar charts for last 7 days and last 4 weeks.
  - **History View**: Session logs with manual session entry and soft deletion.
  - **Settings View**: Configurable daily goal, consistency threshold, theme switcher (Light/Dark/System), CSV export, and data wipe.

- **DevOps & QA (`test/`, `.github/workflows/ci.yml`)**:
  - `test/stats_engine_test.dart`: Midnight split and 4-week trend verification.
  - `test/prd_acceptance_test.dart`: Tests for PRD §13 criteria (AC-1, AC-2, AC-8).
  - GitHub Actions CI workflow to test and build Android APKs at ₹0.
