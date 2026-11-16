# PageClock Cloud Authentication Setup (Web + Android)

This release enables the existing Supabase Auth and session-sync implementation on Flutter Web and Android. Guest Mode remains available and local-first. iOS and desktop remain local-only for now.

## Production Supabase project

- Project: `pageclock-prod`
- Project ref: `xmtmubuoooctkxenwrqs`
- Project URL: `https://xmtmubuoooctkxenwrqs.supabase.co`
- Client key: the Supabase **publishable** key is compiled into the client. This key is intended for public clients; database access must remain protected by RLS.
- Never put a Supabase secret/service-role key, Google client secret, SMTP password, or database password in Flutter code, Dart defines, Git, or APK assets.

The production `public.reading_sessions` table has RLS enabled. Current policies restrict SELECT/INSERT/UPDATE to rows where `user_id = auth.uid()`. The Supabase security advisor currently reports no security findings.

## 1. Configure Auth redirect URLs

In Supabase Dashboard → Authentication → URL Configuration:

1. Keep the production website origin as the Site URL.
2. Add the production Flutter Web origin to Redirect URLs (use the exact deployed Pages origin).
3. Add this Android callback exactly:

   `com.example.pageclock://login-callback`

The Android manifest now registers this scheme/host pair. Do not change one side without changing the other.

## 2. Enable Google OAuth

In Supabase Dashboard → Authentication → Sign In / Providers → Google:

1. Create or select a Google OAuth 2.0 **Web application** client in Google Cloud Console.
2. Add Supabase's callback URL shown on the provider page as an authorized redirect URI:

   `https://xmtmubuoooctkxenwrqs.supabase.co/auth/v1/callback`

3. Configure the Google client ID and client secret in the Supabase Google provider settings and enable the provider.
4. Save the provider.
5. In Google Cloud Console, add the deployed PageClock web origin to Authorized JavaScript origins if using the web client flow.
6. Test Google login separately on Chrome/Web and the Android APK.

The Google client secret belongs only in Supabase provider settings. It must never be embedded in the app.

## 3. Configure six-digit email OTP

In Supabase Dashboard → Authentication → Email Templates:

- Set the sign-in email template body to include the one-time token, for example:

  `Your PageClock verification code is {{ .Token }}`

- Do not use only `{{ .ConfirmationURL }}` for this numeric-code UI.
- Keep the OTP expiry aligned with the app's 10-minute message.

For reliable production delivery, configure a custom SMTP provider under Authentication → SMTP Settings. Supabase's default email service is rate-limited and intended for limited testing, not dependable public production delivery. Keep SMTP credentials in Supabase only.

## 4. Data isolation and sync behavior

- Guest Android data remains in the existing `pageclock.sqlite`.
- Each signed-in user receives a separate `pageclock_user_<user-id>.sqlite` database.
- Completed guest sessions are queued for the existing explicit Merge / Cloud-only / Not now import choice before account sync.
- Only completed sessions and tombstones sync. Active timers remain local.
- The sync coordinator uses the same Supabase `reading_sessions` table and ownership policies on Web and Android.
- Signing out returns to the guest database; it does not merge another account's local data into guest storage.

## 5. Release and verification checklist

- [ ] Supabase email OTP template sends `{{ .Token }}`.
- [ ] SMTP delivery is configured and a real email code is received.
- [ ] Google provider is enabled with valid Google OAuth credentials.
- [ ] Android callback URL is allowlisted in Supabase.
- [ ] Web OTP login and Google login pass.
- [ ] Android OTP login and Google login pass on a physical device.
- [ ] Android sync is verified by creating a completed session, signing in on a second client, and confirming the session appears only in that account.
- [ ] Guest history remains local until the user explicitly chooses to merge it.
- [ ] Sign-out and account switching do not expose another account's local database.
- [ ] Post-merge production APK, checksum, latest-release endpoint and updater are verified under `AGENTS.md`.

A successful CI build alone does not prove that Google OAuth or email delivery is configured. Do not describe authentication as fully operational until the provider settings and real-device flows above pass.
