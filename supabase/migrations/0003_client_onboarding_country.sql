-- Store only coarse country-level onboarding attribution. Never persist client IP addresses.
create table if not exists public.client_onboarding (
  user_id uuid primary key references auth.users(id) on delete cascade,
  country_code text,
  country_name text,
  detected_at timestamptz not null default now(),
  detection_source text not null default 'ip_geolocation',
  constraint client_onboarding_country_code check (country_code is null or country_code ~ '^[A-Z]{2}$'),
  constraint client_onboarding_country_name check (country_name is null or char_length(country_name) <= 100)
);
alter table public.client_onboarding enable row level security;
revoke all on public.client_onboarding from public, anon, authenticated;
grant select, insert, update, delete on public.client_onboarding to service_role;
comment on table public.client_onboarding is
  'First observed PageClock authenticated app session country. Country only; raw IP addresses are never stored.';
