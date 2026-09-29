-- Migration 20260928232340_strengthen_program_part_schedule_validation
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
   if (select sum((x->>'minutes')::numeric) from jsonb_array_elements(new.delivery_plan) x)<>round(new.duration_hours*60) then raise exception 'Delivery parts must equal the agenda total.' using errcode='23514'; end if;
   if jsonb_typeof(new.delivery_part_dates)<>'array' then raise exception 'Delivery part dates must be an array.' using errcode='23514'; end if;
   date_count:=jsonb_array_length(new.delivery_part_dates);
   if date_count<>0 then
     if date_count<>jsonb_array_length(new.delivery_plan) or exists(select 1 from jsonb_array_elements(new.delivery_part_dates) with ordinality x(value,i) where coalesce(x.value->>'date','') !~ '^\d{4}-\d{2}-\d{2}$' or (x.value->>'part')::integer<>x.i) or (select count(distinct x->>'date') from jsonb_array_elements(new.delivery_part_dates) x)<>date_count then
       raise exception 'Assign one distinct date to every delivery part.' using errcode='23514';
     end if;
     if new.date_mode<>'specific' or new.session_dates is null or cardinality(new.session_dates)<>date_count or exists(select 1 from jsonb_array_elements(new.delivery_part_dates) x where not (x->>'date')=any(new.session_dates)) then raise exception 'Session dates must match the delivery part dates.' using errcode='23514'; end if;
   end if;
 end if;
 return new;
end $$;
