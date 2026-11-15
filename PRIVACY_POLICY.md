# Privacy Policy for PageClock

**Last updated:** November 15, 2026

PageClock is designed as a privacy-respecting, offline-first reading and focus tracker. This policy outlines how your data is handled across platforms and modes in strict compliance with the **Google Play Developer Policy**, the **Apple App Store Review Guidelines (Section 5.1 - Privacy)**, and international privacy standards (including GDPR).

> [!NOTE]
> This policy was updated in November 2026 to clearly distinguish the fully offline native mobile builds from the optional, opt-in cloud synchronization feature available on Web. The final policy wording is subject to human owner review and does not constitute formal legal counsel.

---

## 1. Platform & Architectural Separation

PageClock strictly differentiates between client platforms:

### A. Android & iOS Native Applications (100% Offline-First)
- **Zero Cloud Communication:** Native mobile builds do not connect to any cloud server, synchronization engine, or database backend.
- **Zero Third-Party Trackers or SDKs:** No advertising frameworks, analytics trackers, behavioral logging libraries, or remote tracking SDKs are compiled into or loaded by the mobile apps.
- **On-Device Storage Only:** All reading sessions, subjects, notes, custom theme preferences, and daily goal metrics reside exclusively on your physical device using encrypted SQLite (via Drift).

### B. Web Application (Local by Default, Optional Cloud Sync)
- **Local Guest Mode (Default):** When opening the web app (e.g. at `pageclock.pages.dev`), PageClock operates 100% locally in your browser using isolated local storage partitions (`SharedPreferences` / `localStorage`). No account registration or internet connectivity is required.
- **Optional Account & Cloud Sync (Opt-In Only):** Users who desire cross-device synchronization may explicitly opt in by creating or signing in to a free account. Cloud synchronization is only initialized when this feature is active and configured.

---

## 2. What Data Is Processed and Stored (Web Cloud Mode)

When you explicitly sign in to synchronize your reading sessions on the Web, the following data is processed:

1. **Authentication Information:**
   - **Email OTP:** If signing in via email one-time passcode (OTP), your email address is transmitted to Supabase Auth to generate a secure 6-digit verification code.
   - **Google OAuth:** If signing in via Google, authentication occurs via standard OAuth redirect. We receive your unique user identifier, primary email address, and optional display name/avatar from Google. We request minimum scopes (`openid`, `email`, `profile`) and do not access your contacts, files, or calendar.
2. **Reading Session Data:**
   - Completed reading sessions (`started_at_utc`, `ended_at_utc`, `duration_ms`, `pause_intervals`, `tz_offset_min`, optional user notes, and creation timestamps).
   - *In-Flight Timers Are Local:* Running timers and paused in-flight timers are kept strictly local to your device and are never transmitted to the cloud until a session is completed.
   - *Settings & Preferences:* Visual themes, goal numbers, and UI preferences remain local to your browser and are not uploaded.
3. **Third-Party Sub-Processors:**
   - **Supabase Inc.:** Provides secure Postgres database storage and managed authentication. Data is protected by strict PostgreSQL Row Level Security (RLS) policies ensuring users can only read, insert, or update their own partitioned records.
   - **Resend:** Transactional email delivery service used exclusively to dispatch 6-digit verification codes for email sign-in. Resend receives the destination email address and token; it never receives your reading logs or database records.

---

## 3. Guest Data & Opt-In History Merge

- **Guest Data Is Sacred:** If you have used PageClock as a guest on your browser, your local guest history is never automatically uploaded or merged without your explicit permission.
- **First Sign-In Prompt:** Upon first signing in, you are presented with an explicit choice:
  1. *Merge this browser's history into my account:* Copies completed guest sessions into your cloud account partition.
  2. *Use my account's cloud history only:* Preserves your guest partition on the browser while pulling only existing cloud records.
  3. *Not now:* Keeps the prompt accessible in the account menu for future review.
- Your local guest partition is preserved and remains intact if you sign out.

---

## 4. Data Ownership, Retention & Account Deletion ("Right to be Forgotten")

In accordance with GDPR, CCPA, and Apple/Google account management requirements, you retain 100% sovereign ownership over your reading data:

- **Complete Data Portability:** You can export all your data at any time (via **Settings → Export Sessions** or the **Account Menu**) as standard JSON, CSV, or formatted PDF reports.
- **Deletion of Individual Sessions:** Deleting or undoing a session sets a tombstone. On synchronized devices, the session's note and content are cleared from the cloud database and the record is marked deleted (`deleted_at_ms`).
- **Clear All Data:** In guest mode, clearing data wipes local storage. In signed-in mode, clearing data marks all user sessions as deleted across all synchronized devices.
- **Complete In-App Account Deletion:**
  - You can permanently delete your cloud account at any time directly within the application (**Account Menu → Delete Account**).
  - Confirming account deletion invokes a dedicated server-side routine (`delete-account` Edge Function) that immediately and permanently deletes your authentication identity from `auth.users`.
  - Database foreign keys cascade deletion, permanently erasing all associated reading records and cloud metadata.
  - Your local user partition and sync metadata are wiped from the browser, and your session reverts cleanly to local Guest mode.

---

## 5. Free Tier Service Notice & Backup Recommendation

> [!IMPORTANT]
> PageClock's free community cloud tier operates without automated enterprise disaster-recovery snapshots. In addition, inactive free projects may be paused by cloud providers.
> **Recommendation:** We strongly recommend that users periodically download a local backup of their reading history using **Settings → Export JSON Backup** or **Export CSV** to ensure permanent, offline data safety.

---

## 6. System Permissions

PageClock requests only the minimum system permissions necessary to operate:
- **Foreground Service & Notification (Android):** Required strictly to keep the reading stopwatch accurate while your screen is off or while navigating outside the app, and to post completion notifications.
- **Storage / File Picker (All Platforms):** Required only when you explicitly export PDF/CSV/JSON files or import a backup file you select.

---

## 7. Contact & Owner Review

If you have questions, feedback, or requests regarding this Privacy Policy or your data rights, please contact:
- **Developer / Maintainer:** Koushik
- **Repository:** [https://github.com/koushik4475/pageclock](https://github.com/koushik4475/pageclock)
- **Email:** koushik4475@gmail.com
