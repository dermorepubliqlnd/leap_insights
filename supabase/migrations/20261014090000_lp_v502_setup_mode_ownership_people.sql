-- Migration 20261014090000_lp_v502_setup_mode_ownership_people
-- v5.02 (2026-10-14, per Sandra). Additive only: no columns dropped, no data rewritten.
--   1. Setup Mode: app_flags.lp_versioning_paused. While TRUE, ADMINS may edit active, in-use
--      programs in place (no minor revision / new version required). Archived versions stay read
--      only; revision history stays append-only; contributor history rules still apply.
--   2. Program ownership (L&D / Non-L&D + owning department), target audiences, prerequisites.
--      Not part of the version lock -> editable on active programs without a new version.
--   3. lp_prerequisites: reusable list of typed prerequisites (same shape as other Settings lists).
--   4. lnd_contacts: SME & External Contacts directory (no LEAP account, no app access).
--   5. learning_program_people: SMEs and program-specific accredited facilitators, linked to the
--      program FAMILY so they carry across versions.
--   6. replace_learning_program copies the new metadata into the next version.
-- Run once in the Supabase SQL Editor. Safe to re-run (idempotent guards).

begin;

-- 1. Setup Mode flag ------------------------------------------------------------------------
create table if not exists public.app_flags (
  key        text primary key,
  value      jsonb not null default 'false'::jsonb,
  updated_at timestamptz not null default now(),
  updated_by uuid
);
alter table public.app_flags enable row level security;
drop policy if exists app_flags_select on public.app_flags;
create policy app_flags_select on public.app_flags for select to authenticated using (true);
drop policy if exists app_flags_write on public.app_flags;
create policy app_flags_write on public.app_flags for all to authenticated using (public.is_admin()) with check (public.is_admin());
insert into public.app_flags (key, value) values ('lp_versioning_paused', 'false'::jsonb) on conflict (key) do nothing;

create or replace function public.lp_versioning_paused()
returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce((select f.value = 'true'::jsonb from public.app_flags f where f.key = 'lp_versioning_paused'), false);
$$;

-- Edit-rule trigger: same as 20261007100000, plus the Setup Mode bypass for admins on the
-- version-lock checks only.
create or replace function public.lock_used_learning_program_content()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  used boolean;
  paused boolean;
  today date := (now() at time zone 'Asia/Manila')::date;
  e jsonb;
  m jsonb;
  old_total numeric;
  new_total numeric;
begin
  if new.revision is distinct from old.revision or new.revision_history is distinct from old.revision_history then
    if new.revision <> old.revision + 1
       or jsonb_array_length(new.revision_history) <> jsonb_array_length(old.revision_history) + 1
       or (new.revision_history - (jsonb_array_length(new.revision_history) - 1)) <> old.revision_history
       or nullif(btrim(coalesce(new.revision_history->-1->>'note', '')), '') is null then
      raise exception 'Revision history can only be extended by one logged revision with a change note.' using errcode = '23514';
    end if;
  end if;

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

  -- v5.02 Setup Mode: admins skip the version / minor-revision checks.
  paused := public.lp_versioning_paused() and public.is_admin();

  if not paused then
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

    if (new.title is distinct from old.title or new.agenda is distinct from old.agenda)
       and new.revision = old.revision then
      raise exception 'Title or agenda changes on a program with implementations must be saved as a logged minor revision.' using errcode = '23514';
    end if;
  end if;

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

-- 2. Ownership, audiences, prerequisites on learning_programs ---------------------------------
alter table public.learning_programs
  add column if not exists ownership text,
  add column if not exists owner_department_id text references public.departments(id),
  add column if not exists audience_ids text[] not null default '{}'::text[],
  add column if not exists prerequisite_program_ids text[] not null default '{}'::text[],
  add column if not exists prerequisite_item_ids text[] not null default '{}'::text[];

alter table public.learning_programs drop constraint if exists learning_programs_ownership_valid;
alter table public.learning_programs add constraint learning_programs_ownership_valid
  check ((ownership is null or ownership in ('ld', 'non_ld'))
         and (ownership is distinct from 'non_ld' or owner_department_id is not null));

-- 3. Prerequisite list (id, name, is_active -- same shape as Settings lists) ----------------
create table if not exists public.lp_prerequisites (
  id        text primary key default gen_random_uuid()::text,
  name      text not null check (btrim(name) <> ''),
  is_active boolean not null default true
);
create unique index if not exists lp_prerequisites_name_uniq on public.lp_prerequisites (lower(btrim(name)));
alter table public.lp_prerequisites enable row level security;
drop policy if exists lp_prerequisites_select on public.lp_prerequisites;
create policy lp_prerequisites_select on public.lp_prerequisites for select to authenticated using (true);
drop policy if exists lp_prerequisites_insert on public.lp_prerequisites;
create policy lp_prerequisites_insert on public.lp_prerequisites for insert to authenticated with check (auth.uid() is not null);
drop policy if exists lp_prerequisites_update on public.lp_prerequisites;
create policy lp_prerequisites_update on public.lp_prerequisites for update to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists lp_prerequisites_delete on public.lp_prerequisites;
create policy lp_prerequisites_delete on public.lp_prerequisites for delete to authenticated using (public.is_admin());

