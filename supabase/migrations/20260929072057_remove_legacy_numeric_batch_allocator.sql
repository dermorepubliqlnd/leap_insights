-- Migration 20260929072057_remove_legacy_numeric_batch_allocator
-- Exported verbatim from supabase_migrations.schema_migrations (live project catvpurbyvsnijxpzwoh) on 2026-09-29.
-- Already applied to production. Do not re-run manually.


create or replace function public.apply_learning_program_session_snapshot()
returns trigger
language plpgsql
set search_path = 'pg_catalog', 'public'
as $$
declare
  program_row public.learning_programs%rowtype;
begin
  if tg_op = 'INSERT' and new.program_link_origin = 'program_selection' then
    select * into program_row
    from public.learning_programs
    where id = new.program_id;

    if not found or program_row.status <> 'active' then
      raise exception 'Select an active Learning Program.' using errcode = '23514';
    end if;

    if program_row.duration_minutes is null or program_row.duration_minutes <= 0 then
      raise exception 'The Learning Program needs a valid agenda duration before a session can be created.'
        using errcode = '23514';
    end if;

    -- Batch numbering is intentionally NOT handled here.
    -- private.enforce_program_selected_batch is the single authoritative allocator and uses
    -- program family + delivery year + mapped historical baseline.

    new.training_program := program_row.title;
    new.duration_hours := program_row.duration_minutes::numeric/60;
    new.duration_basis := 'total';
    select c.name into new.category
    from public.categories c
    where c.id = program_row.category_id;

    new.assessment_names :=
      case
        when coalesce((program_row.evaluation_config->'l2'->>'enabled')::boolean,false)
          then program_row.assessments
        else '[]'::jsonb
      end;

  elsif tg_op = 'UPDATE'
    and old.program_link_origin = 'program_selection'
    and new.program_id is not distinct from old.program_id then

    new.training_program := old.training_program;
    new.duration_hours := old.duration_hours;
    new.duration_basis := old.duration_basis;
    new.category := old.category;
    new.delivery_type := old.delivery_type;

    -- Do not overwrite batch_no here. The dedicated batch allocator owns it.
  end if;

  return new;
end;
$$;

-- Reset to the mapped historical baseline, then reallocate the post-mapping scheduled session.
update private.training_batch_counters c
set last_sequence = 10,
    updated_at = now()
where c.program_family_id = (
  select lp.program_family_id
  from public.learning_programs lp
  where lp.code='LP-2026-007' and lp.version='v1'
)
and c.delivery_year = 2026;

update public.training_sessions
set batch_no = null,
    updated_at = now()
where code='TS-2026-079'
  and program_link_origin='program_selection'
  and status='scheduled';
