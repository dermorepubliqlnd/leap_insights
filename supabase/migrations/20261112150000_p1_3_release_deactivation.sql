-- 20261112150000_p1_3_release_deactivation
-- What:  RELEASE to Live of Fix 1.3. Re-creates profiles_signin_sync(), is_admin(), is_reports_viewer()
--        WITHOUT the preview-only gate, so deactivating a user blocks sign-in on Live too and a
--        deactivated admin / Reports Viewer loses those powers everywhere.
--        One-time: blocks sign-in for profiles that were ALREADY inactive before this fix (1 account,
--        Redrico, verified 12 Nov) and ends their open sessions.
-- Why:   Validated on Preview 12 Nov: dry run 8/8 + real app test (deactivate → banned, reactivate → unbanned).
-- Date:  2026-11-12 · Approved by: Sandra Barlao ("ok" to release 1.3 to Live)
-- Rollback: supabase/rollback/20261112150000_p1_3_release_deactivation_ROLLBACK.sql

create or replace function public.profiles_signin_sync()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
begin
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

create or replace function public.is_admin()
returns boolean language sql stable set search_path to ''
as $function$
  select coalesce((select p.is_admin and p.is_active from public.profiles p where p.id = auth.uid()), false);
$function$;

create or replace function public.is_reports_viewer()
returns boolean language sql stable set search_path to ''
as $function$
  select coalesce((select p.is_reports_viewer and p.is_active from public.profiles p where p.id = auth.uid()), false);
$function$;

-- One-time: lock accounts that were already inactive.
update auth.users u set banned_until = now() + interval '100 years'
  from public.profiles p
 where p.id = u.id and not p.is_active and u.banned_until is null;
delete from auth.sessions s using public.profiles p where p.id = s.user_id and not p.is_active;

-- Record:
-- insert into supabase_migrations.schema_migrations (version, name)
--   values ('20261112150000', 'p1_3_release_deactivation');