-- 4. SME & External Contacts directory -----------------------------------------------------
create table if not exists public.lnd_contacts (
  id           text primary key default gen_random_uuid()::text,
  full_name    text not null check (btrim(full_name) <> ''),
  organization text,
  contact_type text not null check (contact_type in ('internal_sme', 'external_sme', 'external_facilitator', 'other')),
  email        text,
  position     text,
  is_active    boolean not null default true,
  notes        text,
  created_at   timestamptz not null default now(),
  created_by   uuid default auth.uid(),
  updated_at   timestamptz not null default now(),
  updated_by   uuid
);
create unique index if not exists lnd_contacts_identity_uniq on public.lnd_contacts (lower(btrim(full_name)), lower(btrim(coalesce(email, ''))));
alter table public.lnd_contacts enable row level security;
drop policy if exists lnd_contacts_select on public.lnd_contacts;
create policy lnd_contacts_select on public.lnd_contacts for select to authenticated using (true);
drop policy if exists lnd_contacts_insert on public.lnd_contacts;
create policy lnd_contacts_insert on public.lnd_contacts for insert to authenticated with check (auth.uid() is not null);
drop policy if exists lnd_contacts_update on public.lnd_contacts;
create policy lnd_contacts_update on public.lnd_contacts for update to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists lnd_contacts_delete on public.lnd_contacts;
create policy lnd_contacts_delete on public.lnd_contacts for delete to authenticated using (public.is_admin());

-- 5. SMEs and accredited facilitators per program family ------------------------------------
create table if not exists public.learning_program_people (
  id                   text primary key default gen_random_uuid()::text,
  program_family_id    text not null references public.learning_programs(id) on delete cascade,
  role                 text not null check (role in ('sme', 'facilitator')),
  profile_id           uuid references public.profiles(id),
  contact_id           text references public.lnd_contacts(id) on delete restrict,
  accreditation_status text check (accreditation_status in ('accredited', 'pending', 'expired', 'revoked')),
  accredited_on        date,
  expires_on           date,
  notes                text,
  created_at           timestamptz not null default now(),
  created_by           uuid default auth.uid(),
  updated_at           timestamptz not null default now(),
  updated_by           uuid,
  constraint lpp_one_person check (num_nonnulls(profile_id, contact_id) = 1),
  constraint lpp_status_for_facilitators check ((role = 'facilitator') = (accreditation_status is not null)),
  constraint lpp_dates check (expires_on is null or accredited_on is null or expires_on >= accredited_on)
);
create unique index if not exists lpp_profile_uniq on public.learning_program_people (program_family_id, role, profile_id) where profile_id is not null;
create unique index if not exists lpp_contact_uniq on public.learning_program_people (program_family_id, role, contact_id) where contact_id is not null;
alter table public.learning_program_people enable row level security;
drop policy if exists lpp_select on public.learning_program_people;
create policy lpp_select on public.learning_program_people for select to authenticated using (true);
drop policy if exists lpp_write on public.learning_program_people;
create policy lpp_write on public.learning_program_people for all to authenticated using (auth.uid() is not null) with check (auth.uid() is not null);

-- 6. New versions carry the program metadata forward ----------------------------------------
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
    insert into public.learning_programs (code,title,category_id,delivery_type,version,status,effective_from,effective_to,description,contributors,components,l3_required,l3_notes,agenda,assessments,duration_hours,duration_minutes,evaluation_config,resource_url,checklist_template_id,delivery_parts,allowed_modalities,created_by,updated_by,program_family_id,supersedes_program_id,ownership,owner_department_id,audience_ids,prerequisite_program_ids,prerequisite_item_ids)
    values (old_record.code,old_record.title,old_record.category_id,old_record.delivery_type,next_version,'draft',p_new_start,null,old_record.description,copied_contributors,'[]'::jsonb,old_record.l3_required,old_record.l3_notes,old_record.agenda,old_record.assessments,old_record.duration_hours,old_record.duration_minutes,old_record.evaluation_config,old_record.resource_url,old_record.checklist_template_id,old_record.delivery_parts,old_record.allowed_modalities,auth.uid(),auth.uid(),coalesce(old_record.program_family_id,old_record.id),old_record.id,old_record.ownership,old_record.owner_department_id,old_record.audience_ids,old_record.prerequisite_program_ids,old_record.prerequisite_item_ids) returning * into new_record;
  else
    insert into public.learning_programs (code,title,category_id,delivery_type,version,status,effective_from,effective_to,description,contributors,components,l3_required,l3_notes,agenda,assessments,duration_hours,duration_minutes,evaluation_config,resource_url,checklist_template_id,created_by,updated_by,program_family_id,supersedes_program_id,ownership,owner_department_id,audience_ids,prerequisite_program_ids,prerequisite_item_ids)
    values (old_record.code,old_record.title,null,null,next_version,'draft',p_new_start,null,null,'[]'::jsonb,'[]'::jsonb,false,null,'[]'::jsonb,'[]'::jsonb,null,null,'{"l1":false,"l2":{"enabled":false},"l3":{"enabled":false,"items":[]},"l4":{"enabled":false,"items":[]}}'::jsonb,null,null,auth.uid(),auth.uid(),coalesce(old_record.program_family_id,old_record.id),old_record.id,old_record.ownership,old_record.owner_department_id,old_record.audience_ids,old_record.prerequisite_program_ids,old_record.prerequisite_item_ids) returning * into new_record;
  end if;
  return jsonb_build_object('old',to_jsonb((select x from public.learning_programs x where x.id=p_old_id)),'new',to_jsonb(new_record));
end $function$;

revoke all on function public.replace_learning_program(text, date, date, boolean) from public, anon;
grant execute on function public.replace_learning_program(text, date, date, boolean) to authenticated;

commit;

-- Post-run check (optional):
--   select key, value from public.app_flags;
--   select column_name from information_schema.columns where table_name='learning_programs' and column_name in ('ownership','owner_department_id','audience_ids','prerequisite_program_ids','prerequisite_item_ids');
