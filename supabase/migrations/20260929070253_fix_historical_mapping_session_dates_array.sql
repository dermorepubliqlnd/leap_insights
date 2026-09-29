-- Migration 20260929070253_fix_historical_mapping_session_dates_array
-- Exported verbatim from supabase_migrations.schema_migrations (live project catvpurbyvsnijxpzwoh) on 2026-09-29.
-- Already applied to production. Do not re-run manually.


create or replace function public.validate_historical_program_mapping()
returns trigger
language plpgsql
set search_path = 'public'
as $$
declare
  last_day date;
begin
  if new.program_link_origin <> 'catalog_mapping' or new.program_id is null then
    return new;
  end if;

  if tg_op = 'UPDATE'
     and new.program_id is not distinct from old.program_id
     and new.program_link_origin is not distinct from old.program_link_origin then
    return new;
  end if;

  -- training_sessions.session_dates is a native date[] column, not jsonb.
  if new.date_mode = 'specific'
     and new.session_dates is not null
     and cardinality(new.session_dates) > 0 then
    select max(d) into last_day
    from unnest(new.session_dates) as d;
  end if;

  last_day := coalesce(last_day, new.end_date, new.training_date);

  if new.status in ('cancelled','tentative')
     or (
       new.status is distinct from 'completed'
       and (
         last_day is null
         or last_day >= (now() at time zone 'Asia/Manila')::date
       )
     ) then
    raise exception
      'Only Completed sessions or sessions whose last training date has passed can be mapped to a Learning Program.'
      using errcode = '23514';
  end if;

  return new;
end;
$$;
