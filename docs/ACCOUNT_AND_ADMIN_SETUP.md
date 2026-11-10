# PageClock account and admin setup

Registration is optional. PageClock remains usable without signing in. The app does not upload local Drift reading sessions.

## Configure Supabase
1. Create a Supabase project and apply `supabase/migrations/202611100001_pageclock_accounts_admin.sql`.
2. Enable email/password authentication and email verification.
3. Configure allowed redirect URLs for development and production.
4. Create the owner's account through PageClock and verify its email.
5. Find the owner's UUID in Supabase Authentication → Users and run the bootstrap SQL at the bottom of the migration with role `super_admin`.
6. Build with:
```bash
flutter run --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLIC_ANON_KEY
```

The public anon/publishable key is for client use. Never expose a service-role key in Flutter, web assets, source control, or build defines. RLS is the security boundary; public users cannot grant themselves administrator roles.

The first admin dashboard shows account count only. Reading notes, session history, precise location and behavioural monitoring are deliberately excluded.

This repository change does not create a Supabase project, configure production email, set DNS, deploy hosting, or grant the initial admin role. Those require the project owner's Supabase account and production domain. Until configured, the app shows an offline-safe notice.
