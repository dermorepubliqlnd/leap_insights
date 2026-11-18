-- 20261118090000_compliance_p1_requirements
-- What (PREVIEW-GATED writes): Compliance Phase 1 (Assessment 05) — the compliance rule of a Learning Program.
--   (a) compliance_levels: clean list of levels for "who must complete" (seeded with 7 levels).
--   (b) lp_requirements: ONE rule per program family (survives new program versions). Required? (none /
--       mandatory / compliance), who must complete (all / departments / levels / departments + levels),
--       how often (one-time or every N months), deadline (fixed date each cycle or N days after hire),
--       completion definition, owner, notes. Rule number r<rule_no>.<rule_rev>; status draft / approved.
--       Draft programs: any program author may set it (status draft, r1.0).
--       The rule is APPROVED when the program is activated (interim approval = activation, decision E2).
--       After approval only admins may change it; the database classifies the change:
--         major (type / who / how often / deadline rule) -> r(n+1).0 ; minor (owner / notes / definition) -> rn.(m+1).
--       Admin changes are approved at once and marked self-approved (decision E8: top of the chain auto-approves).
--   (c) lp_requirement_events: append-only history written by the database (who, when, what, snapshot).
--   (d) Activation check (preview only): a NEW program (first version created on/after 2026-11-18) cannot be
--       activated until "Required?" is answered. Existing programs and their new versions are grandfathered.
--   No employee data is stored anywhere.
-- Why:   Assessment 05 decisions E1 (all delivery types), E2, E4, E6 (levels list), E8. Phase 1 = rule only;
--        cycles and counts come in Phase 2.
-- Date:  2026-11-18 · Approved by: Sandra Barlao ("ok" to build Phase 1 on Preview)
-- Rollback: supabase/rollback/20261118090000_compliance_p1_requirements_ROLLBACK.sql
-- Release: remove the is_preview_request() checks (policies + activation check).

-- (a) ───────────────────────────────────────────────────────────────────────────────────────────
create table if not exists public.compliance_levels (
  id         text primary key,
  name       text not null unique check (char_length(name) between 1 and 80),
  sort_order integer not null default 0,
  is_active  boolean not null default true,
  created_at timestamptz not null default now()
);
insert into public.compliance_levels (id, name, sort_order) values
  ('lvl_ic','Individual Contributor',10), ('lvl_jl','Junior Leader',20), ('lvl_sup','Supervisor / Team Leader',30),
  ('lvl_mgr','Manager',40), ('lvl_sl','Senior Leader',50), ('lvl_exec','Executive',60), ('lvl_nh','New Hire',70)
on conflict (id) do nothing;
alter table public.compliance_levels enable row level security;
drop policy if exists compliance_levels_select on public.compliance_levels;
create policy compliance_levels_select on public.compliance_levels for select to authenticated using (true);
drop policy if exists compliance_levels_write on public.compliance_levels;
create policy compliance_levels_write on public.compliance_levels for all to authenticated
  using (public.is_preview_request() and public.is_admin()) with check (public.is_preview_request() and public.is_admin());
grant select, insert, update, delete on public.compliance_levels to authenticated;

