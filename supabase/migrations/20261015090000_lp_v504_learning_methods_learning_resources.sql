-- Migration 20261015090000_lp_v504_learning_methods_learning_resources
-- v5.04 (2026-10-15, per Sandra). Additive only.
--   1. learning_methods: configurable Learning Method list (Settings → Lists → Learning Methods), same
--      shape as the other lists (id, name, is_active). Topics store method ids inside the existing
--      learning_programs.agenda JSON (agenda[i].methods = [id, ...]) -- no agenda schema change.
--   2. learning_programs.learning_resources: resource inventory titles [{id, title, updatedAt}] (no URLs/uploads).
--      Administrative metadata (outside the version lock). Existing resource_url (Program Folder) is untouched.
--   3. replace_learning_program copies learning_resources into the next version.
--   4. l1_targets: dated L1 targets (Learning Content Rating, Learning Material Rating, Facilitator
--      Effectiveness, CSAT on 1-5; NPS on -100..100). program_family_id NULL = organisation default
--      (admin only); otherwise a program-specific override (any program editor). Effective dates per
--      metric may not overlap. Version-exempt (not part of the program row).
-- Safe to re-run.

begin;

create table if not exists public.learning_methods (
  id        text primary key default gen_random_uuid()::text,
  name      text not null check (btrim(name) <> ''),
  is_active boolean not null default true
);
create unique index if not exists learning_methods_name_uniq on public.learning_methods (lower(btrim(name)));
alter table public.learning_methods enable row level security;
drop policy if exists learning_methods_select on public.learning_methods;
create policy learning_methods_select on public.learning_methods for select to authenticated using (true);
drop policy if exists learning_methods_write on public.learning_methods;
create policy learning_methods_write on public.learning_methods for all to authenticated using (public.is_admin()) with check (public.is_admin());

insert into public.learning_methods (id, name) values
  ('lm_presentation','Presentation'), ('lm_discussion','Discussion'), ('lm_demonstration','Demonstration'),
  ('lm_activity','Activity'), ('lm_role_play','Role Play'), ('lm_simulation','Simulation'),
  ('lm_assessment','Assessment'), ('lm_video','Video'), ('lm_self_study','Self-Study')
on conflict do nothing;

alter table public.learning_programs
  add column if not exists learning_resources jsonb not null default '[]'::jsonb;
alter table public.learning_programs drop constraint if exists learning_programs_learning_resources_array;
alter table public.learning_programs add constraint learning_programs_learning_resources_array check (jsonb_typeof(learning_resources) = 'array');

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
    insert into public.learning_programs (code,title,category_id,delivery_type,version,status,effective_from,effective_to,description,contributors,components,l3_required,l3_notes,agenda,assessments,duration_hours,duration_minutes,evaluation_config,resource_url,checklist_template_id,delivery_parts,allowed_modalities,created_by,updated_by,program_family_id,supersedes_program_id,ownership,owner_department_id,audience_ids,prerequisite_program_ids,prerequisite_item_ids,learning_resources)
    values (old_record.code,old_record.title,old_record.category_id,old_record.delivery_type,next_version,'draft',p_new_start,null,old_record.description,copied_contributors,'[]'::jsonb,old_record.l3_required,old_record.l3_notes,old_record.agenda,old_record.assessments,old_record.duration_hours,old_record.duration_minutes,old_record.evaluation_config,old_record.resource_url,old_record.checklist_template_id,old_record.delivery_parts,old_record.allowed_modalities,auth.uid(),auth.uid(),coalesce(old_record.program_family_id,old_record.id),old_record.id,old_record.ownership,old_record.owner_department_id,old_record.audience_ids,old_record.prerequisite_program_ids,old_record.prerequisite_item_ids,old_record.learning_resources) returning * into new_record;
  else
    insert into public.learning_programs (code,title,category_id,delivery_type,version,status,effective_from,effective_to,description,contributors,components,l3_required,l3_notes,agenda,assessments,duration_hours,duration_minutes,evaluation_config,resource_url,checklist_template_id,created_by,updated_by,program_family_id,supersedes_program_id,ownership,owner_department_id,audience_ids,prerequisite_program_ids,prerequisite_item_ids,learning_resources)
    values (old_record.code,old_record.title,null,null,next_version,'draft',p_new_start,null,null,'[]'::jsonb,'[]'::jsonb,false,null,'[]'::jsonb,'[]'::jsonb,null,null,'{"l1":false,"l2":{"enabled":false},"l3":{"enabled":false,"items":[]},"l4":{"enabled":false,"items":[]}}'::jsonb,null,null,auth.uid(),auth.uid(),coalesce(old_record.program_family_id,old_record.id),old_record.id,old_record.ownership,old_record.owner_department_id,old_record.audience_ids,old_record.prerequisite_program_ids,old_record.prerequisite_item_ids,old_record.learning_resources) returning * into new_record;
  end if;
  return jsonb_build_object('old',to_jsonb((select x from public.learning_programs x where x.id=p_old_id)),'new',to_jsonb(new_record));
