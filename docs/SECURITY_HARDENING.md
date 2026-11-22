# PageClock Security Hardening Checklist

This checklist complements automated tests. Repository code changes cannot enable GitHub account/repository settings or rotate credentials.

## Repository-owner settings (manual, GitHub UI)

- [ ] Enable private vulnerability reporting / Security Advisories.
- [ ] Enable secret scanning and push protection (where available for this repository/plan).
- [ ] Enable Dependabot alerts and security updates.
- [ ] Protect `main`: require PRs, at least one approval where feasible, dismiss stale approvals, require status checks, block force pushes and branch deletion, and restrict bypasses.
- [ ] Ensure release workflow secrets are only available to trusted pushes on `main`; never to PR builds, forks, or untrusted workflow dispatch inputs.
- [ ] Review repository collaborators, deploy keys, OAuth apps, GitHub Actions permissions and Supabase project access quarterly; remove unused access.
- [ ] Rotate credentials immediately after suspected exposure; revoke first, then replace.

## CI/CD

- [ ] Pin all third-party GitHub Actions to full commit SHAs and periodically update them.
- [ ] Keep workflow permissions minimal per job; avoid write permissions except in the publishing job.
- [ ] Protect publishing from PR events and untrusted inputs.
- [ ] Keep signing credentials in GitHub Actions secrets, never repository files or build artifacts.
- [ ] Verify release checksum and signing certificate continuity before distributing an APK.

## Application and backend

- [ ] Keep Supabase service-role credentials server-only; Flutter client must use publishable key.
- [ ] Audit every exposed table for RLS, grants, and least-privilege policies.
- [ ] Review Edge Functions for authorization checks, input validation, abuse/rate controls, and sensitive logging.
- [ ] Do not trust user-editable metadata for authorization.
- [ ] Review data export/import, OAuth callback handling, and updater URL/hash validation.
- [ ] Run dependency vulnerability checks and review dependency update PRs.

## Verification notes

Repository files can document or automate portions of this checklist, but settings and secret inventory require owner-side verification. Do not mark items complete without evidence.
