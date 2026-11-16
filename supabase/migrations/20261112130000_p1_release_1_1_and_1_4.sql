-- 20261112130000_p1_release_1_1_and_1_4
-- What:  RELEASE to Live of Phase 1 fixes 1.1 (last-admin guard) and 1.4 (audit-log integrity).
--        Re-creates both functions WITHOUT the preview-only gate, so the rules apply to every
--        request (Live and Preview). Logic is otherwise identical to the tested Preview versions.
-- Why:   Validated on Preview 12 Nov: rolled-back tests (13/13 and 7/7) + real end-to-end check
--        on the Preview site as Sandra (self-demote/deactivate blocked; forged audit actor/date overwritten).
-- Date:  2026-11-12 · Approved by: Sandra Barlao ("ok" to release 1.1 and 1.4 to Live)
-- Rollback (restore Preview-only behaviour): re-run the function bodies from
--        20261112100000_p1_1_last_admin_guard.sql and 20261112110000_p1_4_audit_log_integrity.sql;
--        full removal: supabase/rollback/*_ROLLBACK.sql for each fix.

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

create or replace function public.audit_log_stamp()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  me uuid := auth.uid();
begin
  if me is not null then
    new.actor_id := me;
    new.ts := now();
    select nullif(btrim(coalesce(p.first_name, '') || ' ' || coalesce(p.last_name, '')), '')
      into new.actor_name from public.profiles p where p.id = me;
  elsif new.actor_id is not null and new.actor_name is null then
    select nullif(btrim(coalesce(p.first_name, '') || ' ' || coalesce(p.last_name, '')), '')
      into new.actor_name from public.profiles p where p.id = new.actor_id;
  end if;
  return new;
end;
$function$;

revoke all on function public.guard_last_admin() from public, anon, authenticated;
revoke all on function public.audit_log_stamp() from public, anon, authenticated;

-- Record:
-- insert into supabase_migrations.schema_migrations (version, name)
--   values ('20261112130000', 'p1_release_1_1_and_1_4');
