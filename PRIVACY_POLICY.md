# Privacy Policy for PageClock

**Last updated:** November 10, 2026

PageClock is an offline-first reading focus tracker. Core timer, calendar, reports, notes and reading-session features work without an account. Optional account features are inactive until a user chooses to register and the operator configures the backend.

## 1. Local data by default
- Reading sessions, subjects, notes and detailed personal metrics are stored locally on your device using SQLite (or the platform's local web storage).
- Signing in does not upload reading history, notes or session details.
- You can continue using PageClock without registering or signing in.
- Exported backups and reports remain under your control.

## 2. Optional account information
If you choose to create an account after online account services are enabled, Supabase Auth processes your email address and authentication credentials. An optional display name, account ID and account creation date are stored in the PageClock profile table. Passwords are handled by the authentication provider and are not stored by PageClock in application tables.

## 3. Optional diagnostics and sharing
Product analytics, crash diagnostics, cloud sync and device activity tracking are not enabled. PageClock does not upload personal reading notes or detailed session history to the admin dashboard. Any future collection must be separately described, purpose-limited and controlled through explicit consent before activation.

## 4. Access, export and deletion
- Local reading data can be exported using the in-app export features and deleted using Settings → Delete All Data.
- When online account services are deployed, signed-in users can request deletion of their account from the account screen. This deletes the authentication account and associated server-side account metadata; it does not delete local reading data on the device.
- Administrative access is restricted by database roles and row-level security. Admins can see account email, display name and registration date, not personal reading notes or session history.

## 5. Third-party service
When optional online accounts are enabled, authentication and account metadata are processed by Supabase. See https://supabase.com/privacy. The Supabase service-role key is used only by the server-side account-deletion function and is never included in the client application.

## 6. Permissions
PageClock requests only the minimum permissions required for core features:
- **Foreground service / notifications (Android):** to display an ongoing timer and keep timing accurate while the app is in the background.

## 7. Contact
For privacy questions or account deletion support:
- **Developer:** Koushik
- **Email:** koushik4475@gmail.com
