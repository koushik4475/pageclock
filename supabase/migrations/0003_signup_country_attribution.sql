-- PageClock country-only signup attribution.
-- DB-IP Lite CIDR ranges are imported locally; no raw client IP is persisted.
create table if not exists public.ip_country_ranges (
  network cidr primary key,
  country_code text not null check (country_code ~ '^[A-Z]{2}$'),
  country_name text not null,
  source_version text not null,
  updated_at timestamptz not null default now()
);

create index if not exists ip_country_ranges_network_gist
  on public.ip_country_ranges using gist (network inet_ops);

alter table public.ip_country_ranges enable row level security;
revoke all on public.ip_country_ranges from public, anon, authenticated;
grant select on public.ip_country_ranges to service_role;

create table if not exists public.signup_country_capture (
  user_id uuid primary key,
  country_code text not null check (country_code ~ '^[A-Z]{2}$'),
  country_name text not null,
  detected_at timestamptz not null default now(),
  source text not null default 'dbip-lite-local'
    check (source = 'dbip-lite-local')
);

alter table public.signup_country_capture enable row level security;
revoke all on public.signup_country_capture from public, anon, authenticated;
grant select, insert, update, delete on public.signup_country_capture to service_role;

comment on table public.ip_country_ranges is
  'Locally imported DB-IP Lite country CIDR ranges. No per-request external geolocation lookup.';
comment on table public.signup_country_capture is
  'Country-only signup attribution. Raw IP addresses are never stored. Rows are written by the Supabase Auth Before User Created hook.';

create or replace function public.pageclock_before_user_created(event jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  signup_ip inet;
  signup_user_id uuid;
  detected_code text;
  detected_name text;
begin
  signup_user_id := nullif(event->'user'->>'id', '')::uuid;
  signup_ip := nullif(event->'metadata'->>'ip_address', '')::inet;

  if signup_user_id is null or signup_ip is null then
    return '{}'::jsonb;
  end if;

  select country_code, country_name
    into detected_code, detected_name
    from public.ip_country_ranges
   where signup_ip <<= network
   order by masklen(network) desc
   limit 1;

  if detected_code is null then
    return '{}'::jsonb;
  end if;

  insert into public.signup_country_capture
    (user_id, country_code, country_name, detected_at, source)
  values
    (signup_user_id, detected_code, detected_name, now(), 'dbip-lite-local')
  on conflict (user_id) do update
    set country_code = excluded.country_code,
        country_name = excluded.country_name,
        detected_at = excluded.detected_at,
        source = excluded.source;

  return '{}'::jsonb;
exception
  when invalid_text_representation or invalid_parameter_value then
    -- Invalid/missing IP or user identifier must never block signup.
    return '{}'::jsonb;
end;
$$;

revoke all on function public.pageclock_before_user_created(jsonb)
  from public, anon, authenticated;
grant execute on function public.pageclock_before_user_created(jsonb)
  to supabase_auth_admin;

-- Supabase Auth invokes the hook as supabase_auth_admin.
grant select on public.ip_country_ranges to supabase_auth_admin;
grant insert, update on public.signup_country_capture to supabase_auth_admin;
