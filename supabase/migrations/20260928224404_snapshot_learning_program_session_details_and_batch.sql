-- Migration 20260928224404_snapshot_learning_program_session_details_and_batch
-- Exported verbatim from supabase_migrations.schema_migrations (live project catvpurbyvsnijxpzwoh) on 2026-09-29.
-- Already applied to production. Do not re-run manually.

alter table public.training_sessions
add column if not exists duration_basis text not null default 'per_day';

alter table public.training_sessions
add constraint training_sessions_duration_basis_check check (duration_basis in ('per_day','total'));

create or replace function public.apply_learning_program_session_snapshot()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare program_row public.learning_programs%rowtype;
declare family_key text;
declare next_batch integer;
begin
  if tg_op = 'INSERT' and new.program_link_origin = 'program_selection' then
    select * into program_row from public.learning_programs where id = new.program_id;
    if not found or program_row.status <> 'active' then
      raise exception 'Select an active Learning Program.' using errcode = '23514';
    end if;
    if program_row.duration_minutes is null or program_row.duration_minutes <= 0 then
      raise exception 'The Learning Program needs a valid agenda duration before a session can be created.' using errcode = '23514';
    end if;
    family_key := coalesce(program_row.program_family_id,program_row.id);
    perform pg_advisory_xact_lock(hashtext('learning_program_batch_'||family_key));
    select coalesce(max(s.batch_no::integer),0)+1 into next_batch
      from public.training_sessions s
      join public.learning_programs lp on lp.id=s.program_id
      where coalesce(lp.program_family_id,lp.id)=family_key
        and s.batch_no ~ '^[0-9]+$';
    new.batch_no := lpad(next_batch::text,3,'0');
    new.training_program := program_row.title;
    new.duration_hours := program_row.duration_minutes::numeric/60;
    new.duration_basis := 'total';
    select c.name into new.category from public.categories c where c.id=program_row.category_id;
    new.assessment_names := case when coalesce((program_row.evaluation_config->'l2'->>'enabled')::boolean,false)
      then program_row.assessments else '[]'::jsonb end;
  elsif tg_op = 'UPDATE' and old.program_link_origin = 'program_selection'
    and new.program_id is not distinct from old.program_id then
    new.training_program := old.training_program;
    new.duration_hours := old.duration_hours;
    new.duration_basis := old.duration_basis;
    new.category := old.category;
    new.batch_no := old.batch_no;
    new.delivery_type := old.delivery_type;
  end if;
  return new;
end;
$$;

create trigger z_training_session_program_snapshot
before insert or update on public.training_sessions
for each row execute function public.apply_learning_program_session_snapshot();
