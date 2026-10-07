-- Migration 20261007100000_learning_program_minor_revisions_and_dated_contributors
-- v5.00 (2026-10-07, per Sandra): edit rules for Learning Programs that already have implementations.
--   * Free edits (no version change): resource link, description, category, default checklist, contributors.
--   * Minor revision (v1 -> v1.1, same row, reports roll up): title and agenda wording/timing/order,
--     same topic count, same total duration, same delivery parts. Requires a change note.
--   * Major version (new row via replace_learning_program): delivery type, delivery parts, topic
--     count, total duration, assessments, evaluation setup.
--   * Contributors become dated assignments {id, profileId, role, primary, startDate, endDate, addedAt}.
--     Once a program has implementations, assignments can be ended but not deleted (same-day
--     mistakes excepted); only admins can correct dates.
--   * Session program snapshot now records revision + contributors at creation.
--   * replace_learning_program gains p_copy_content (copy current content into the new draft).

begin;

-- 1. Revision columns ---------------------------------------------------------------------
alter table public.learning_programs
  add column if not exists revision integer not null default 0,
  add column if not exists revision_history jsonb not null default '[]'::jsonb;

alter table public.learning_programs drop constraint if exists learning_programs_revision_valid;
alter table public.learning_programs add constraint learning_programs_revision_valid
  check (revision >= 0 and jsonb_typeof(revision_history) = 'array' and jsonb_array_length(revision_history) = revision);

-- 2. Backfill contributor assignment ids/dates (bypass row locks for this one-time data fix) --
alter table public.learning_programs disable trigger learning_program_archived_read_only;
alter table public.learning_programs disable trigger learning_program_used_content_lock;

update public.learning_programs lp
set contributors = coalesce((
  select jsonb_agg(
           c
           || jsonb_build_object(
                'id',        coalesce(c->>'id', gen_random_uuid()::text),
                'startDate', coalesce(c->>'startDate', lp.effective_from::text),
                'addedAt',   coalesce(c->>'addedAt', lp.created_at::text))
           || case when c ? 'endDate' then '{}'::jsonb else jsonb_build_object('endDate', null) end
           order by ord)
  from jsonb_array_elements(lp.contributors) with ordinality as t(c, ord)
), '[]'::jsonb)
where jsonb_typeof(lp.contributors) = 'array' and jsonb_array_length(lp.contributors) > 0;

alter table public.learning_programs enable trigger learning_program_used_content_lock;
alter table public.learning_programs enable trigger learning_program_archived_read_only;

-- 3. Edit rules (replaces the all-or-nothing content lock) ----------------------------------
create or replace function public.lock_used_learning_program_content()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  used boolean;
  today date := (now() at time zone 'Asia/Manila')::date;
  e jsonb;
  m jsonb;
  old_total numeric;
  new_total numeric;
