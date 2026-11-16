-- 20261112100000_p1_1_last_admin_guard
-- What:  Database-level last-administrator safeguard (Phase 1, fix 1.1).
--        1. No signed-in user may change their OWN admin status or deactivate themselves.
--        2. No change (update or delete, by anyone, including the service role) may leave
--           LEAP with zero active administrators.
-- Why:   Sandra is the only admin; today the "last admin" protection exists only in the
--        User Management screen (DB.adminCount()), so a direct API request could remove it
--        and lock everyone out of administration. Assessment 02 / Revision 1, finding C3.
-- Date:  2026-11-12 · Asked by: Sandra Barlao (Stage B, fix 1.1 approved to build)
-- Scope: Additive. One function + one trigger on public.profiles. No data is changed.
-- Preview first: rules apply ONLY to requests from the Preview build (x-app-channel: preview)
--        until release. RELEASE = re-create the function without the `if not public.is_preview_request()`
--        line (see bottom of file).
-- Rollback: drop trigger trg_guard_last_admin on public.profiles; drop function public.guard_last_admin();

create or replace function public.guard_last_admin()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  me uuid := auth.uid();
  removes_active_admin boolean;
  others int;
begin
  -- Preview-first gate (remove at release).
  if not public.is_preview_request() then
    return case when tg_op = 'DELETE' then old else new end;
  end if;

  -- Rule 1: nobody changes their own admin status or deactivates themselves.
  if tg_op = 'UPDATE' and me is not null and old.id = me
     and (new.is_admin is distinct from old.is_admin
          or (old.is_active and not new.is_active)) then
    raise exception 'You cannot change your own administrator status or deactivate your own account. Ask another administrator.'
      using errcode = '42501';
  end if;

  -- Rule 2: never leave zero active administrators.
  if tg_op = 'DELETE' then
    removes_active_admin := old.is_admin and old.is_active;
  else
    removes_active_admin := old.is_admin and old.is_active
                            and not (new.is_admin and new.is_active);
  end if;

  if removes_active_admin then
    select count(*) into others
      from public.profiles p
     where p.is_admin and p.is_active and p.id <> old.id;
    if others = 0 then
      raise exception 'LEAP must always have at least one active administrator. Add another administrator first.'
        using errcode = '42501';
    end if;
  end if;

  return case when tg_op = 'DELETE' then old else new end;
end;
$function$;

revoke all on function public.guard_last_admin() from public, anon, authenticated;

drop trigger if exists trg_guard_last_admin on public.profiles;
create trigger trg_guard_last_admin
  before update of is_admin, is_active or delete on public.profiles
  for each row execute function public.guard_last_admin();

-- Record (run in the same SQL editor session when applying):
-- insert into supabase_migrations.schema_migrations (version, name)
--   values ('20261112100000', 'p1_1_last_admin_guard');

-- RELEASE (separate migration, only after Sandra's "go"):
--   create or replace function public.guard_last_admin() ... same body WITHOUT the preview gate.
