-- Migration 20260928110737_version_family_code_draft_and_l2_checks
-- Exported verbatim from supabase_migrations.schema_migrations (live project catvpurbyvsnijxpzwoh) on 2026-09-29.
-- Already applied to production. Do not re-run manually.

drop index public.learning_programs_code_key;
create unique index learning_programs_code_version_unique on public.learning_programs(code,version) where code is not null;
alter table public.learning_programs alter column delivery_type drop not null;
alter table public.learning_programs drop constraint learning_programs_status_check;
alter table public.learning_programs add constraint learning_programs_status_check check (status in ('active','inactive','draft'));
alter table public.learning_programs drop constraint learning_programs_inactive_end_chk;
alter table public.learning_programs add constraint learning_programs_inactive_end_chk check (status <> 'inactive' or effective_to is not null);
create or replace function public.learning_program_l2_valid(config jsonb, items jsonb) returns boolean language plpgsql immutable set search_path=public as $$
declare item jsonb; score text;
begin
  if coalesce(config #>> '{l2,enabled}','false') <> 'true' then return true; end if;
  if jsonb_typeof(items) <> 'array' or jsonb_array_length(items)=0 then return false; end if;
  for item in select value from jsonb_array_elements(items) loop
    if nullif(btrim(item->>'name'),'') is null then return false; end if;
    if item->'pre' is distinct from 'true'::jsonb and item->'post' is distinct from 'true'::jsonb then return false; end if;
    if item->'post' = 'true'::jsonb then
      score := item->>'passingScore';
      if score is null or score !~ '^[0-9]+(\.[0-9]+)?$' then return false; end if;
      if score::numeric < 0 or score::numeric > 100 then return false; end if;
    end if;
  end loop;
  return true;
end $$;
alter table public.learning_programs add constraint learning_programs_l2_valid check (public.learning_program_l2_valid(evaluation_config,assessments));
alter table public.learning_programs add constraint learning_programs_successor_active_complete check (status <> 'active' or supersedes_program_id is null or (category_id is not null and delivery_type is not null and jsonb_typeof(agenda)='array' and jsonb_array_length(agenda)>0));
create or replace function public.replace_learning_program(p_old_id text,p_end_date date,p_new_start date)
returns jsonb language plpgsql security invoker set search_path=public as $$
declare old_record public.learning_programs%rowtype; new_record public.learning_programs%rowtype; next_version text;
begin
  perform pg_advisory_xact_lock(hashtext('learning_program_version_'||p_old_id));
  select * into old_record from public.learning_programs where id=p_old_id for update;
  if not found then raise exception 'Program not found'; end if;
  if old_record.status <> 'active' then raise exception 'Only active programs can be replaced'; end if;
  if p_end_date is null or p_end_date < old_record.effective_from then raise exception 'Enter a valid end date'; end if;
  if p_new_start is null or p_new_start <= p_end_date then raise exception 'New version must start after the old version ends'; end if;
  if exists(select 1 from public.learning_programs where supersedes_program_id=p_old_id) then raise exception 'A replacement version already exists'; end if;
  next_version := case when old_record.version ~* '^v[0-9]+$' then 'v'||((substring(old_record.version from 2)::integer)+1)::text else old_record.version||'.1' end;
  update public.learning_programs set status='inactive',effective_to=p_end_date,retirement_reason='replaced',updated_at=now(),updated_by=auth.uid() where id=p_old_id;
  insert into public.learning_programs (code,title,category_id,delivery_type,version,status,effective_from,effective_to,description,contributors,components,l3_required,l3_notes,agenda,assessments,duration_hours,duration_minutes,evaluation_config,resource_url,checklist_template_id,created_by,updated_by,program_family_id,supersedes_program_id)
  values (old_record.code,old_record.title,null,null,next_version,'draft',p_new_start,null,null,'[]'::jsonb,'[]'::jsonb,false,null,'[]'::jsonb,'[]'::jsonb,null,null,'{"l1":false,"l2":{"enabled":false},"l3":{"enabled":false,"items":[]},"l4":{"enabled":false,"items":[]}}'::jsonb,null,null,auth.uid(),auth.uid(),coalesce(old_record.program_family_id,old_record.id),old_record.id) returning * into new_record;
  return jsonb_build_object('old',to_jsonb((select x from public.learning_programs x where x.id=p_old_id)),'new',to_jsonb(new_record));
end $$;
grant execute on function public.replace_learning_program(text,date,date) to authenticated;
update public.learning_programs child set code=parent.code from public.learning_programs parent where child.supersedes_program_id=parent.id and child.code<>parent.code;
