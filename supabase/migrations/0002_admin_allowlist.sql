-- PageClock Admin Command Center: private single-owner admin allowlist.
create table if not exists public.admin_allowlist (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.admin_allowlist enable row level security;
revoke all on public.admin_allowlist from public, anon, authenticated;
grant select, insert, update, delete on public.admin_allowlist to service_role;

comment on table public.admin_allowlist is
  'Server-managed PageClock administrator allowlist. Never expose through the client Data API.';
