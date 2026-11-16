begin;
create extension if not exists pgtap;

select plan(20);

-- ============================================================================
-- Setup Test Fixtures & Users
-- ============================================================================
insert into auth.users (id, email)
values
  ('11111111-1111-1111-1111-111111111111'::uuid, 'user_a@pageclock.test'),
  ('22222222-2222-2222-2222-222222222222'::uuid, 'user_b@pageclock.test'),
  ('33333333-3333-3333-3333-333333333333'::uuid, 'user_c@pageclock.test')
on conflict (id) do nothing;

-- ============================================================================
-- 1. Anonymous Role Lockout (anon role has 0 access)
-- ============================================================================
set local role anon;
set local "request.jwt.claims" to '{}';

select throws_ok(
  $$ select * from public.reading_sessions $$,
  '42501',
  null,
  'anon role cannot select from reading_sessions'
);

select throws_ok(
  $$ insert into public.reading_sessions (user_id, id, started_at_utc, ended_at_utc, created_at_ms, updated_at_ms)
     values ('11111111-1111-1111-1111-111111111111'::uuid, 'anon_row', 1700000000000, 1700001000000, 1700000000000, 1700001000000) $$,
  '42501',
  null,
  'anon role cannot insert into reading_sessions'
);

select throws_ok(
  $$ update public.reading_sessions set note = 'hacked' where id = 'anon_row' $$,
  '42501',
  null,
  'anon role cannot update reading_sessions'
);

select throws_ok(
  $$ delete from public.reading_sessions where id = 'anon_row' $$,
  '42501',
  null,
  'anon role cannot delete from reading_sessions'
);

-- ============================================================================
-- 2. Authenticated Role: NO DELETE Allowed (tombstone only)
-- ============================================================================
set local role authenticated;
set local "request.jwt.claims" to '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';

select throws_ok(
  $$ delete from public.reading_sessions where id = 'any_row' $$,
  '42501',
  null,
  'authenticated role has no DELETE permission on reading_sessions'
);

-- ============================================================================
-- 3. Authenticated RLS & Cross-User Isolation
-- ============================================================================
-- User A can insert own row
select lives_ok(
  $$ insert into public.reading_sessions (
       user_id, id, started_at_utc, ended_at_utc, duration_ms, tz_offset_min, note, created_at_ms, updated_at_ms
     ) values (
       '11111111-1111-1111-1111-111111111111'::uuid, 'row_a_1', 1700000000000, 1700001800000, 1800000, 0, 'Original note', 1700000000000, 1700001800000
     ) $$,
  'User A can insert row with own user_id'
);

-- User A cannot insert row under User B's user_id
select throws_ok(
  $$ insert into public.reading_sessions (
       user_id, id, started_at_utc, ended_at_utc, duration_ms, tz_offset_min, created_at_ms, updated_at_ms
     ) values (
       '22222222-2222-2222-2222-222222222222'::uuid, 'row_b_forged', 1700000000000, 1700001800000, 1800000, 0, 1700000000000, 1700001800000
     ) $$,
  '42501',
  null,
  'User A cannot insert row under User B user_id'
);

-- User A can select own row
select results_eq(
  $$ select id from public.reading_sessions where id = 'row_a_1' $$,
  $$ values ('row_a_1') $$,
  'User A can select own row'
);

-- Switch to User B: cannot see or update User A's row
set local "request.jwt.claims" to '{"sub": "22222222-2222-2222-2222-222222222222", "role": "authenticated"}';

select is_empty(
  $$ select * from public.reading_sessions where id = 'row_a_1' $$,
  'User B cannot select User A row'
);

-- User B attempting update on User A's row affects 0 rows
select lives_ok(
  $$ update public.reading_sessions set note = 'tampered' where id = 'row_a_1' $$,
  'User B updating User A row completes cleanly without matching rows'
);

-- Switch back to User A: assert note is not tampered
set local "request.jwt.claims" to '{"sub": "11111111-1111-1111-1111-111111111111", "role": "authenticated"}';
select results_eq(
  $$ select note from public.reading_sessions where id = 'row_a_1' $$,
  $$ values ('Original note') $$,
  'User A row note was not modified by User B'
);

-- User A cannot change user_id on update (immutable check)
select throws_ok(
  $$ update public.reading_sessions
     set user_id = '22222222-2222-2222-2222-222222222222'::uuid
     where id = 'row_a_1' $$,
  'P0001',
  'user_id is immutable',
  'user_id cannot be changed on update'
);

