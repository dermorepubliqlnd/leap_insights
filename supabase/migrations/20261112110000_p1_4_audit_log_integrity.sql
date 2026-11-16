-- 20261112110000_p1_4_audit_log_integrity
-- What:  Audit-log entries can no longer be faked (Phase 1, fix 1.4).
--        For every entry written by a signed-in user, the database itself sets:
--          * actor_id   = the signed-in user (a forged "who did it" is overwritten)
--          * ts         = the database clock (no back- or future-dating)
--          * actor_name = the user's name at that moment (new column), so the record stays
--                         readable even if that user's profile is later deleted (the
--                         admin-user-actions function blanks actor_id on delete).
--        Entries written by the system itself (migrations, service role: no signed-in user)
--        keep the values they provide.
-- Why:   Policy audit_insert lets any signed-in user insert any row with any actor_id and ts;
--        traceability could be faked. Assessment 02 finding C4.
-- Date:  2026-11-12 · Asked by: Sandra Barlao ("Start Fix 1.4 on Preview")
-- Scope: Additive. One new nullable column, one function, one trigger. No existing rows change.
--        Reading the audit log is unchanged (restricting reads is a later phase).
--        Update/delete of audit rows by signed-in users is already impossible (no RLS policy).
-- Preview first: stamping applies ONLY to requests from the Preview build until release.
--        RELEASE = re-create the function without the `if not public.is_preview_request()` line.
-- Rollback: supabase/rollback/20261112110000_p1_4_audit_log_integrity_ROLLBACK.sql

alter table public.audit_log add column if not exists actor_name text;

create or replace function public.audit_log_stamp()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  me uuid := auth.uid();
begin
  -- Preview-first gate (remove at release).
  if not public.is_preview_request() then
    return new;
  end if;

  if me is not null then
    new.actor_id := me;
    new.ts := now();
    select nullif(btrim(coalesce(p.first_name, '') || ' ' || coalesce(p.last_name, '')), '')
      into new.actor_name
      from public.profiles p
     where p.id = me;
  elsif new.actor_id is not null and new.actor_name is null then
    select nullif(btrim(coalesce(p.first_name, '') || ' ' || coalesce(p.last_name, '')), '')
      into new.actor_name
      from public.profiles p
     where p.id = new.actor_id;
  end if;

  return new;
end;
$function$;

revoke all on function public.audit_log_stamp() from public, anon, authenticated;

drop trigger if exists trg_audit_log_stamp on public.audit_log;
create trigger trg_audit_log_stamp
  before insert on public.audit_log
  for each row execute function public.audit_log_stamp();

-- Record (same session when applying):
-- insert into supabase_migrations.schema_migrations (version, name)
--   values ('20261112110000', 'p1_4_audit_log_integrity');