-- (b) ───────────────────────────────────────────────────────────────────────────────────────────
create table if not exists public.lp_requirements (
  id                    text primary key default gen_random_uuid()::text,
  program_family_id     text not null unique references public.learning_programs(id) on delete cascade,
  required_type         text not null check (required_type in ('none','mandatory','compliance')),
  scope_kind            text check (scope_kind in ('all','departments','levels','departments_levels')),
  department_ids        text[] not null default '{}'::text[],
  level_ids             text[] not null default '{}'::text[],
  recurrence_months     integer check (recurrence_months between 1 and 60),
  deadline_kind         text check (deadline_kind in ('fixed_date','days_after_hire')),
  deadline_mmdd         text check (deadline_mmdd ~ '^(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$'),
  deadline_days         integer check (deadline_days between 1 and 365),
  completion_definition text check (char_length(completion_definition) <= 500),
  owner_id              uuid references public.profiles(id),
  notes                 text check (char_length(notes) <= 500),
  rule_no               integer not null default 1,
  rule_rev              integer not null default 0,
  status                text not null default 'draft' check (status in ('draft','approved')),
  approved_by           uuid,
  approved_at           timestamptz,
  self_approved         boolean not null default false,
  created_at            timestamptz not null default now(),
  created_by            uuid default auth.uid(),
  updated_at            timestamptz not null default now(),
  updated_by            uuid,
  constraint lp_requirements_complete check (
    required_type = 'none' or (
      scope_kind is not null and deadline_kind is not null and owner_id is not null
      and (deadline_kind <> 'fixed_date' or deadline_mmdd is not null)
      and (deadline_kind <> 'days_after_hire' or deadline_days is not null)
      and (scope_kind not in ('departments','departments_levels') or cardinality(department_ids) > 0)
      and (scope_kind not in ('levels','departments_levels') or cardinality(level_ids) > 0)
    ))
);

create table if not exists public.lp_requirement_events (
  id                text primary key default gen_random_uuid()::text,
  requirement_id    text not null,
  program_family_id text not null,
  action            text not null,   -- created / edited / approved_with_program / minor_change / major_change / deleted
  rule_label        text,            -- e.g. r1.0, r2.0
  snapshot          jsonb not null,
  actor_id          uuid,
  actor_name        text,
  at                timestamptz not null default now()
);
create index if not exists lp_requirement_events_family on public.lp_requirement_events (program_family_id, at desc);

-- Is any version of this program family active?
create or replace function public.lp_family_has_active(p_family text)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.learning_programs lp
                 where coalesce(lp.program_family_id, lp.id) = p_family and lp.status = 'active');
$$;
revoke all on function public.lp_family_has_active(text) from public, anon;
grant execute on function public.lp_family_has_active(text) to authenticated;

create or replace function public.lp_requirements_before()
returns trigger language plpgsql set search_path = '' as $$
declare major boolean; minor boolean; approving boolean := coalesce(current_setting('leap.lp_req_approve', true), '') = '1';
begin
  new.updated_at := now();
  new.updated_by := coalesce(auth.uid(), new.updated_by);
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
          or new.recurrence_months is distinct from old.recurrence_months or new.deadline_kind is distinct from old.deadline_kind
          or new.deadline_mmdd is distinct from old.deadline_mmdd or new.deadline_days is distinct from old.deadline_days;
    minor := new.owner_id is distinct from old.owner_id or new.notes is distinct from old.notes
          or new.completion_definition is distinct from old.completion_definition;
    if major then new.rule_no := old.rule_no + 1; new.rule_rev := 0;
    elsif minor then new.rule_rev := old.rule_rev + 1; end if;
    if major or minor then
      new.approved_by := auth.uid(); new.approved_at := now(); new.self_approved := true;
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists trg_lp_requirements_before on public.lp_requirements;
create trigger trg_lp_requirements_before before insert or update on public.lp_requirements
  for each row execute function public.lp_requirements_before();

create or replace function public.lp_requirements_after()
returns trigger language plpgsql security definer set search_path = '' as $$
declare act text; r public.lp_requirements%rowtype; nm text; strip text[] := array['updated_at','updated_by'];
begin
  if tg_op = 'DELETE' then r := old; act := 'deleted';
  else
    r := new;
    if tg_op = 'INSERT' then act := 'created';
    elsif new.status = 'approved' and old.status = 'draft' then act := 'approved_with_program';
    elsif new.rule_no > old.rule_no then act := 'major_change';
    elsif new.rule_rev > old.rule_rev then act := 'minor_change';
    elsif (to_jsonb(new) - strip) = (to_jsonb(old) - strip) then return null;   -- nothing changed
    else act := 'edited'; end if;
  end if;
  select nullif(btrim(coalesce(p.first_name, '') || ' ' || coalesce(p.last_name, '')), '') into nm
    from public.profiles p where p.id = auth.uid();
  insert into public.lp_requirement_events (requirement_id, program_family_id, action, rule_label, snapshot, actor_id, actor_name)
  values (r.id, r.program_family_id, act, 'r' || r.rule_no || '.' || r.rule_rev, to_jsonb(r), auth.uid(), nm);
  return null;
