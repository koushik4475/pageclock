create sequence if not exists public.reading_sessions_server_seq;

create table public.reading_sessions (
  user_id          uuid    not null references auth.users(id) on delete cascade,
  id               text    not null,
  started_at_utc   bigint  not null,
  ended_at_utc     bigint  not null,              -- only completed sessions sync
  paused_total_ms  bigint  not null default 0,
  pause_intervals  jsonb   not null default '[]'::jsonb,
  duration_ms      bigint  not null default 0,
  tz_offset_min    integer not null default 0,
  subject_id       text,
  note             text,
  source           text    not null default 'timer',
  device_id        text    not null default 'local',
  created_at_ms    bigint  not null,
  updated_at_ms    bigint  not null,
  deleted_at_ms    bigint,
  server_seq       bigint  not null default nextval('public.reading_sessions_server_seq'),
  primary key (user_id, id),
  -- structural / abuse limits only (no business-rule checks: they create poison-pill rows)
  constraint rs_id_fmt   check (id ~ '^[A-Za-z0-9_-]{1,64}$'),
  constraint rs_pause    check (jsonb_typeof(pause_intervals) = 'array' and jsonb_array_length(pause_intervals) <= 500),
  constraint rs_len      check (coalesce(char_length(note),0) <= 2000
                            and coalesce(char_length(subject_id),0) <= 200
                            and char_length(source) <= 32 and char_length(device_id) <= 100)
);

create index reading_sessions_pull_idx on public.reading_sessions (user_id, server_seq);

alter table public.reading_sessions enable row level security;

create policy rs_select on public.reading_sessions for select to authenticated
  using ((select auth.uid()) = user_id);
create policy rs_insert on public.reading_sessions for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy rs_update on public.reading_sessions for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
-- deliberately NO delete policy: deletion is a tombstone; account deletion cascades from auth.users

revoke all on public.reading_sessions from public, anon, authenticated;
grant select, insert, update on public.reading_sessions to authenticated;
grant usage on sequence public.reading_sessions_server_seq to authenticated;

create or replace function public.reading_sessions_guard() returns trigger
language plpgsql security invoker set search_path = '' as $$
declare
  now_ms bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  n bigint;
begin
  if tg_op = 'INSERT' then
    -- cap only genuinely new rows (an upsert that will become an UPDATE must not be blocked at the cap)
    if not exists (select 1 from public.reading_sessions where user_id = new.user_id and id = new.id) then
      select count(*) into n from (select 1 from public.reading_sessions where user_id = new.user_id limit 20000) s;
      if n >= 20000 then raise exception 'reading_sessions_user_cap' using errcode = 'P0001'; end if;
    end if;
  else
    if new.user_id <> old.user_id then raise exception 'user_id is immutable'; end if;
    -- server-side LWW: stale or equal writes are ignored, except a tombstone beating a live row at equal time
    if new.updated_at_ms < old.updated_at_ms then return old; end if;
    if new.updated_at_ms = old.updated_at_ms
       and not (new.deleted_at_ms is not null and old.deleted_at_ms is null) then return old; end if;
  end if;
  if new.updated_at_ms > now_ms + 86400000 then raise exception 'updated_at_ms_in_future'; end if;
  if new.deleted_at_ms is not null then new.note := null; end if;
  new.server_seq := nextval('public.reading_sessions_server_seq');
  return new;
end $$;

create trigger reading_sessions_guard before insert or update on public.reading_sessions
  for each row execute function public.reading_sessions_guard();
