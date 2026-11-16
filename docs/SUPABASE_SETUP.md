# PageClock Supabase & Infrastructure Setup Guide

This document specifies the exact configuration required for the human operator to provision and configure Supabase, Resend, and Google OAuth for PageClock Web Cloud Sync.

> [!IMPORTANT]
> The automated agent cannot perform cloud provisioning, DNS modifications, or credential creation. Follow this guide step-by-step. Never commit private credentials or secrets to this repository.

---

## 1. Prerequisites & Gates (Human Tasks H1–H4)

| Gate | Requirement | Notes |
|---|---|---|
| **H1** | **Domain Ownership & DNS** | Required for Resend email OTP. `pageclock.pages.dev` cannot be verified for SPF/DKIM. If you do not yet own a custom domain, ship Google OAuth first and activate email OTP later. |
| **H2** | **Two Supabase Projects** | Create `pageclock-staging` and `pageclock-prod` under your Supabase organization (Supabase Free tier allows 2 active projects). |
| **H3** | **Google Cloud Web OAuth Client** | Create OAuth 2.0 Web Client IDs for staging and prod in Google Cloud Console. |
| **H4** | **Deployment Strategy** | GitHub Variables `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` configured in repository settings. |

---

## 2. Project Provisioning (H2)

1. Log in to the [Supabase Dashboard](https://supabase.com/dashboard).
2. Create Project 1:
   - **Name:** `pageclock-staging`
   - **Database Password:** Store securely in your password manager.
   - **Region:** Choose closest to your primary user base (e.g., `us-east-1` or `eu-west-1`).
3. Create Project 2:
   - **Name:** `pageclock-prod`
   - **Database Password:** Store securely in your password manager.
   - **Region:** Same as staging.

> [!WARNING]
> Supabase Free tier projects automatically pause after 7 consecutive days of inactivity and do not include automated daily backups. Ensure staging and production monitoring.

---

## 3. Database Schema & Migration Deployment

Apply the schema migration located at `supabase/migrations/0001_reading_sessions.sql` to **staging first**, verify with pgTAP tests, and then apply to **production**.

### Option A: Via Supabase CLI
```bash
# Link to your staging project
supabase link --project-ref <staging-project-ref>
supabase db push

# Run database tests (if Docker is available)
supabase test db
```

### Option B: Via Supabase Web Dashboard SQL Editor
1. Open **SQL Editor** in the Supabase Dashboard.
2. Paste the contents of `supabase/migrations/0001_reading_sessions.sql`.
3. Click **Run**.
4. Confirm tables and sequences:
   - Table `public.reading_sessions` created with RLS enabled.
   - Sequence `public.reading_sessions_server_seq` created.
   - Policies `rs_select`, `rs_insert`, and `rs_update` active.
   - Trigger `reading_sessions_guard` attached.

---

## 4. Authentication Configuration (H5)

Navigate to **Authentication > Configuration** in the Supabase Dashboard for each project.

### 4.1 URL Configuration
- **Production (`pageclock-prod`):**
  - **Site URL:** `https://pageclock.pages.dev`
  - **Redirect URLs (Allow list):**
    ```text
    https://pageclock.pages.dev/**
    ```
    *(Strict allow-list. Do NOT allow broad wildcard domains in production).*
- **Staging (`pageclock-staging`):**
  - **Site URL:** `https://<staging-alias>.pages.dev` (or local test URL)
  - **Redirect URLs (Allow list):**
    ```text
    https://<staging-alias>.pages.dev/**
    http://localhost:*/**
    ```

### 4.2 Email Provider & OTP Configuration
Navigate to **Authentication > Providers > Email**:
- **Enable Email Provider:** ON
- **Confirm Email:** OFF (we use passwordless 6-digit OTP codes)
- **OTP Expiry:** `600` seconds (10 minutes)
- **OTP Length:** `6` digits

### 4.3 Custom SMTP Configuration (Resend)
Navigate to **Authentication > SMTP Settings**:
- **Sender Email:** `auth@yourdomain.com` (Must be verified in Resend)
- **Sender Name:** `PageClock`
- **Host:** `smtp.resend.com`
- **Port:** `465` (SSL) or `587` (TLS)
- **Username:** `resend`
- **Password:** `<YOUR_RESEND_API_KEY>`

> [!IMPORTANT]
> **Auth Rate Limits:** Resend Free tier permits **100 emails/day** (3,000 emails/month). Set email rate limits in Supabase accordingly:
> - Max Rate Limit: Low threshold to prevent quota exhaustion DoS.
> - Rate Limit Interval: 60 seconds minimum between resend requests.

### 4.4 Email Template Customization
Navigate to **Authentication > Email Templates > Magic Link / Confirmation**:
- Replace email body with pure token verification (prevents email scanner bots from pre-clicking and burning confirmation URLs):
```html
<h2>Your PageClock Verification Code</h2>
<p>Enter the following 6-digit code to sign in to your PageClock account:</p>
<h1 style="font-size: 32px; letter-spacing: 4px; font-family: monospace;">{{ .Token }}</h1>
<p>This code will expire in 10 minutes. If you did not request this code, you can safely ignore this email.</p>
```
> [!CAUTION]
> Do NOT include `{{ .ConfirmationURL }}` in the email template. Antivirus software and enterprise mail scanners pre-fetch links, burning one-time tokens before the user can click them.

---

## 5. Google OAuth Provider Setup (H3)

### 5.1 Google Cloud Console Configuration
1. Go to the [Google Cloud Console](https://console.cloud.google.com/).
2. Create or select a Google Cloud Project (e.g., `pageclock-auth`).
3. Configure the **OAuth Consent Screen**:
   - User Type: **External**
   - Publishing Status: **In production** *(Testing mode caps at 100 test users and expires refresh tokens after 7 days)*
   - Scopes: `.../auth/userinfo.email`, `.../auth/userinfo.profile`, `openid`
4. Create **Credentials > OAuth Client ID**:
   - Application Type: **Web application**
   - Authorized JavaScript origins:
     - `https://pageclock.pages.dev` (for prod)
     - `https://<staging-alias>.pages.dev` and `http://localhost` (for staging)
   - Authorized redirect URIs:
     - Production: `https://<prod-project-ref>.supabase.co/auth/v1/callback`
     - Staging: `https://<staging-project-ref>.supabase.co/auth/v1/callback`

### 5.2 Supabase Google Provider
1. In Supabase Dashboard, go to **Authentication > Providers > Google**.
2. Toggle **Enable Google provider** to ON.
3. Paste **Client ID** and **Client Secret** obtained from Google Cloud Console.
4. Save changes.

---

## 6. Edge Function Deployment (`delete-account`)

The `delete-account` edge function enables compliant user deletion under GDPR/privacy policies.

1. Install Supabase CLI locally if not already installed:
   ```bash
   npm install -g supabase
   ```
2. Deploy the function:
   ```bash
   supabase functions deploy delete-account --project-ref <project-ref>
   ```
3. Set Function Environment Secrets:
   ```bash
   # Production origin only in production
   supabase secrets set ALLOWED_ORIGINS="https://pageclock.pages.dev" --project-ref <prod-project-ref>

   # Staging origin + localhost in staging
   supabase secrets set ALLOWED_ORIGINS="https://<staging-alias>.pages.dev,http://localhost:5000" --project-ref <staging-project-ref>
   ```
4. Verify `verify_jwt = true` is respected (enforced in `supabase/config.toml`).

---

## 7. GitHub Repository Variables (H4)

In your GitHub repository settings under **Settings > Secrets and variables > Actions > Variables** (NOT Secrets, as these are public values in client builds):

| Variable Name | Staging Value | Production Value |
|---|---|---|
| `SUPABASE_URL` | `https://<staging-ref>.supabase.co` | `https://<prod-ref>.supabase.co` |
| `SUPABASE_PUBLISHABLE_KEY` | `<staging-anon-key>` | `<prod-anon-key>` |

> [!CAUTION]
> NEVER input or expose `SUPABASE_SERVICE_ROLE_KEY` in GitHub Variables, repository files, or `--dart-define` parameters. The service role key is strictly server-side and automatically injected by Supabase Edge Functions.

---

## 8. Verification Checklist

Before enabling `PAGECLOCK_CLOUD_AUTH_ENABLED=true` in production:

- [ ] Staging schema migration applied cleanly.
- [ ] Email OTP delivered and tested in Gmail, Outlook, and iCloud/Yahoo.
- [ ] OTP expired code (>10 min) rejected gracefully.
- [ ] Invalid OTP code rejected gracefully.
- [ ] Google OAuth login redirects and completes cleanly via PKCE.
- [ ] Account deletion function invokes, cascades row deletion, and removes auth user.
- [ ] Zero secrets present in compiled web artifacts or git history.
