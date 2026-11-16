# Architecture Decision Record: Optional Web-Only Cloud Sync

- **Status:** Approved for Web + Android implementation
- **Date:** 2026-11-15
- **Scope:** Flutter Web and Android (iOS remains offline-first for this release)
- **Governing Policy:** AGENTS.md §5 (Security and data integrity; no unauthorized telemetry or remote config)
- **Feature Flag:** `PAGECLOCK_CLOUD_AUTH_ENABLED` (Default: `false`)

---

## 1. Context & Problem Statement

PageClock was designed as a zero-setup, offline-first reading focus tracker. On Android, sessions are stored in an encrypted/private SQLite database via Drift. On Flutter Web, sessions are stored in browser local storage (`SharedPreferences` under key `pageclock_web_sessions_v1`).

While this guarantees privacy and zero network dependency, web users face critical limitations:
1. Clearing browser data or using private browsing permanently deletes reading history.
2. Users reading across multiple computers (e.g., work and personal laptops) cannot access a unified reading history.
3. Browser storage quota eviction can silently jeopardize long-term focus records.

Users desire an optional mechanism to back up and synchronize reading sessions across web browsers without sacrificing the instant, private guest mode that defines PageClock.

---

## 2. Decision

We will provide an **optional cloud authentication and synchronization system on Flutter Web and Android** powered by Supabase Auth and PostgreSQL with Row Level Security (RLS).

### Core Tenets:
1. **Guest Mode is Sacred:** PageClock web continues to function 100% offline with zero login requirement. First-time visitors enter guest mode instantly.
2. **Opt-In Sync Only:** Account creation is entirely optional ("Back up & sync"). Guest history is never automatically uploaded; users are prompted with an explicit choice (Merge, Cloud-only, or Not now) upon first sign-in.
3. **Platform Isolation:** Flutter Web and Android can opt into cloud authentication and sync. iOS remains offline-first in this release. Guest mode remains fully local on every platform.
4. **Compile-Time Feature Flag (Default OFF):** All cloud-related pathways are inert unless compiled with `PAGECLOCK_CLOUD_AUTH_ENABLED=true` alongside valid web credentials.
5. **Least Privilege & Local-First:** Writes always hit local browser storage first. Sync runs asynchronously in the background. Only completed sessions and tombstones sync; running timers remain strictly device-local.

---

## 3. Scope & Native Safety Guardrails

To strictly honor `AGENTS.md` §5 ("Preserve offline-first behavior and least privilege. A release update must not introduce telemetry, remote config, or permissions unless separately justified and reviewed"):

- **Guarded Code Execution:** `CloudConfig.isEnabledFor` enables cloud features only on Web or Android when the flag and public project configuration are present. iOS and desktop remain disabled.
- **Android OAuth Callback:** The app registers only the `com.example.pageclock://login-callback` deep-link intent filter. No new Android permissions or background services are required.
- **Native Data Isolation:** Guest data remains in the existing `pageclock.sqlite`; each authenticated user receives a separate Drift database file. Only completed sessions and tombstones are synchronized.
- **Release Continuity:** Every merge to `main` continues to ship production-signed Android APKs with identical signing identity and verified checksums (`AGENTS.md` §1–§4).

---

## 4. What Data Leaves the Browser (and when)

### When Data Leaves:
Data is transmitted **only** after:
1. An explicit user-initiated sign-in action (Google OAuth or email 6-digit OTP).
2. Explicit confirmation of guest history import or saving a new completed session while signed in.

### Data Transmitted:
- **Authentication Identifiers:** User email address and Supabase-assigned user UUID.
- **Completed Reading Sessions (`reading_sessions` table):**
  - Session identifiers: `id` (client-generated), `user_id` (foreign key to `auth.users`).
  - Timestamps: `started_at_utc` (epoch ms), `ended_at_utc` (epoch ms), `created_at_ms`, `updated_at_ms`, `deleted_at_ms` (tombstone).
  - Durations & Offsets: `paused_total_ms`, `duration_ms`, `tz_offset_min`.
  - Pause History: `pause_intervals` JSON array (`[{start_utc, end_utc}]`).
  - Session Metadata: `note` (book title or thoughts, max 2000 chars), `subject_id` (max 200 chars), `source` (`'timer'` or `'manual'`).
  - Server Sequence: `server_seq` (server-assigned monotonically increasing integer for sync cursor).

