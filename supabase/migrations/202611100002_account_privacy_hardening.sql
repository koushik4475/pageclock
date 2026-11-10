-- Harden account metadata access and make consent history append-only.
alter table public.profiles add column if not exists email text;
update public.profiles p set email = u.email from auth.users u where u.id = p.id and p.email is distinct from u.email;

create or replace function public.handle_new_pageclock_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles(id, display_name, email)
  values (
    new.id,
    nullif(new.raw_user_meta_data ->> 'display_name', ''),
    new.email
  )
  on conflict (id) do update
    set email = excluded.email,
        display_name = coalesce(public.profiles.display_name, excluded.display_name);
  return new;
end;
$$;

create or replace function public.sync_pageclock_profile_email()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.profiles set email = new.email where id = new.id;
  return new;
end;
$$;

drop trigger if exists on_pageclock_auth_email_updated on auth.users;
create trigger on_pageclock_auth_email_updated
after update of email on auth.users
for each row execute procedure public.sync_pageclock_profile_email();

-- Users may edit their display name, but cannot forge the email shown to admins.
revoke update on public.profiles from authenticated;
grant update (display_name) on public.profiles to authenticated;

-- Consent is an append-only audit trail. Revocation is a new row with granted=false.
drop policy if exists "Manage own consent" on public.consent_records;
drop policy if exists "Read own consent" on public.consent_records;
drop policy if exists "Insert own consent" on public.consent_records;
create policy "Read own consent" on public.consent_records
  for select to authenticated using (user_id = (select auth.uid()));
create policy "Insert own consent" on public.consent_records
  for insert to authenticated with check (user_id = (select auth.uid()));
revoke update, delete on public.consent_records from authenticated;
grant select, insert on public.consent_records to authenticated;

-- The admin directory is restricted by the existing admin-only profile RLS policy.