begin
  -- Revision bookkeeping applies to every status: append exactly one noted entry, never rewrite.
  if new.revision is distinct from old.revision or new.revision_history is distinct from old.revision_history then
    if new.revision <> old.revision + 1
       or jsonb_array_length(new.revision_history) <> jsonb_array_length(old.revision_history) + 1
       or (new.revision_history - (jsonb_array_length(new.revision_history) - 1)) <> old.revision_history
       or nullif(btrim(coalesce(new.revision_history->-1->>'note', '')), '') is null then
      raise exception 'Revision history can only be extended by one logged revision with a change note.' using errcode = '23514';
    end if;
  end if;

  -- Assignment dates must be coherent.
  for e in select x from jsonb_array_elements(coalesce(new.contributors, '[]'::jsonb)) x loop
    if nullif(e->>'endDate', '') is not null and nullif(e->>'startDate', '') is not null
       and (e->>'endDate')::date < (e->>'startDate')::date then
      raise exception 'A contributor assignment cannot end before it starts.' using errcode = '23514';
    end if;
  end loop;

  if old.status <> 'active' then
    return new;
  end if;

  used := exists (
    select 1 from public.training_sessions s
    where s.program_id = old.id
      and s.status in ('scheduled', 'completed')
      and s.program_link_origin in ('program_selection', 'catalog_mapping'));
  if not used then
    return new;
  end if;

  -- Major-version fields.
  select coalesce(sum((x->>'duration')::numeric), 0) into old_total from jsonb_array_elements(coalesce(old.agenda, '[]'::jsonb)) x;
  select coalesce(sum((x->>'duration')::numeric), 0) into new_total from jsonb_array_elements(coalesce(new.agenda, '[]'::jsonb)) x;
  if row(new.delivery_type, new.delivery_parts, new.assessments, new.evaluation_config, new.l3_required, new.allowed_modalities)
       is distinct from
     row(old.delivery_type, old.delivery_parts, old.assessments, old.evaluation_config, old.l3_required, old.allowed_modalities)
     or jsonb_array_length(coalesce(new.agenda, '[]'::jsonb)) <> jsonb_array_length(coalesce(old.agenda, '[]'::jsonb))
     or new_total <> old_total
     or new.duration_minutes is distinct from old.duration_minutes then
    raise exception 'This change needs a new program version (delivery type, parts, topic count, total duration, assessments or evaluations changed).' using errcode = '23514';
  end if;

  -- Minor-revision fields need a logged revision.
  if (new.title is distinct from old.title or new.agenda is distinct from old.agenda)
     and new.revision = old.revision then
    raise exception 'Title or agenda changes on a program with implementations must be saved as a logged minor revision.' using errcode = '23514';
  end if;

  -- Contributor history: end, do not delete; only admins correct dates.
  for e in select x from jsonb_array_elements(coalesce(old.contributors, '[]'::jsonb)) x loop
    continue when not (e ? 'id');
    m := null;
    select x into m from jsonb_array_elements(coalesce(new.contributors, '[]'::jsonb)) x where x->>'id' = e->>'id' limit 1;
    if m is null then
      if nullif(e->>'addedAt', '') is null
         or ((e->>'addedAt')::timestamptz at time zone 'Asia/Manila')::date <> today then
        raise exception 'Contributor assignments cannot be deleted once the program has implementations. End the assignment instead.' using errcode = '23514';
      end if;
    else
      if m->>'profileId' is distinct from e->>'profileId' or m->>'role' is distinct from e->>'role' then
        raise exception 'A contributor assignment''s person and role cannot be changed. End it and add a new assignment.' using errcode = '23514';
      end if;
      if (m->>'startDate' is distinct from e->>'startDate'
          or (nullif(e->>'endDate', '') is not null and m->>'endDate' is distinct from e->>'endDate'))
         and not public.is_admin() then
        raise exception 'Only administrators can correct contributor assignment dates.' using errcode = '23514';
      end if;
    end if;
  end loop;

  return new;
end $$;

-- 4. Session snapshot records revision + contributors at creation ---------------------------
create or replace function public.snapshot_selected_program_information()
returns trigger
language plpgsql
set search_path to 'pg_catalog', 'public'
as $function$
declare p public.learning_programs%rowtype;
begin
 if tg_op='INSERT' and new.program_link_origin='program_selection' then
   select * into p from public.learning_programs where id=new.program_id;
   if not found then raise exception 'Learning Program not found.' using errcode='23514'; end if;
   new.program_info_snapshot:=jsonb_build_object('code',p.code,'title',p.title,'version',p.version,'revision',p.revision,'description',p.description,'agenda',p.agenda,'deliveryType',p.delivery_type,'resourceUrl',p.resource_url,'allowedModalities',p.allowed_modalities,'effectiveFrom',p.effective_from,'effectiveTo',p.effective_to,'contributors',p.contributors);
   new.evaluation_plan:=coalesce(p.evaluation_config,'{}'::jsonb);
   new.l3_required:=coalesce((p.evaluation_config->'l3'->>'enabled')::boolean,false);
   new.l3_methods:=coalesce((select jsonb_agg(x->>'method') from jsonb_array_elements(coalesce(p.evaluation_config->'l3'->'items','[]'::jsonb)) x),'[]'::jsonb);
   new.l3_followups:=coalesce((select jsonb_agg(jsonb_build_object('method',x->>'method','daysAfter',(x->>'daysAfter')::integer,'notes',coalesce(x->>'notes',''),'dueDate',null,'rating',null,'evidence','','completedAt',null)) from jsonb_array_elements(coalesce(p.evaluation_config->'l3'->'items','[]'::jsonb)) x),'[]'::jsonb);
   new.l4_results:=coalesce((select jsonb_agg(jsonb_build_object('measure',x->>'measure','baseline',coalesce(x->>'baseline',''),'target',coalesce(x->>'target',''),'actual','','notes','')) from jsonb_array_elements(coalesce(p.evaluation_config->'l4'->'items','[]'::jsonb)) x),'[]'::jsonb);
 elsif tg_op='UPDATE' and old.program_link_origin='program_selection' and new.program_id is not distinct from old.program_id then
   new.program_info_snapshot:=old.program_info_snapshot;
   new.evaluation_plan:=old.evaluation_plan;
   new.l3_required:=old.l3_required;
 end if;
 return new;
