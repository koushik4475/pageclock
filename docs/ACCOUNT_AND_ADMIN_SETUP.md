# PageClock account and admin setup

PageClock remains fully usable offline without registration. Reading sessions, notes and personal reports are never uploaded by the account feature.

## 1. Create and configure Supabase

1. Create a Supabase project.
2. Apply migrations in order:
   - `supabase/migrations/202611100001_pageclock_accounts_admin.sql`
   - `supabase/migrations/202611100002_account_privacy_hardening.sql`
3. Enable email/password authentication and email verification.
4. Configure the production Site URL and allowed redirect URLs in Authentication → URL Configuration.
5. Configure SMTP for production email delivery; do not rely on the default test email service for public users.
6. Build the app using the project URL and public publishable/anon key:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_PUBLISHABLE_OR_ANON_KEY
```

A backend initialization failure is fail-soft: the app continues in offline mode.

## 2. Bootstrap the first administrator

1. Create and verify the owner's account in PageClock.
2. In Supabase Authentication → Users, copy the owner's UUID.
3. In the SQL editor, run:

```sql
insert into public.admin_roles(user_id, role)
values ('YOUR_AUTH_USER_UUID', 'super_admin');
```

Never let a public client assign administrator roles. The app's RLS policies prevent users from self-promoting.

## 3. Deploy secure account deletion

The app calls a server-side Edge Function. Deploy it from the repository root:

```bash
supabase functions deploy delete-account
```

Configure these Edge Function secrets using the Supabase dashboard or CLI:

```bash
supabase secrets set SUPABASE_URL=https://YOUR_PROJECT.supabase.co
supabase secrets set SUPABASE_ANON_KEY=YOUR_PUBLIC_ANON_KEY
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=YOUR_SERVICE_ROLE_KEY
```

The service-role key belongs only in Supabase Edge Function secrets. Never put it in Flutter defines, web assets, source control or a browser.

The function validates the caller's access token and deletes only that authenticated user's account. Local reading data is not deleted.

## 4. Password recovery

Configure the Supabase email templates and redirect URLs for the app's supported deep link / web callback before enabling public registration. After a recovery link establishes a valid session, the account screen's **Set a new password** action calls Supabase Auth to update the password. Test the full email-to-app flow on each production platform.

## 5. Admin directory and privacy

The admin screen provides a paginated directory with search by email and shows only email, display name and registration date. Access is restricted by the database administrator role and row-level security. It does not expose reading notes, session history, precise location, behavioural analytics or device activity.

Consent records are append-only. A withdrawal must be recorded as a new row with `granted = false`; existing consent history cannot be edited or deleted by the client.

## 6. Before public launch

This repository supplies the app UI, SQL migrations and Edge Function source. It does not create your Supabase project, configure your SMTP sender/domain, set production redirect/deep-link domains, provision the first administrator or deploy hosting. Complete and verify those owner-controlled steps, then test signup, verification, sign-in, password recovery, account deletion, non-admin denial and admin-only directory access in a staging project before public registration.