### Data NEVER Transmitted:
- **Active / Running Timers:** An active timer (`endedAtUtc == null`) is strictly device-local.
- **Cancelled Session Tombstones:** Timers cancelled before completion are soft-deleted locally but never pushed to the cloud.
- **Hardware Identifiers:** `device_id` is hard-coded to `'local'` on web; no device fingerprinting or MAC/hardware telemetry is collected.
- **Settings & Preferences:** Local clock faces, display settings, and theme choices remain local to each device.

---

## 5. Third-Party Subprocessors

| Subprocessor | Purpose | Data Shared | Security Controls |
|---|---|---|---|
| **Supabase Inc.** | Hosted PostgreSQL DB, Auth service, Edge Functions | User email, User UUID, encrypted session records | Row Level Security (RLS), TLS in transit, AES-256 at rest, SOC 2 Type II compliant |
| **Google LLC** | Federated Single Sign-On (Google OAuth) | Email, profile name/avatar metadata via PKCE redirect | Scopes restricted to `openid email profile` only; PKCE flow with no client secrets in app |
| **Resend Inc.** | Custom SMTP email delivery for 6-digit OTP codes | Recipient email address, one-time verification token | TLS encrypted SMTP, 600s token TTL, no confirmation URLs (prevents email scanner token burning) |

---

## 6. Explicitly Prohibited & Excluded Features (AGENTS §5 Compliance)

The following capabilities are **strictly excluded** from this release:
1. **NO Analytics / Tracking SDKs:** No Google Analytics, PostHog, Mixpanel, or telemetry libraries.
2. **NO Remote Configuration:** No Firebase Remote Config, LaunchDarkly, or dynamic feature flag services.
3. **NO Crash Reporting SDKs:** No Sentry, Crashlytics, or remote exception phone-home handlers.
4. **NO Cloud Profiles / Social Graphs:** No `profiles` or `users` public tables. Display metadata is extracted strictly from `auth.users` session metadata.
5. **NO Cloud Preferences / Subjects:** User preferences and subject tags remain device-local.

---

## 7. Security Architecture & Least Privilege

1. **Client Credential Boundary:** Only the public Supabase project URL and public publishable API key are embedded in Web/Android client builds. These values are designed for client exposure and are constrained by RLS.
2. **Zero Secrets in Repository or Client Bundle:** Service-role keys, database passwords, SMTP credentials, and Google OAuth client secrets are never committed to git, never passed to `--dart-define`, and never embedded in compiled JavaScript.
3. **Postgres Row Level Security (RLS):**
   - The `anon` role is completely locked out (`REVOKE ALL`).
   - Authenticated users can only `SELECT`, `INSERT`, and `UPDATE` rows where `user_id = auth.uid()`.
   - `DELETE` is permanently revoked for authenticated users; deletions are recorded as tombstones (`deleted_at_ms`), preventing accidental data clobbering or resurrection.
   - Account deletion triggers a PostgreSQL `ON DELETE CASCADE` from `auth.users` via a dedicated secure Edge Function (`delete-account`).
4. **Abuse Mitigation:**
   - Per-user cap of 20,000 reading session rows enforced by a database trigger (`reading_sessions_guard`).
   - String length caps and array length bounds prevent oversized payload injection.
   - Guard trigger enforces Last-Write-Wins (LWW) and rejects timestamps dated more than 24 hours in the future.

---

## 8. Owner Review & Sign-Off

Per `AGENTS.md` §5, this decision must be reviewed and approved by the project owner before merging cloud synchronization into the production default branch.

- [x] Web + Android scope approved; iOS remains offline-first.
- [x] No telemetry or analytics introduced.
- [ ] Google OAuth provider credentials and redirect allowlist configured in Supabase.
- [ ] Email OTP template and SMTP delivery verified.
- [ ] Android merged manifest and signed release pipeline verified.

**Approved by:** Project owner (explicit approval in ChatGPT on 2026-11-16)  
**Date:** 2026-11-16
