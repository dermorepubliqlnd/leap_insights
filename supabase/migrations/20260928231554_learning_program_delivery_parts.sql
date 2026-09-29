-- Migration 20260928231554_learning_program_delivery_parts
-- Exported verbatim from supabase_migrations.schema_migrations (live project catvpurbyvsnijxpzwoh) on 2026-09-29.
-- Already applied to production. Do not re-run manually.

alter table public.learning_programs add column if not exists delivery_parts integer not null default 1;
alter table public.learning_programs add constraint learning_programs_delivery_parts_range check (delivery_parts between 1 and 30);
alter table public.training_sessions add column if not exists delivery_plan jsonb not null default '[]'::jsonb;
alter table public.training_sessions add column if not exists delivery_part_dates jsonb not null default '[]'::jsonb;
create or replace function public.snapshot_learning_program_delivery_plan() returns trigger language plpgsql set search_path = pg_catalog, public as $$
declare p public.learning_programs%rowtype;
declare plan jsonb;
begin
 if tg_op='INSERT' and new.program_link_origin='program_selection' then
   select * into p from public.learning_programs where id=new.program_id;
   if not found or p.status<>'active' then raise exception 'Select an active Learning Program.' using errcode='23514'; end if;
   if p.delivery_parts>1 then
     if jsonb_typeof(p.agenda)<>'array' or jsonb_array_length(p.agenda)=0 or exists(select 1 from jsonb_array_elements(p.agenda) a where coalesce(a->>'part','') !~ '^[1-9][0-9]*$' or (a->>'part')::int>p.delivery_parts or coalesce(a->>'duration','') !~ '^[1-9][0-9]*$') then
       raise exception 'The program agenda needs a valid part and duration for every topic.' using errcode='23514';
     end if;
     select jsonb_agg(jsonb_build_object('part',n,'minutes',coalesce((select sum((a->>'duration')::integer) from jsonb_array_elements(p.agenda) a where (a->>'part')::integer=n),0)) order by n) into plan from generate_series(1,p.delivery_parts) n;
     if exists(select 1 from jsonb_array_elements(plan) x where (x->>'minutes')::int<=0) then raise exception 'Each delivery part needs at least one agenda item.' using errcode='23514'; end if;
   else
     plan:=jsonb_build_array(jsonb_build_object('part',1,'minutes',p.duration_minutes));
   end if;
   new.delivery_plan:=plan;
   new.delivery_part_dates:='[]'::jsonb;
 elsif tg_op='UPDATE' and old.program_link_origin='program_selection' and new.program_id is not distinct from old.program_id then
   new.delivery_plan:=old.delivery_plan;
 end if;
 return new;
end $$;
drop trigger if exists zz_snapshot_learning_program_delivery_plan on public.training_sessions;
create trigger zz_snapshot_learning_program_delivery_plan before insert or update on public.training_sessions for each row execute function public.snapshot_learning_program_delivery_plan();
