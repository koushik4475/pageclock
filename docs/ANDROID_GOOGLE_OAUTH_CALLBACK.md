# Android Google OAuth callback setup

PageClock uses Supabase PKCE OAuth on Android and returns to the installed app through this callback:

```text
com.example.pageclock://login-callback/
```

## Supabase dashboard requirement

In the **production Supabase project** (`xmtmubuoooctkxenwrqs`), open **Authentication → URL Configuration → Redirect URLs** and add this exact URL:

```text
com.example.pageclock://login-callback/
```

The callback must be in the Additional Redirect URLs allowlist. If it is absent, Supabase can fall back to the configured Site URL, which sends the user back to the website instead of the Android app.

Keep the Google provider's authorized OAuth redirect URI pointed at the Supabase Auth callback:

```text
https://xmtmubuoooctkxenwrqs.supabase.co/auth/v1/callback
```

That Google Console URI is different from the app deep link above.

## Android app configuration

The Android manifest registers the matching scheme and host on the exported MainActivity. The Supabase Flutter SDK receives the incoming deep link and completes the pending PKCE exchange; do not manually exchange the code a second time.

Google OAuth is launched in the external browser. After Google and Supabase finish, Android should open PageClock via the registered custom scheme, and the existing auth-state listener restores the account scope.

## Verification checklist

- [ ] The callback URL is present in the production Supabase Redirect URLs allowlist.
- [ ] Google provider remains enabled and its authorized redirect URI is the Supabase Auth callback above.
- [ ] Android package ID remains `com.example.pageclock`.
- [ ] A signed production APK opens Google in Chrome, then returns to PageClock.
- [ ] PageClock shows the authenticated account without showing the website login page.
- [ ] Force-close and relaunch PageClock; the Supabase session remains restored.

A CI build cannot verify the live Supabase allowlist or a physical Chrome-to-APK handoff. Record the final device test separately before claiming the production login issue is resolved.
