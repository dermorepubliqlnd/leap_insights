-- 20261118130000_lp_audience_levels_departments
-- What: Target Audience split into LEVELS and DEPARTMENTS (each with an "All" option),
--       and the compliance rule's "Who must complete" now comes from the program's target audience.
--   (a) learning_programs: audience_all_levels / audience_level_ids / audience_all_departments /
--       audience_department_ids. NULL "all" flag = not answered yet.
--       Old audience_ids (mixed list) is kept untouched and read-only in the app.
--   (b) Levels list: "New Hire" deactivated (not a rank; Sandra 18 Nov: no new-hire option). Kept for old records.
--   (c) One-time data move: programs tagged "All Employees" -> All levels + All departments;
--       "New Hires" -> All levels + All departments.
--   (d) New versions copy the audience from the version they replace (lp_start_new_version lists its columns,
--       so a BEFORE INSERT trigger fills them).
--   (e) lp_requirements: scope_source ('own' = older rule with its own list | 'audience' = from the program)
--       For 'audience' rules the database fills scope from the program family's governing
--       version (newest active, else newest version). Existing rules stay 'own' (Sandra 18 Nov: keep as is).
--   (f) When a program's audience changes (or a version is published), audience rules are refreshed.
--       On an APPROVED rule this is a major change (new rule number, applies from the next cycle because
--       cycles copy the rule when they open). Only admins may make it; others get a clear message.
--   (g) Publish check (preview only): new programs created on/after 2026-11-18 need Levels and Departments.
--   No employee data. Old audiences list stays for the checklist templates that use it.
-- Why:  Sandra 18 Nov: "separate the target audience and departments… target audience is more of a level";
--       levels = IC … Executive + All levels, All departments, no new-hire option; compliance applies to the audience only;
--       required to publish; existing rules kept; audience change on a published required program = major.
-- Date: 2026-11-18 · Approved by: Sandra Barlao (answers to questions 1–10, "I agree with your suggestions")
-- Rollback: supabase/rollback/20261118130000_lp_audience_levels_departments_ROLLBACK.sql
-- Release: remove is_preview_request() from lp_audience_on_activation and lp_requirements_before (guard).

-- (a) ───────────────────────────────────────────────────────────────────────
alter table public.learning_programs
  add column if not exists audience_all_levels      boolean,
  add column if not exists audience_level_ids       text[] not null default '{}'::text[],
  add column if not exists audience_all_departments boolean,
  add column if not exists audience_department_ids  text[] not null default '{}'::text[];

-- (b) ───────────────────────────────────────────────────────────────────────
update public.compliance_levels set is_active = false where id = 'lvl_nh' and is_active;

-- (c) ───────────────────────────────────────────────────────────────────────
update public.learning_programs lp
   set audience_all_levels = true, audience_all_departments = true
 where lp.audience_all_levels is null and lp.audience_all_departments is null
   and exists (select 1 from public.audiences a where a.id = any(lp.audience_ids) and a.name in ('All Employees','New Hires'));

-- (d) ───────────────────────────────────────────────────────────────────────
create or replace function public.lp_audience_before()
returns trigger language plpgsql security definer set search_path = '' as $$
declare pred public.learning_programs%rowtype;
begin
  if tg_op = 'INSERT' and new.supersedes_program_id is not null
     and new.audience_all_levels is null and new.audience_all_departments is null then
    select * into pred from public.learning_programs where id = new.supersedes_program_id;
    if found then
      new.audience_all_levels := pred.audience_all_levels; new.audience_level_ids := pred.audience_level_ids;
      new.audience_all_departments := pred.audience_all_departments; new.audience_department_ids := pred.audience_department_ids;
    end if;
  end if;
  if new.audience_all_levels then new.audience_level_ids := '{}'; end if;
  if new.audience_all_departments then new.audience_department_ids := '{}'; end if;
  new.audience_level_ids := coalesce(new.audience_level_ids, '{}'); new.audience_department_ids := coalesce(new.audience_department_ids, '{}');
  return new;
