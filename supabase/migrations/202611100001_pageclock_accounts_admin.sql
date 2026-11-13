-- PageClock accounts and administrator foundation. Never put service_role keys in client apps.
create table if not exists public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 display_name text, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.admin_roles (
 user_id uuid primary key references auth.users(id) on delete cascade,
 role text not null check (role in ('super_admin','admin','support')), created_at timestamptz not null default now()
);
create table if not exists public.user_devices (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 installation_id uuid not null, platform text not null check (platform in ('android','ios','macos','web','windows','linux','other')),
 app_version text, last_seen_at timestamptz not null default now(), created_at timestamptz not null default now(),
 unique(user_id, installation_id)
);
create table if not exists public.consent_records (
 id bigint generated always as identity primary key, user_id uuid not null references auth.users(id) on delete cascade,
 purpose text not null check (purpose in ('product_analytics','crash_diagnostics','cloud_sync')),
 granted boolean not null, policy_version text not null, recorded_at timestamptz not null default now()
);
create table if not exists public.audit_logs (
 id bigint generated always as identity primary key, actor_id uuid references auth.users(id) on delete set null,
 action text not null, target_user_id uuid references auth.users(id) on delete set null,
 metadata jsonb not null default '{}'::jsonb, created_at timestamptz not null default now()
);
create or replace function public.is_pageclock_admin()
returns boolean language sql stable security definer set search_path = ''
as $$ select exists (select 1 from public.admin_roles where user_id = (select auth.uid()) and role in ('super_admin','admin')); $$;
create or replace function public.handle_new_pageclock_user()
returns trigger language plpgsql security definer set search_path = ''
as $$
begin
 insert into public.profiles(id, display_name) values(new.id, nullif(new.raw_user_meta_data ->> 'display_name','')) on conflict(id) do nothing;
 return new;
end;
$$;
drop trigger if exists on_pageclock_user_created on auth.users;
create trigger on_pageclock_user_created after insert on auth.users for each row execute procedure public.handle_new_pageclock_user();
alter table public.profiles enable row level security;
alter table public.admin_roles enable row level security;
alter table public.user_devices enable row level security;
alter table public.consent_records enable row level security;
alter table public.audit_logs enable row level security;
create policy "Read own profile or admin directory" on public.profiles for select to authenticated using (id = (select auth.uid()) or public.is_pageclock_admin());
create policy "Update own profile" on public.profiles for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));
create policy "Read own role or admin roles" on public.admin_roles for select to authenticated using (user_id = (select auth.uid()) or public.is_pageclock_admin());
create policy "Manage own devices" on public.user_devices for all to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "Manage own consent" on public.consent_records for all to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "Admins read audit logs" on public.audit_logs for select to authenticated using (public.is_pageclock_admin());
grant select, update on public.profiles to authenticated;
grant select on public.admin_roles to authenticated;
grant select, insert, update, delete on public.user_devices to authenticated;
grant select, insert on public.consent_records to authenticated;
grant select on public.audit_logs to authenticated;
grant execute on function public.is_pageclock_admin() to authenticated;
-- After owner creates and verifies account, promote manually in Supabase SQL editor:
-- insert into public.admin_roles(user_id, role) values ('YOUR_AUTH_USER_UUID', 'super_admin');
