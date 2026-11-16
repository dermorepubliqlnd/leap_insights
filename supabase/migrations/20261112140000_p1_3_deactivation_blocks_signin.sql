-- 20261112140000_p1_3_deactivation_blocks_signin
-- What:  Fix 1.3 — switching a user's "Active Account" off in User Management now really blocks sign-in.
--        (a) Trigger trg_profiles_signin_sync → function profiles_signin_sync(): when profiles.is_active
--            changes, the matching sign-in account (auth.users) is banned (deactivated) or unbanned
--            (reactivated), and the person's open sessions are ended. Covers password AND Microsoft sign-in.
--        (b) is_admin() / is_reports_viewer() return false for a deactivated person.
--        Both are PREVIEW-GATED: they only apply to requests from the Preview site (x-app-channel: preview).
-- Why:   Assessment 02 / Revision 1: deactivation only flagged the profile; the account could still sign in.
-- Date:  2026-11-12 · Approved by: Sandra Barlao ("ok" to start 1.3 on Preview)
-- Design note: done in the database (no Edge Function or app change). Fix 1.7 (admin password resets)
--        deferred — only one admin exists, so the risk it closes does not exist yet.
-- Rollback: supabase/rollback/20261112140000_p1_3_deactivation_blocks_signin_ROLLBACK.sql
-- Release: re-create both helper functions + profiles_signin_sync without the is_preview_request() test.

create or replace function public.profiles_signin_sync()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
  if not public.is_preview_request() then
    return new;
  end if;
  if new.is_active is distinct from old.is_active then
    if new.is_active then
      update auth.users set banned_until = null where id = new.id;
    else
      update auth.users set banned_until = now() + interval '100 years' where id = new.id;
      delete from auth.sessions where user_id = new.id;
    end if;
  end if;
  return new;
end;
$function$;

revoke all on function public.profiles_signin_sync() from public, anon, authenticated;

drop trigger if exists trg_profiles_signin_sync on public.profiles;
create trigger trg_profiles_signin_sync
  after update of is_active on public.profiles
  for each row execute function public.profiles_signin_sync();

create or replace function public.is_admin()
returns boolean
language sql
stable
set search_path to ''
as $function$
  select coalesce((select p.is_admin and (p.is_active or not public.is_preview_request())
                     from public.profiles p where p.id = auth.uid()), false);
$function$;

create or replace function public.is_reports_viewer()
returns boolean
language sql
stable
set search_path to ''
as $function$
  select coalesce((select p.is_reports_viewer and (p.is_active or not public.is_preview_request())
                     from public.profiles p where p.id = auth.uid()), false);
$function$;

-- Record:
-- insert into supabase_migrations.schema_migrations (version, name)
--   values ('20261112140000', 'p1_3_deactivation_blocks_signin');