end $function$;

-- 5. New version: optionally copy current content into the draft ----------------------------
drop function if exists public.replace_learning_program(text, date, date);

create or replace function public.replace_learning_program(p_old_id text, p_end_date date, p_new_start date, p_copy_content boolean default false)
returns jsonb
language plpgsql
set search_path to 'public'
as $function$
declare old_record public.learning_programs%rowtype; new_record public.learning_programs%rowtype; next_version text; copied_contributors jsonb;
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
  if coalesce(p_copy_content,false) then
    copied_contributors := coalesce((
      select jsonb_agg((c - 'endDate') || jsonb_build_object('id',gen_random_uuid()::text,'startDate',p_new_start::text,'endDate',null,'addedAt',now()::text) order by ord)
      from jsonb_array_elements(coalesce(old_record.contributors,'[]'::jsonb)) with ordinality t(c,ord)
      where nullif(c->>'endDate','') is null or (c->>'endDate')::date >= p_end_date),'[]'::jsonb);
    insert into public.learning_programs (code,title,category_id,delivery_type,version,status,effective_from,effective_to,description,contributors,components,l3_required,l3_notes,agenda,assessments,duration_hours,duration_minutes,evaluation_config,resource_url,checklist_template_id,delivery_parts,allowed_modalities,created_by,updated_by,program_family_id,supersedes_program_id)
    values (old_record.code,old_record.title,old_record.category_id,old_record.delivery_type,next_version,'draft',p_new_start,null,old_record.description,copied_contributors,'[]'::jsonb,old_record.l3_required,old_record.l3_notes,old_record.agenda,old_record.assessments,old_record.duration_hours,old_record.duration_minutes,old_record.evaluation_config,old_record.resource_url,old_record.checklist_template_id,old_record.delivery_parts,old_record.allowed_modalities,auth.uid(),auth.uid(),coalesce(old_record.program_family_id,old_record.id),old_record.id) returning * into new_record;
  else
    insert into public.learning_programs (code,title,category_id,delivery_type,version,status,effective_from,effective_to,description,contributors,components,l3_required,l3_notes,agenda,assessments,duration_hours,duration_minutes,evaluation_config,resource_url,checklist_template_id,created_by,updated_by,program_family_id,supersedes_program_id)
    values (old_record.code,old_record.title,null,null,next_version,'draft',p_new_start,null,null,'[]'::jsonb,'[]'::jsonb,false,null,'[]'::jsonb,'[]'::jsonb,null,null,'{"l1":false,"l2":{"enabled":false},"l3":{"enabled":false,"items":[]},"l4":{"enabled":false,"items":[]}}'::jsonb,null,null,auth.uid(),auth.uid(),coalesce(old_record.program_family_id,old_record.id),old_record.id) returning * into new_record;
  end if;
  return jsonb_build_object('old',to_jsonb((select x from public.learning_programs x where x.id=p_old_id)),'new',to_jsonb(new_record));
end $function$;

revoke all on function public.replace_learning_program(text, date, date, boolean) from public, anon;
grant execute on function public.replace_learning_program(text, date, date, boolean) to authenticated;

commit;