end $function$;

revoke all on function public.replace_learning_program(text, date, date, boolean) from public, anon;
grant execute on function public.replace_learning_program(text, date, date, boolean) to authenticated;

-- 4. Dated L1 targets ----------------------------------------------------------------------
create table if not exists public.l1_targets (
  id                text primary key default gen_random_uuid()::text,
  program_family_id text references public.learning_programs(id) on delete cascade,
  metric            text not null check (metric in ('content','material','facilitator','csat','nps')),
  target            numeric(6,2) not null,
  effective_from    date not null,
  effective_to      date,
  created_at        timestamptz not null default now(),
  created_by        uuid default auth.uid(),
  updated_at        timestamptz not null default now(),
  updated_by        uuid,
  constraint l1_targets_dates check (effective_to is null or effective_to >= effective_from),
  constraint l1_targets_range check ((metric = 'nps' and target between -100 and 100) or (metric <> 'nps' and target between 1 and 5))
);
create index if not exists l1_targets_lookup on public.l1_targets (program_family_id, metric, effective_from);

create or replace function public.l1_targets_no_overlap()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  if exists (
    select 1 from public.l1_targets t
    where t.id <> new.id
      and t.metric = new.metric
      and t.program_family_id is not distinct from new.program_family_id
      and daterange(t.effective_from, coalesce(t.effective_to, 'infinity'::date), '[]')
          && daterange(new.effective_from, coalesce(new.effective_to, 'infinity'::date), '[]')) then
    raise exception 'Another target for this measure already covers part of these dates. End or adjust it first.' using errcode = '23514';
  end if;
  return new;
end $$;
drop trigger if exists l1_targets_no_overlap on public.l1_targets;
create trigger l1_targets_no_overlap before insert or update on public.l1_targets
  for each row execute function public.l1_targets_no_overlap();

alter table public.l1_targets enable row level security;
drop policy if exists l1_targets_select on public.l1_targets;
create policy l1_targets_select on public.l1_targets for select to authenticated using (true);
drop policy if exists l1_targets_write on public.l1_targets;
create policy l1_targets_write on public.l1_targets for all to authenticated
  using (auth.uid() is not null and (program_family_id is not null or public.is_admin()))
  with check (auth.uid() is not null and (program_family_id is not null or public.is_admin()));

insert into public.l1_targets (id, program_family_id, metric, target, effective_from) values
  ('l1d_content', null, 'content', 4.50, '2026-01-01'),
  ('l1d_material', null, 'material', 4.50, '2026-01-01'),
  ('l1d_facilitator', null, 'facilitator', 4.50, '2026-01-01'),
  ('l1d_csat', null, 'csat', 4.50, '2026-01-01'),
  ('l1d_nps', null, 'nps', 50, '2026-01-01')
on conflict do nothing;

commit;
