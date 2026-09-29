-- Migration 20260928104600_program_version_workflow_and_kpi_metadata
-- Exported verbatim from supabase_migrations.schema_migrations (live project catvpurbyvsnijxpzwoh) on 2026-09-29.
-- Already applied to production. Do not re-run manually.

alter table public.learning_programs add column if not exists program_family_id text, add column if not exists supersedes_program_id text references public.learning_programs(id) on delete restrict, add column if not exists retirement_reason text;
update public.learning_programs set program_family_id=id where program_family_id is null;
alter table public.learning_programs alter column program_family_id set not null;
create index if not exists learning_programs_family_idx on public.learning_programs(program_family_id);
create unique index if not exists learning_programs_supersedes_once_idx on public.learning_programs(supersedes_program_id) where supersedes_program_id is not null;
alter table public.kpi_targets add column if not exists kpi_name text, add column if not exists data_source text, add column if not exists weight numeric;
update public.kpi_targets set kpi_name=case kpi_key when 'idqa' then 'ID QA Score' when 'idContent' then 'Learning Content Rating' when 'idTime' then 'Timeliness' when 'cdqa' then 'CD QA Score' when 'cdMaterial' then 'Learning Material Rating' when 'cdTime' then 'Timeliness' when 'facil' then 'Facilitator Effectiveness' when 'pass' then 'Assessment Pass Rate' when 'obs' then 'Trainer Observation' when 'report' then 'Report Timeliness' when 'csat' then 'Learner Satisfaction (CSAT)' else kpi_key end where kpi_name is null;
update public.kpi_targets set data_source=case kpi_key when 'idqa' then 'idqa' when 'cdqa' then 'cdqa' when 'facil' then 'trainer_evaluation' when 'obs' then 'trainer_evaluation' when 'pass' then 'assessment' when 'report' then 'training_report' when 'csat' then 'csat' else 'pending' end where data_source is null;
update public.kpi_targets set weight=case role when 'id' then 100.0/3 when 'cd' then 100.0/3 else 20 end where weight is null;
alter table public.kpi_targets add constraint kpi_targets_weight_chk check (weight >= 0 and weight <= 100);
create or replace function public.replace_learning_program(p_old_id text,p_end_date date,p_new_start date)
returns jsonb language plpgsql security invoker set search_path=public as $$
declare old_record public.learning_programs%rowtype; new_record public.learning_programs%rowtype; next_number integer; new_code text; next_version text;
begin
  perform pg_advisory_xact_lock(hashtext('learning_program_version_code'));
  select * into old_record from public.learning_programs where id=p_old_id for update;
  if not found then raise exception 'Program not found'; end if;
  if old_record.status <> 'active' then raise exception 'Only active programs can be replaced'; end if;
  if p_end_date is null or p_end_date < old_record.effective_from then raise exception 'Enter a valid end date'; end if;
  if p_new_start is null or p_new_start <= p_end_date then raise exception 'New version must start after the old version ends'; end if;
  if exists(select 1 from public.learning_programs where supersedes_program_id=p_old_id) then raise exception 'A replacement version already exists'; end if;
  next_version := case when old_record.version ~* '^v[0-9]+$' then 'v'||((substring(old_record.version from 2)::integer)+1)::text else old_record.version||'.1' end;
  select coalesce(max(substring(code from 9)::integer),0)+1 into next_number from public.learning_programs where code ~ ('^LP-'||extract(year from current_date)::integer||'-[0-9]+$');
  new_code := 'LP-'||extract(year from current_date)::integer||'-'||lpad(next_number::text,3,'0');
  update public.learning_programs set status='inactive',effective_to=p_end_date,retirement_reason='replaced',updated_at=now(),updated_by=auth.uid() where id=p_old_id;
  insert into public.learning_programs (code,title,category_id,delivery_type,version,status,effective_from,effective_to,description,contributors,components,l3_required,l3_notes,agenda,assessments,duration_hours,duration_minutes,evaluation_config,resource_url,checklist_template_id,created_by,updated_by,program_family_id,supersedes_program_id)
  values (new_code,old_record.title,old_record.category_id,old_record.delivery_type,next_version,'active',p_new_start,null,old_record.description,old_record.contributors,old_record.components,old_record.l3_required,old_record.l3_notes,old_record.agenda,old_record.assessments,old_record.duration_hours,old_record.duration_minutes,old_record.evaluation_config,old_record.resource_url,old_record.checklist_template_id,auth.uid(),auth.uid(),coalesce(old_record.program_family_id,old_record.id),old_record.id) returning * into new_record;
  return jsonb_build_object('old',to_jsonb((select x from public.learning_programs x where x.id=p_old_id)),'new',to_jsonb(new_record));
end $$;
grant execute on function public.replace_learning_program(text,date,date) to authenticated;
