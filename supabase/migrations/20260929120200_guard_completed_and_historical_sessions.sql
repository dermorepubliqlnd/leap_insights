-- Migration 20260929120200_guard_completed_and_historical_sessions
-- Exported verbatim from supabase_migrations.schema_migrations (live project catvpurbyvsnijxpzwoh) on 2026-09-29.
-- Already applied to production. Do not re-run manually.

create or replace function public.guard_training_session_protected_changes()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_end date;
begin
  if auth.uid() is null or public.is_admin() then
    return coalesce(new, old);
  end if;

  if tg_op = 'DELETE' then
    if old.status = 'completed' then
      raise exception 'Delivery Complete sessions can only be deleted by an administrator.'
        using errcode = '42501';
    end if;
    return old;
  end if;

  -- UPDATE
  if old.program_id is null
     or old.program_link_origin not in ('program_selection','catalog_mapping')
     or old.status is distinct from 'completed' then
    return new;
  end if;

  if old.date_mode = 'specific' and old.session_dates is not null and cardinality(old.session_dates) > 0 then
    select max(d) into v_end from unnest(old.session_dates) as d;
  end if;
  v_end := coalesce(v_end, old.end_date, old.training_date);
  if v_end is null or v_end >= date '2026-10-01' then
    return new;
  end if;

  if new.training_program is distinct from old.training_program
     or new.delivery_type is distinct from old.delivery_type
     or new.status is distinct from old.status
     or new.training_date is distinct from old.training_date
     or new.end_date is distinct from old.end_date
     or new.date_mode is distinct from old.date_mode
     or new.session_dates is distinct from old.session_dates
     or new.delivery_part_dates is distinct from old.delivery_part_dates
     or new.trainer_id is distinct from old.trainer_id
     or new.co_facilitator_id is distinct from old.co_facilitator_id
     or new.guest_trainer_name is distinct from old.guest_trainer_name
     or new.co_facilitator_guest_name is distinct from old.co_facilitator_guest_name
     or new.facilitator_name is distinct from old.facilitator_name
     or new.venue_id is distinct from old.venue_id
     or new.venue_other_name is distinct from old.venue_other_name
     or new.modality_id is distinct from old.modality_id
     or new.audience is distinct from old.audience
     or new.batch_no is distinct from old.batch_no
     or new.code is distinct from old.code
     or new.duration is distinct from old.duration
     or new.duration_hours is distinct from old.duration_hours
     or new.num_participants is distinct from old.num_participants
     or new.expected_participants is distinct from old.expected_participants
     or new.program_id is distinct from old.program_id
     or new.program_link_origin is distinct from old.program_link_origin
     or new.program_linked_at is distinct from old.program_linked_at
  then
    raise exception 'Historical mapped sessions are read-only for core delivery facts. Only Session Notes can be updated.'
      using errcode = '42501';
  end if;
  return new;
end;
$function$;

drop trigger if exists trg_guard_training_session_protected_changes on public.training_sessions;
create trigger trg_guard_training_session_protected_changes
  before update or delete on public.training_sessions
  for each row execute function public.guard_training_session_protected_changes();
