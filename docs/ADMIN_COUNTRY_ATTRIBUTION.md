# PageClock signup country attribution

PageClock records the **country inferred at signup**, not nationality or a live/current location.
The raw IP is supplied transiently by Supabase Auth's Before User Created hook, matched against
a locally imported DB-IP Lite country range table, and is never persisted by PageClock.

## One-time setup

1. Apply migration `supabase/migrations/0003_signup_country_attribution.sql`.
2. Download the DB-IP Lite Country CSV from https://db-ip.com/db/download/ip-to-country-lite.
3. Install `scripts/geoip-requirements.txt` and run
   `DATABASE_URL='...' python scripts/import_dbip_country.py /path/to/dbip-country-lite.csv`.
   Use a secure direct/session-pooler database connection; do not commit credentials.
4. Validate known IPv4 and IPv6 addresses against `public.ip_country_ranges`.
5. In Supabase Dashboard → Authentication → Hooks, enable **Before User Created** and select
   `public.pageclock_before_user_created(event jsonb)`.
6. Create a test account and verify a row appears in `public.signup_country_capture`.
7. Verify the admin dashboard shows country code/name and that unknown/private IPs remain
   unclassified without blocking signup.

## Data source and refresh

DB-IP Lite country CSV is licensed under CC BY 4.0. Retain attribution to DB-IP and follow the
current license terms: https://db-ip.com/db/lite.php. Refresh the local range table monthly (or
when DB-IP publishes an update) using the latest CSV. The importer replaces the table in one transaction (the previous dataset is retained if the import fails); schedule it during a low-traffic window and validate before enabling the hook against a newly loaded dataset.

No MaxMind account, API key, geolocation API call, Cloudflare proxy, or new Edge Function secret
is required. The external setup is the Supabase Auth Hook toggle plus a database connection for
the one-time import and periodic refresh.

## Operational notes

- This is approximate IP geolocation. VPNs, proxies, mobile carriers, and privacy relays can
  produce incorrect or unknown countries.
- Country detection is optional and fail-open: signup must continue if the IP is missing, invalid,
  or not present in the local database.
- No city, region, coordinates, or raw IP are stored.
- The hook runs before the Auth user row is created, so it records a user UUID without a foreign
  key. Review and clean up orphaned captures periodically.
- Existing accounts are not backfilled. Only signups after the hook is enabled are attributed.
- DB-IP Lite attribution is required. The admin country panel displays a clickable “IP Geolocation by DB-IP” link as required for web applications. See the license link above.
