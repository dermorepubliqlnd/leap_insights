-- Migration 20260928232010_validate_learning_program_delivery_part_dates
-- Exported verbatim from supabase_migrations.schema_migrations (live project catvpurbyvsnijxpzwoh) on 2026-09-29.
-- Already applied to production. Do not re-run manually.

create or replace function public.validate_learning_program_delivery_dates() returns trigger language plpgsql set search_path=pg_catalog,public as $$
declare date_count integer;
begin
 if new.program_link_origin='program_selection' and jsonb_array_length(new.delivery_plan)>0 then
   if tg_op='UPDATE' and old.program_link_origin='program_selection' and new.program_id is not distinct from old.program_id then
     new.checklist_template_id:=old.checklist_template_id;
     new.assessment_names:=old.assessment_names;
   end if;
   if jsonb_typeof(new.delivery_part_dates)<>'array' then raise exception 'Delivery part dates must be an array.' using errcode='23514'; end if;
   date_count:=jsonb_array_length(new.delivery_part_dates);
   if date_count<>0 then
     if date_count<>jsonb_array_length(new.delivery_plan) or exists(select 1 from jsonb_array_elements(new.delivery_part_dates) x where coalesce(x->>'date','') !~ '^\d{4}-\d{2}-\d{2}$') or (select count(distinct x->>'date') from jsonb_array_elements(new.delivery_part_dates) x)<>date_count then
       raise exception 'Assign one distinct date to every delivery part.' using errcode='23514';
     end if;
     if new.session_dates is null or cardinality(new.session_dates)<>date_count then raise exception 'Session dates must match the delivery part dates.' using errcode='23514'; end if;
   end if;
 end if;
 return new;
end $$;
drop trigger if exists zzz_validate_learning_program_delivery_dates on public.training_sessions;
create trigger zzz_validate_learning_program_delivery_dates before insert or update on public.training_sessions for each row execute function public.validate_learning_program_delivery_dates();