end;
$$;
revoke all on function public.lp_requirements_after() from public, anon, authenticated;
drop trigger if exists trg_lp_requirements_after on public.lp_requirements;
create trigger trg_lp_requirements_after after insert or update or delete on public.lp_requirements
  for each row execute function public.lp_requirements_after();

alter table public.lp_requirements enable row level security;
drop policy if exists lp_requirements_select on public.lp_requirements;
create policy lp_requirements_select on public.lp_requirements for select to authenticated using (true);
drop policy if exists lp_requirements_insert on public.lp_requirements;
create policy lp_requirements_insert on public.lp_requirements for insert to authenticated
  with check (public.is_preview_request() and (public.is_admin() or not public.lp_family_has_active(program_family_id)));
drop policy if exists lp_requirements_update on public.lp_requirements;
create policy lp_requirements_update on public.lp_requirements for update to authenticated
  using (public.is_preview_request() and (public.is_admin() or (status = 'draft' and not public.lp_family_has_active(program_family_id))))
  with check (public.is_preview_request() and (public.is_admin() or (status = 'draft' and not public.lp_family_has_active(program_family_id))));
drop policy if exists lp_requirements_delete on public.lp_requirements;
create policy lp_requirements_delete on public.lp_requirements for delete to authenticated
  using (public.is_preview_request() and public.is_admin());
grant select, insert, update, delete on public.lp_requirements to authenticated;

alter table public.lp_requirement_events enable row level security;
drop policy if exists lp_requirement_events_select on public.lp_requirement_events;
create policy lp_requirement_events_select on public.lp_requirement_events for select to authenticated using (true);
grant select on public.lp_requirement_events to authenticated;   -- no insert/update/delete for users: written by the trigger only

-- (d) ───────────────────────────────────────────────────────────────────────────────────────────
create or replace function public.lp_requirement_on_activation()
returns trigger language plpgsql security definer set search_path = '' as $$
declare fam text := coalesce(new.program_family_id, new.id); rq public.lp_requirements%rowtype;
begin
  if not (old.status = 'draft' and new.status = 'active') then return new; end if;
  select * into rq from public.lp_requirements where program_family_id = fam;
  if not found then
    if public.is_preview_request() and new.supersedes_program_id is null
       and (new.created_at at time zone 'Asia/Manila')::date >= date '2026-11-18' then
      raise exception 'Answer "Required?" in the Compliance Requirement section before activating this program.' using errcode = '23514';
    end if;
    return new;
  end if;
  if rq.status = 'draft' then                                    -- interim approval = activation (E2)
    perform set_config('leap.lp_req_approve', '1', true);
    update public.lp_requirements
       set status = 'approved', approved_by = auth.uid(), approved_at = now(),
           self_approved = (auth.uid() is not distinct from rq.updated_by)
     where id = rq.id;
    perform set_config('leap.lp_req_approve', '', true);
  end if;
  return new;
end;
$$;
revoke all on function public.lp_requirement_on_activation() from public, anon, authenticated;
drop trigger if exists trg_lp_requirement_on_activation on public.learning_programs;
create trigger trg_lp_requirement_on_activation before update of status on public.learning_programs
  for each row execute function public.lp_requirement_on_activation();

-- Record:
-- insert into supabase_migrations.schema_migrations (version, name) values ('20261118090000', 'compliance_p1_requirements');
