-- Migration 20260928112134_protect_archived_learning_program_versions
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
  return old;
end;
$$;

create trigger learning_program_archived_read_only
before update or delete on public.learning_programs
for each row execute function public.reject_archived_learning_program_changes();
