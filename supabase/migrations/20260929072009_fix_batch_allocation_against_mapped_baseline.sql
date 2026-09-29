-- Migration 20260929072009_fix_batch_allocation_against_mapped_baseline
-- Exported verbatim from supabase_migrations.schema_migrations (live project catvpurbyvsnijxpzwoh) on 2026-09-29.
-- Already applied to production. Do not re-run manually.


create or replace function private.enforce_program_selected_batch()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_family text;
  v_year integer;
  v_count integer := 0;
  v_max_seq integer := 0;
  v_last integer := 0;
  v_next integer;
begin
  if new.program_id is null or new.program_link_origin <> 'program_selection' then
    return new;
  end if;

  -- Unrelated edits to an already-assigned session must never renumber it.
  if tg_op='UPDATE' and old.batch_no is not distinct from new.batch_no then
    return new;
  end if;

  v_year := extract(year from coalesce(
    new.training_date,
    new.session_dates[1],
    (
      select min((j.value->>'date')::date)
      from jsonb_array_elements(coalesce(new.delivery_part_dates,'[]'::jsonb)) j(value)
      where (j.value->>'date') ~ '^\d{4}-\d{2}-\d{2}$'
    )
  ))::integer;

  if v_year is null then
    return new;
  end if;

  select lp.program_family_id into v_family
  from public.learning_programs lp
  where lp.id = new.program_id;

  if v_family is null then
    return new;
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_family || ':' || v_year::text, 0)
  );

  select count(*)::integer,
         coalesce(max(
           case
             when ts.batch_no ~ ('^' || v_year::text || '-[0-9]+$')
             then split_part(ts.batch_no,'-',2)::integer
             else null
           end
         ),0)::integer
    into v_count, v_max_seq
  from public.training_sessions ts
  join public.learning_programs lp on lp.id = ts.program_id
  where lp.program_family_id = v_family
    and ts.id is distinct from new.id
    and extract(year from coalesce(
      ts.training_date,
      ts.session_dates[1],
      (
        select min((j.value->>'date')::date)
        from jsonb_array_elements(coalesce(ts.delivery_part_dates,'[]'::jsonb)) j(value)
        where (j.value->>'date') ~ '^\d{4}-\d{2}-\d{2}$'
      )
    ))::integer = v_year;

  insert into private.training_batch_counters(program_family_id,delivery_year,last_sequence,updated_at)
  values (v_family,v_year,greatest(v_count,v_max_seq),now())
  on conflict (program_family_id,delivery_year)
  do update set
    last_sequence = greatest(private.training_batch_counters.last_sequence, excluded.last_sequence),
    updated_at = now()
  returning last_sequence into v_last;

  v_next := greatest(v_last,v_count,v_max_seq) + 1;
  new.batch_no := v_year::text || '-' || lpad(v_next::text,3,'0');

  update private.training_batch_counters
  set last_sequence=v_next, updated_at=now()
  where program_family_id=v_family and delivery_year=v_year;

  return new;
end;
$$;

-- Reset the counter to the migrated historical baseline for LP-2026-007.
update private.training_batch_counters c
set last_sequence = 10, updated_at = now()
where c.program_family_id = (
  select lp.program_family_id
  from public.learning_programs lp
  where lp.code='LP-2026-007' and lp.version='v1'
)
and c.delivery_year = 2026;

-- Re-allocate the post-mapping test/new session from the authoritative baseline.
update public.training_sessions
set batch_no = null, updated_at = now()
where code='TS-2026-079'
  and program_link_origin='program_selection'
  and status='scheduled';