-- ============================================================================
-- 4. server_seq Progression
-- ============================================================================
-- Retrieve initial server_seq
prepare get_seq as
  select server_seq from public.reading_sessions where id = 'row_a_1';

-- Update row with newer timestamp
select lives_ok(
  $$ update public.reading_sessions
     set updated_at_ms = 1700002000000, note = 'Updated note'
     where id = 'row_a_1' $$,
  'User A updates row with newer updated_at_ms'
);

select isnt_empty(
  $$ select 1 from public.reading_sessions where id = 'row_a_1' and server_seq > 1 $$,
  'server_seq advances on successful update'
);

-- ============================================================================
-- 5. LWW and Tombstone Rules
-- ============================================================================
-- Stale update is ignored (updated_at_ms lower than current 1700002000000)
select lives_ok(
  $$ update public.reading_sessions
     set updated_at_ms = 1700001500000, note = 'Stale edit'
     where id = 'row_a_1' $$,
  'Stale update executes without error'
);

select results_eq(
  $$ select note from public.reading_sessions where id = 'row_a_1' $$,
  $$ values ('Updated note') $$,
  'Stale update was ignored by guard trigger'
);

-- Equal-timestamp tombstone beats live row, and tombstone nulls note
select lives_ok(
  $$ update public.reading_sessions
     set updated_at_ms = 1700002000000, deleted_at_ms = 1700002000000, note = 'Should be nulled'
     where id = 'row_a_1' $$,
  'Equal-timestamp tombstone update executes'
);

select results_eq(
  $$ select deleted_at_ms, note from public.reading_sessions where id = 'row_a_1' $$,
  $$ values (1700002000000::bigint, null::text) $$,
  'Equal-timestamp tombstone won and note was nulled'
);

-- Future timestamp (> 24 hours from now) rejected
select throws_ok(
  $$ insert into public.reading_sessions (
       user_id, id, started_at_utc, ended_at_utc, created_at_ms, updated_at_ms
     ) values (
       '11111111-1111-1111-1111-111111111111'::uuid, 'future_row', 1700000000000, 1700001000000, 1700000000000,
       ((extract(epoch from clock_timestamp()) * 1000)::bigint + 100000000)
     ) $$,
  'P0001',
  'updated_at_ms_in_future',
  'Future updated_at_ms is rejected'
);

-- ============================================================================
-- 6. Per-User 20,000 Row Cap & Upsert Safety
-- ============================================================================
-- Switch to superuser to simulate cap condition for user_c
reset role;

-- Populate 20000 rows for user_c directly
insert into public.reading_sessions (
  user_id, id, started_at_utc, ended_at_utc, created_at_ms, updated_at_ms
)
select
  '33333333-3333-3333-3333-333333333333'::uuid,
  'bulk_' || i::text,
  1700000000000,
  1700001000000,
  1700000000000,
  1700001000000
from generate_series(1, 20000) as g(i);

-- Act as user_c
set local role authenticated;
set local "request.jwt.claims" to '{"sub": "33333333-3333-3333-3333-333333333333", "role": "authenticated"}';

-- Inserting 20001st row must raise reading_sessions_user_cap
select throws_ok(
  $$ insert into public.reading_sessions (
       user_id, id, started_at_utc, ended_at_utc, created_at_ms, updated_at_ms
     ) values (
       '33333333-3333-3333-3333-333333333333'::uuid, 'overflow_row', 1700000000000, 1700001000000, 1700000000000, 1700001000000
     ) $$,
  'P0001',
  'reading_sessions_user_cap',
  'Inserting past 20000 rows raises reading_sessions_user_cap'
);

-- Updating an existing row at the cap must succeed
select lives_ok(
  $$ update public.reading_sessions
     set updated_at_ms = 1700002000000, note = 'Updated at cap'
     where id = 'bulk_1' $$,
  'Updating existing row at the cap is not blocked'
);

-- ============================================================================
-- 7. Cascade Deletion on Account Removal
-- ============================================================================
reset role;

delete from auth.users where id = '11111111-1111-1111-1111-111111111111'::uuid;

select is_empty(
  $$ select * from public.reading_sessions where user_id = '11111111-1111-1111-1111-111111111111'::uuid $$,
  'Deleting user from auth.users cascades and removes reading_sessions rows'
);

select * from finish();
rollback;
