-- Migration 20260928114126_limit_catalog_mapping_to_past_or_completed_sessions
-- Exported verbatim from supabase_migrations.schema_migrations (live project catvpurbyvsnijxpzwoh) on 2026-09-29.
-- Already applied to production. Do not re-run manually.

create or replace function public.validate_historical_program_mapping()
returns trigger
language plpgsql
set search_path = public
as $$
declare last_day text;
begin
  if new.program_link_origin <> 'catalog_mapping' or new.program_id is null then return new; end if;
  if tg_op = 'UPDATE' and new.program_id is not distinct from old.program_id
     and new.program_link_origin is not distinct from old.program_link_origin then return new; end if;
  if new.date_mode = 'specific' and jsonb_typeof(new.session_dates) = 'array' then
    select max(day) into last_day from jsonb_array_elements_text(new.session_dates) as day;
  end if;
  last_day := coalesce(last_day,new.end_date::text,new.training_date::text);
  if new.status in ('cancelled','tentative') or
     (new.status is distinct from 'completed' and (last_day is null or last_day >= (now() at time zone 'Asia/Manila')::date::text)) then
    raise exception 'Only Completed sessions or sessions whose last training date has passed can be mapped to a Learning Program.' using errcode = '23514';
  end if;
  return new;
end;
$$;
create trigger training_session_historical_mapping_guard
before insert or update of program_id,program_link_origin on public.training_sessions
for each row execute function public.validate_historical_program_mapping();