end;
$$;
revoke all on function public.lp_audience_before() from public, anon, authenticated;
drop trigger if exists trg_lp_audience_before on public.learning_programs;
create trigger trg_lp_audience_before before insert or update on public.learning_programs
  for each row execute function public.lp_audience_before();

-- (e) ───────────────────────────────────────────────────────────────────────
alter table public.lp_requirements
  add column if not exists scope_source   text not null default 'own';
alter table public.lp_requirements drop constraint if exists lp_requirements_scope_source_chk;
alter table public.lp_requirements add constraint lp_requirements_scope_source_chk check (scope_source in ('own','audience'));

-- The version whose audience governs the rule: newest active version, else the newest version.
create or replace function public.lp_family_audience(p_family text)
returns public.learning_programs language sql stable security definer set search_path = '' as $$
  select lp.* from public.learning_programs lp
   where coalesce(lp.program_family_id, lp.id) = p_family
   order by (lp.status = 'active') desc, lp.effective_from desc nulls last, lp.created_at desc
   limit 1;
$$;
revoke all on function public.lp_family_audience(text) from public, anon;
grant execute on function public.lp_family_audience(text) to authenticated;

create or replace function public.lp_requirements_before()
returns trigger language plpgsql set search_path = '' as $$
declare major boolean; minor boolean; approving boolean := coalesce(current_setting('leap.lp_req_approve', true), '') = '1';
        g public.learning_programs;
begin
  new.updated_at := now();
  new.updated_by := coalesce(auth.uid(), new.updated_by);
  -- v20261118130000: "Who must complete" = the program's target audience.
  if new.scope_source = 'audience' and new.required_type <> 'none' then
    g := public.lp_family_audience(new.program_family_id);
    if g.id is null or g.audience_all_levels is null or g.audience_all_departments is null
       or (not g.audience_all_levels and cardinality(g.audience_level_ids) = 0)
       or (not g.audience_all_departments and cardinality(g.audience_department_ids) = 0) then
      raise exception 'Set the program''s Target Audience (levels and departments) first. The requirement applies to that audience.' using errcode = '23514';
    end if;
    new.scope_kind := case when g.audience_all_levels and g.audience_all_departments then 'all'
                           when g.audience_all_levels then 'departments'
                           when g.audience_all_departments then 'levels'
                           else 'departments_levels' end;
    new.department_ids := case when g.audience_all_departments then '{}' else g.audience_department_ids end;
    new.level_ids := case when g.audience_all_levels then '{}' else g.audience_level_ids end;
  end if;
  if new.required_type = 'none' then
    new.scope_kind := null; new.department_ids := '{}'; new.level_ids := '{}'; new.recurrence_months := null;
    new.deadline_kind := null; new.deadline_mmdd := null; new.deadline_days := null;
  end if;
  if new.scope_kind = 'all' then new.department_ids := '{}'; new.level_ids := '{}'; end if;
  if new.scope_kind = 'departments' then new.level_ids := '{}'; end if;
  if new.scope_kind = 'levels' then new.department_ids := '{}'; end if;
  if new.deadline_kind = 'fixed_date' then new.deadline_days := null; end if;
  if new.deadline_kind = 'days_after_hire' then new.deadline_mmdd := null; end if;
  if tg_op = 'INSERT' then
    new.created_by := coalesce(auth.uid(), new.created_by);
    new.rule_no := 1; new.rule_rev := 0;
    if public.lp_family_has_active(new.program_family_id) then      -- added to an active program (admins only, by RLS)
      new.status := 'approved'; new.approved_by := auth.uid(); new.approved_at := now(); new.self_approved := true;
    else
      new.status := 'draft'; new.approved_by := null; new.approved_at := null; new.self_approved := false;
    end if;
    return new;
  end if;
  -- UPDATE: the database owns numbering and approval fields.
  new.id := old.id; new.program_family_id := old.program_family_id;
  new.created_at := old.created_at; new.created_by := old.created_by;
  if approving then                                              -- set only by the activation trigger
    new.rule_no := old.rule_no; new.rule_rev := old.rule_rev; return new;
  end if;
  new.rule_no := old.rule_no; new.rule_rev := old.rule_rev; new.status := old.status;
  new.approved_by := old.approved_by; new.approved_at := old.approved_at; new.self_approved := old.self_approved;
  if old.status = 'approved' then
    major := new.required_type is distinct from old.required_type or new.scope_kind is distinct from old.scope_kind
          or new.department_ids is distinct from old.department_ids or new.level_ids is distinct from old.level_ids
          or new.scope_source is distinct from old.scope_source
          or new.recurrence_months is distinct from old.recurrence_months or new.deadline_kind is distinct from old.deadline_kind
          or new.deadline_mmdd is distinct from old.deadline_mmdd or new.deadline_days is distinct from old.deadline_days;
    minor := new.owner_id is distinct from old.owner_id or new.notes is distinct from old.notes
          or new.completion_definition is distinct from old.completion_definition;
    -- Approved rules: admins only (RLS covers direct edits; this covers the audience refresh from a program save).
    if (major or minor) and auth.uid() is not null and public.is_preview_request() and not public.is_admin() then
      raise exception 'This program has an approved compliance requirement. Changing its Target Audience changes who must complete it, so only an admin can make this change.' using errcode = '42501';
    end if;
    if major then new.rule_no := old.rule_no + 1; new.rule_rev := 0;
    elsif minor then new.rule_rev := old.rule_rev + 1; end if;
    if major or minor then
      new.approved_by := auth.uid(); new.approved_at := now(); new.self_approved := true;
    end if;
  end if;
  return new;
