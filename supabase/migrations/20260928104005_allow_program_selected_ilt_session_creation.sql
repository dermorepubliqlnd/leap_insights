-- Migration 20260928104005_allow_program_selected_ilt_session_creation
-- Exported verbatim from supabase_migrations.schema_migrations (live project catvpurbyvsnijxpzwoh) on 2026-09-29.
-- Already applied to production. Do not re-run manually.

create or replace function public.guard_training_session_program_link()
returns trigger
language plpgsql
security invoker
set search_path = pg_catalog, public
as $$
begin
  if tg_op = 'INSERT' and new.program_id is not null then
    if new.program_link_origin = 'program_selection'
       and new.delivery_type = 'ILT'
       and exists (
         select 1 from public.learning_programs p
         where p.id = new.program_id
           and p.status = 'active'
           and p.delivery_type in ('ILT','Blended')
       ) then
      return new;
    end if;
    if not public.is_admin() then
      raise exception 'Only an administrator may add a catalogue mapping' using errcode = '42501';
    end if;
  elsif tg_op = 'UPDATE' and (
      old.program_id is distinct from new.program_id
      or old.program_link_origin is distinct from new.program_link_origin
      or old.program_linked_at is distinct from new.program_linked_at
    ) then
    if not public.is_admin() then
      raise exception 'Only an administrator may change an existing session program link' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;
