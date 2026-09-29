-- Migration 20260928102410_guard_learning_program_session_mapping
-- Exported verbatim from supabase_migrations.schema_migrations (live project catvpurbyvsnijxpzwoh) on 2026-09-29.
-- Already applied to production. Do not re-run manually.

create function public.guard_training_session_program_link()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog, public
as $$
begin
  if (tg_op = 'INSERT' and new.program_id is not null)
     or (tg_op = 'UPDATE' and (
       old.program_id is distinct from new.program_id
       or old.program_link_origin is distinct from new.program_link_origin
       or old.program_linked_at is distinct from new.program_linked_at
     )) then
    if not public.is_admin() then
      raise exception 'Only an administrator may change a session program link' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;
revoke all on function public.guard_training_session_program_link() from public;
create trigger guard_training_session_program_link
before insert or update on public.training_sessions
for each row execute function public.guard_training_session_program_link();