end;
$$;

-- (f) ───────────────────────────────────────────────────────────────────────
create or replace function public.lp_audience_sync()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if row(new.audience_all_levels, new.audience_level_ids, new.audience_all_departments, new.audience_department_ids, new.status)
     is not distinct from
     row(old.audience_all_levels, old.audience_level_ids, old.audience_all_departments, old.audience_department_ids, old.status) then
    return null;
  end if;
  update public.lp_requirements set updated_at = now()
   where program_family_id = coalesce(new.program_family_id, new.id)
     and scope_source = 'audience' and required_type <> 'none';
  return null;
end;
$$;
revoke all on function public.lp_audience_sync() from public, anon, authenticated;
drop trigger if exists trg_lp_audience_sync on public.learning_programs;
create trigger trg_lp_audience_sync after update on public.learning_programs
  for each row execute function public.lp_audience_sync();

-- (g) ───────────────────────────────────────────────────────────────────────
create or replace function public.lp_audience_on_activation()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if not (old.status = 'draft' and new.status = 'active') then return new; end if;
  if public.is_preview_request() and new.supersedes_program_id is null
     and (new.created_at at time zone 'Asia/Manila')::date >= date '2026-11-18'
     and (new.audience_all_levels is null or new.audience_all_departments is null
          or (not new.audience_all_levels and cardinality(new.audience_level_ids) = 0)
          or (not new.audience_all_departments and cardinality(new.audience_department_ids) = 0)) then
    raise exception 'Set the Target Audience (levels and departments) before publishing this program.' using errcode = '23514';
  end if;
  return new;
end;
$$;
revoke all on function public.lp_audience_on_activation() from public, anon, authenticated;
drop trigger if exists trg_lp_audience_on_activation on public.learning_programs;
create trigger trg_lp_audience_on_activation before update of status on public.learning_programs
  for each row execute function public.lp_audience_on_activation();

insert into supabase_migrations.schema_migrations (version, name) values ('20261118130000', 'lp_audience_levels_departments') on conflict do nothing;
