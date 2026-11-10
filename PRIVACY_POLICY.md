# Privacy Policy for PageClock

**Last updated:** November 10, 2026

PageClock is an offline-first reading focus tracker. Core timer, calendar, reports, notes and reading-session features work without an account. Optional account features are inactive until a user chooses to register and the operator configures the backend.

## 1. Local data by default
- Reading sessions, subjects, notes and detailed personal metrics are stored locally on your device using SQLite (or the platform's local web storage).
- Signing in does not upload reading history, notes or session details.
- You can continue using PageClock without registering or signing in.
- Exported backups and reports remain under your control.

## 2. Optional account information
If you choose to create an account after online account services are enabled, PageClock's authentication provider processes your email address, authentication credentials and optional display name to create and secure your account. Passwords are handled by the authentication provider and are not stored by PageClock in application tables.

The account service may store your account ID, account creation date, profile name and administrator role metadata. Account registration is optional and is not required for core offline functionality.

## 3. Optional diagnostics and sharing
Product analytics, crash diagnostics, cloud sync and device activity tracking are not enabled by this initial account implementation. Any future optional collection must be separately described, purpose-limited and controlled through an explicit consent choice before activation. PageClock does not upload personal reading notes or detailed session history to the admin dashboard.

## 4. Data access, export and deletion
- You can continue to export your local data using the in-app export features.
- You can delete local records using Settings → Delete All Data.
- Account deletion will be supported through the account service before public account launch; until then, contact the developer to request account deletion.
- Administrative access is restricted by database roles and row-level security. Admins can see account metadata needed to operate the service, not personal reading notes or session history.

## 5. Third-party service
When optional online accounts are enabled, authentication and account metadata are processed by Supabase. The service's privacy and security documentation is available at https://supabase.com/privacy. No Supabase service-role key is included in the client application.

## 6. Permissions
PageClock requests only the minimum permissions required for core features:
- **Foreground service / notifications (Android):** to display an ongoing timer and keep timing accurate while the app is in the background.

## 7. Contact
For privacy questions or account deletion requests:
- **Developer:** Koushik
- **Email:** koushik4475@gmail.com
