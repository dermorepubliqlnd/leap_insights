-- Migration 20260928113344_fix_archived_program_trigger_return
-- Exported verbatim from supabase_migrations.schema_migrations (live project catvpurbyvsnijxpzwoh) on 2026-09-29.
-- Already applied to production. Do not re-run manually.

create or replace function public.reject_archived_learning_program_changes()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if old.status = 'inactive' then
    raise exception 'Archived learning program versions are read only.' using errcode = '23514';
  end if;
  if tg_op = 'UPDATE' then
    return new;
  end if;
  return old;
end;
$$;
