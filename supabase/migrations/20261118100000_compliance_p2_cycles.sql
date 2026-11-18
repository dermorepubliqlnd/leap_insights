-- 20261118100000_compliance_p2_cycles
-- What (PREVIEW-GATED writes): Compliance Phase 2 (Assessment 05) — completion tracking by cycle, counts only.
--   compliance_cycles      one period of a program's compliance rule (e.g. GMP 2027): dates, deadline, target %,
--                          status planned -> open -> closed -> finalized (or cancelled); rule copied when opened.
--   compliance_lines       one row per department in a cycle; original required headcount, locked once open.
--   compliance_updates     a dated progress update (as-of date + source, e.g. Litmos report). Append-only.
--   compliance_snapshots   the counts in an update per department (completed, exempt). Append-only.
--   compliance_adjustments headcount changes after opening: previous -> revised + reason. Auto-approved when
--                          within 5% of the original and before the deadline, or when the requester has no one
--                          above them (E8); otherwise waits for an admin who is not the requester.
--   compliance_events      history written by the database only.
--   No employee names or IDs anywhere.
-- Who: view = all signed-in users. Updates + adjustment requests = admin or the rule owner.
--      Open / close / finalize / cancel / reopen / deadline change / headcounts before opening = admin.
-- Why:  Sandra 18 Nov ("perfect please render in preview" after the mockup); defaults E3 (any version active in
--       the cycle counts), E5 (rule changes from next cycle; the cycle keeps its copy), E7 (HR headcount at open),
--       E9 (groups under 5 hidden in the app), E4 (deadline change needs approval -> admin + reason, logged).
-- Date: 2026-11-18 · Approved by: Sandra Barlao
-- Rollback: supabase/rollback/20261118100000_compliance_p2_cycles_ROLLBACK.sql
-- Release: remove the is_preview_request() checks in the policies.

create table if not exists public.compliance_cycles (
  id               text primary key default gen_random_uuid()::text,
  code             text not null unique,
  name             text not null check (char_length(name) between 1 and 80),
  requirement_id   text not null references public.lp_requirements(id) on delete restrict,
  program_family_id text not null,
  rule_label       text,
  rule_snapshot    jsonb,
  period_start     date not null,
  period_end       date not null,
  deadline         date not null,
  target_pct       numeric(5,2) not null default 95 check (target_pct > 0 and target_pct <= 100),
  status           text not null default 'planned' check (status in ('planned','open','closed','finalized','cancelled')),
  status_reason    text check (char_length(status_reason) <= 500),
  notes            text check (char_length(notes) <= 500),
  opened_at timestamptz, opened_by uuid, closed_at timestamptz, closed_by uuid, finalized_at timestamptz, finalized_by uuid,
  created_at timestamptz not null default now(), created_by uuid default auth.uid(),
  updated_at timestamptz not null default now(), updated_by uuid,
  constraint compliance_cycles_dates check (period_end >= period_start and deadline >= period_start)
);
create index if not exists compliance_cycles_family on public.compliance_cycles (program_family_id);

create table if not exists public.compliance_lines (
  id                text primary key default gen_random_uuid()::text,
  cycle_id          text not null references public.compliance_cycles(id) on delete cascade,
  department_id     text not null,
  original_required integer not null default 0 check (original_required >= 0),
  sort_order        integer not null default 0,
  created_at        timestamptz not null default now(),
  unique (cycle_id, department_id)
);

create table if not exists public.compliance_updates (
  id          text primary key default gen_random_uuid()::text,
  cycle_id    text not null references public.compliance_cycles(id) on delete cascade,
  as_of       date not null,
  source      text not null check (source in ('litmos','hr','attendance','manual','historical','other')),
  note        text check (char_length(note) <= 500),
  entered_by  uuid default auth.uid(),
  entered_at  timestamptz not null default now()
);

create table if not exists public.compliance_snapshots (
  id         text primary key default gen_random_uuid()::text,
  update_id  text not null references public.compliance_updates(id) on delete cascade,
  cycle_id   text not null references public.compliance_cycles(id) on delete cascade,
  line_id    text not null references public.compliance_lines(id) on delete cascade,
  completed  integer not null check (completed >= 0),
  exempt     integer not null default 0 check (exempt >= 0),
  unique (update_id, line_id)
);

create table if not exists public.compliance_adjustments (
  id            text primary key default gen_random_uuid()::text,
  cycle_id      text not null references public.compliance_cycles(id) on delete cascade,
  line_id       text not null references public.compliance_lines(id) on delete cascade,
  previous_required integer not null check (previous_required >= 0),
  revised_required  integer not null check (revised_required >= 0),
  reason_code   text not null check (reason_code in ('left','joined','transfer_out','transfer_in','correction','rule_change','other')),
  note          text check (char_length(note) <= 500),
  status        text not null default 'pending' check (status in ('pending','approved','returned')),
  requested_by  uuid default auth.uid(),
  requested_at  timestamptz not null default now(),
  decided_by    uuid,
  decided_at    timestamptz,
  decision_note text check (char_length(decision_note) <= 500),
  self_approved boolean not null default false
);

create table if not exists public.compliance_events (
  id        text primary key default gen_random_uuid()::text,
  cycle_id  text not null,
  action    text not null,
  detail    text,
  actor_id  uuid,
  actor_name text,
  at        timestamptz not null default now()
);
create index if not exists compliance_events_cycle on public.compliance_events (cycle_id, at desc);

-- ── helpers ────────────────────────────────────────────────────────────────────────────────────
create or replace function public.comp_actor_name()
returns text language sql stable security definer set search_path = '' as $$
  select nullif(btrim(coalesce(p.first_name,'') || ' ' || coalesce(p.last_name,'')), '') from public.profiles p where p.id = auth.uid();
$$;
create or replace function public.comp_log(p_cycle text, p_action text, p_detail text)
returns void language sql security definer set search_path = '' as $$
  insert into public.compliance_events (cycle_id, action, detail, actor_id, actor_name)
  values (p_cycle, p_action, p_detail, auth.uid(), public.comp_actor_name());
$$;
revoke all on function public.comp_log(text,text,text) from public, anon, authenticated;
-- Admin, or the owner named on the cycle's rule.
create or replace function public.comp_can_update(p_cycle text)
returns boolean language sql stable security definer set search_path = '' as $$
  select public.is_admin() or exists (
    select 1 from public.compliance_cycles c join public.lp_requirements r on r.id = c.requirement_id
     where c.id = p_cycle and r.owner_id = auth.uid());
$$;
-- Nobody above this person in the reporting line (decision E8).
create or replace function public.comp_is_top()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.profiles p where p.id = auth.uid() and p.supervisor_id is null and p.is_active);
$$;
grant execute on function public.comp_can_update(text), public.comp_is_top(), public.comp_actor_name() to authenticated;

-- Current required headcount of a line = latest approved adjustment, else the original.
create or replace function public.comp_line_required(p_line text)
returns integer language sql stable security definer set search_path = '' as $$
  select coalesce((select a.revised_required from public.compliance_adjustments a
                    where a.line_id = p_line and a.status = 'approved' order by a.decided_at desc nulls last, a.requested_at desc limit 1),
                  (select l.original_required from public.compliance_lines l where l.id = p_line));
$$;
grant execute on function public.comp_line_required(text) to authenticated;

-- ── cycles ─────────────────────────────────────────────────────────────────────────────────────
create or replace function public.compliance_cycles_guard()
returns trigger language plpgsql security definer set search_path = '' as $$
declare rq public.lp_requirements%rowtype;
begin
  new.updated_at := now(); new.updated_by := auth.uid();
  if tg_op = 'INSERT' then
    select * into rq from public.lp_requirements where id = new.requirement_id;
    if not found or rq.status <> 'approved' or rq.required_type = 'none' then
      raise exception 'A cycle needs an approved Mandatory or Compliance rule on the program.' using errcode = '23514';
    end if;
    new.program_family_id := rq.program_family_id;
    new.status := 'planned'; new.created_by := coalesce(auth.uid(), new.created_by);
    new.rule_label := 'r' || rq.rule_no || '.' || rq.rule_rev; new.rule_snapshot := to_jsonb(rq);
    return new;
  end if;
  -- UPDATE
  new.id := old.id; new.requirement_id := old.requirement_id; new.program_family_id := old.program_family_id;
  new.created_at := old.created_at; new.created_by := old.created_by; new.code := old.code;
  if old.status = 'finalized' then raise exception 'This cycle is finalized and locked.' using errcode = '42501'; end if;
  if old.status = 'cancelled' then raise exception 'This cycle is cancelled.' using errcode = '42501'; end if;
  if new.status is distinct from old.status then
    if not ((old.status = 'planned' and new.status in ('open','cancelled'))
         or (old.status = 'open' and new.status in ('closed','cancelled'))
         or (old.status = 'closed' and new.status in ('finalized','open'))) then
      raise exception 'A cycle cannot move from % to %.', old.status, new.status using errcode = '23514';
    end if;
    if new.status in ('cancelled') or (old.status = 'closed' and new.status = 'open') then
      if coalesce(btrim(new.status_reason),'') = '' or new.status_reason is not distinct from old.status_reason then
        raise exception 'Give a reason.' using errcode = '23514';
      end if;
    end if;
    if new.status = 'open' and old.status = 'planned' then
      if not exists (select 1 from public.compliance_lines where cycle_id = old.id) then
        raise exception 'Add at least one department before opening the cycle.' using errcode = '23514';
      end if;
      select * into rq from public.lp_requirements where id = old.requirement_id;   -- copy the rule as it is today (E5)
      new.rule_label := 'r' || rq.rule_no || '.' || rq.rule_rev; new.rule_snapshot := to_jsonb(rq);
      new.opened_at := now(); new.opened_by := auth.uid();
    end if;
    if new.status = 'closed' then new.closed_at := now(); new.closed_by := auth.uid(); end if;
    if new.status = 'finalized' then new.finalized_at := now(); new.finalized_by := auth.uid(); end if;
    if new.status = 'open' and old.status = 'closed' then new.closed_at := null; new.closed_by := null; end if;
  else
    new.rule_label := old.rule_label; new.rule_snapshot := old.rule_snapshot;
    new.opened_at := old.opened_at; new.opened_by := old.opened_by; new.closed_at := old.closed_at; new.closed_by := old.closed_by;
    new.finalized_at := old.finalized_at; new.finalized_by := old.finalized_by;
  end if;
  if old.status <> 'planned' and (new.period_start is distinct from old.period_start or new.period_end is distinct from old.period_end or new.target_pct is distinct from old.target_pct) then
    raise exception 'Cycle dates and target are locked once the cycle is open.' using errcode = '23514';
  end if;
  if old.status <> 'planned' and new.deadline is distinct from old.deadline then             -- E4: deadline change after opening
    if coalesce(btrim(new.status_reason),'') = '' or new.status_reason is not distinct from old.status_reason then
      raise exception 'Give a reason for changing the deadline.' using errcode = '23514';
    end if;
  end if;
  return new;
end;
$$;
drop trigger if exists trg_compliance_cycles_guard on public.compliance_cycles;
create trigger trg_compliance_cycles_guard before insert or update on public.compliance_cycles
  for each row execute function public.compliance_cycles_guard();

create or replace function public.compliance_cycles_log()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' then perform public.comp_log(new.id, 'created', new.name || ' planned: ' || new.period_start || ' to ' || new.period_end || ', deadline ' || new.deadline);
  else
    if new.status is distinct from old.status then
      perform public.comp_log(new.id, new.status, case when new.status = 'open' and old.status = 'planned' then 'Opened under rule ' || coalesce(new.rule_label,'')
                                                      when new.status = 'open' then 'Reopened: ' || coalesce(new.status_reason,'')
                                                      when new.status = 'cancelled' then 'Cancelled: ' || coalesce(new.status_reason,'')
                                                      else initcap(new.status) end);
    end if;
    if new.deadline is distinct from old.deadline then
      perform public.comp_log(new.id, 'deadline_changed', 'Deadline ' || old.deadline || ' -> ' || new.deadline || coalesce(' · ' || nullif(new.status_reason, old.status_reason), '') ||
        case when old.status <> 'planned' and public.comp_is_top() then ' (self-approved)' else '' end);
    end if;
    if old.status = 'planned' and (new.period_start, new.period_end, new.target_pct, new.name) is distinct from (old.period_start, old.period_end, old.target_pct, old.name) then
      perform public.comp_log(new.id, 'edited', 'Cycle details edited before opening');
    end if;
  end if;
  return null;
end;
$$;
drop trigger if exists trg_compliance_cycles_log on public.compliance_cycles;
create trigger trg_compliance_cycles_log after insert or update on public.compliance_cycles
  for each row execute function public.compliance_cycles_log();

-- ── lines (departments) ────────────────────────────────────────────────────────────────────────
create or replace function public.compliance_lines_guard()
returns trigger language plpgsql security definer set search_path = '' as $$
declare st text;
begin
  select status into st from public.compliance_cycles where id = coalesce(new.cycle_id, old.cycle_id);
  if st is distinct from 'planned' then
    raise exception 'Departments and starting headcounts are locked once the cycle is open. Use Adjust headcount.' using errcode = '23514';
  end if;
  if tg_op = 'UPDATE' then new.id := old.id; new.cycle_id := old.cycle_id; end if;
  return coalesce(new, old);
end;
$$;
drop trigger if exists trg_compliance_lines_guard on public.compliance_lines;
create trigger trg_compliance_lines_guard before insert or update or delete on public.compliance_lines
  for each row execute function public.compliance_lines_guard();

-- ── updates + snapshots ────────────────────────────────────────────────────────────────────────
create or replace function public.compliance_updates_guard()
returns trigger language plpgsql security definer set search_path = '' as $$
declare c public.compliance_cycles%rowtype; today date := (now() at time zone 'Asia/Manila')::date;
begin
  select * into c from public.compliance_cycles where id = new.cycle_id;
  if c.status <> 'open' then raise exception 'Updates can only be added while the cycle is open.' using errcode = '23514'; end if;
  if new.as_of > today then raise exception 'The as-of date cannot be in the future.' using errcode = '23514'; end if;
  if new.as_of < c.period_start then raise exception 'The as-of date is before the cycle started.' using errcode = '23514'; end if;
  new.entered_by := auth.uid(); new.entered_at := now();
  return new;
end;
$$;
drop trigger if exists trg_compliance_updates_guard on public.compliance_updates;
create trigger trg_compliance_updates_guard before insert on public.compliance_updates
  for each row execute function public.compliance_updates_guard();

create or replace function public.compliance_snapshots_guard()
returns trigger language plpgsql security definer set search_path = '' as $$
declare req integer; u public.compliance_updates%rowtype; ln public.compliance_lines%rowtype;
begin
  select * into u from public.compliance_updates where id = new.update_id;
  select * into ln from public.compliance_lines where id = new.line_id;
  if u.cycle_id is distinct from ln.cycle_id then raise exception 'Department does not belong to this cycle.' using errcode = '23514'; end if;
  new.cycle_id := u.cycle_id;
  req := public.comp_line_required(new.line_id);
  if new.completed + new.exempt > req then
    raise exception 'Completed + exempt (%) is more than the required headcount (%) for a department. Adjust the headcount first.', new.completed + new.exempt, req using errcode = '23514';
  end if;
  return new;
end;
$$;
drop trigger if exists trg_compliance_snapshots_guard on public.compliance_snapshots;
create trigger trg_compliance_snapshots_guard before insert on public.compliance_snapshots
  for each row execute function public.compliance_snapshots_guard();

create or replace function public.compliance_updates_log()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform public.comp_log(new.cycle_id, 'update', 'Progress update as of ' || new.as_of || ' (' || new.source || ')');
  return null;
end;
$$;
drop trigger if exists trg_compliance_updates_log on public.compliance_updates;
create trigger trg_compliance_updates_log after insert on public.compliance_updates
  for each row execute function public.compliance_updates_log();

-- ── adjustments ────────────────────────────────────────────────────────────────────────────────
create or replace function public.compliance_adjustments_guard()
returns trigger language plpgsql security definer set search_path = '' as $$
declare c public.compliance_cycles%rowtype; ln public.compliance_lines%rowtype; today date := (now() at time zone 'Asia/Manila')::date; small boolean;
begin
  select * into c from public.compliance_cycles where id = coalesce(new.cycle_id, old.cycle_id);
  if tg_op = 'INSERT' then
    select * into ln from public.compliance_lines where id = new.line_id;
    if ln.cycle_id is distinct from new.cycle_id then raise exception 'Department does not belong to this cycle.' using errcode = '23514'; end if;
    if c.status <> 'open' then raise exception 'Headcount can only be adjusted while the cycle is open.' using errcode = '23514'; end if;
    if exists (select 1 from public.compliance_adjustments where line_id = new.line_id and status = 'pending') then
      raise exception 'This department already has a headcount change waiting for approval.' using errcode = '23514';
    end if;
    new.previous_required := public.comp_line_required(new.line_id);
    if new.revised_required = new.previous_required then raise exception 'The new headcount is the same as the current one.' using errcode = '23514'; end if;
    new.requested_by := auth.uid(); new.requested_at := clock_timestamp();
    small := abs(new.revised_required - ln.original_required) <= greatest(1, round(ln.original_required * 0.05)) and today <= c.deadline;
    if small or public.comp_is_top() then
      new.status := 'approved'; new.decided_by := auth.uid(); new.decided_at := clock_timestamp(); new.self_approved := true;
    else
      new.status := 'pending'; new.decided_by := null; new.decided_at := null; new.self_approved := false;
    end if;
    return new;
  end if;
  -- UPDATE = a decision on a pending request
  if old.status <> 'pending' then raise exception 'This headcount change was already decided.' using errcode = '23514'; end if;
  if new.status not in ('approved','returned') then raise exception 'Approve or return the request.' using errcode = '23514'; end if;
  if old.requested_by = auth.uid() then raise exception 'You cannot approve your own headcount change.' using errcode = '42501'; end if;
  if new.status = 'returned' and coalesce(btrim(new.decision_note),'') = '' then raise exception 'Give a reason for returning it.' using errcode = '23514'; end if;
  new.id := old.id; new.cycle_id := old.cycle_id; new.line_id := old.line_id; new.previous_required := old.previous_required;
  new.revised_required := old.revised_required; new.reason_code := old.reason_code; new.note := old.note;
  new.requested_by := old.requested_by; new.requested_at := old.requested_at;
  new.decided_by := auth.uid(); new.decided_at := clock_timestamp(); new.self_approved := false;
  return new;
end;
$$;
drop trigger if exists trg_compliance_adjustments_guard on public.compliance_adjustments;
create trigger trg_compliance_adjustments_guard before insert or update on public.compliance_adjustments
  for each row execute function public.compliance_adjustments_guard();

create or replace function public.compliance_adjustments_log()
returns trigger language plpgsql security definer set search_path = '' as $$
declare dn text;
begin
  select name into dn from public.departments where id = (select department_id from public.compliance_lines where id = new.line_id);
  if tg_op = 'INSERT' then
    perform public.comp_log(new.cycle_id, 'adjustment', coalesce(dn,'Department') || ': ' || new.previous_required || ' -> ' || new.revised_required || ' (' || new.reason_code || ')' ||
      case when new.status = 'approved' then case when new.self_approved and public.comp_is_top() then ' · self-approved' else ' · approved (within 5%)' end else ' · waiting for approval' end);
  elsif new.status is distinct from old.status then
    perform public.comp_log(new.cycle_id, 'adjustment_' || new.status, coalesce(dn,'Department') || ': ' || new.previous_required || ' -> ' || new.revised_required || coalesce(' · ' || new.decision_note, ''));
  end if;
  return null;
end;
$$;
drop trigger if exists trg_compliance_adjustments_log on public.compliance_adjustments;
create trigger trg_compliance_adjustments_log after insert or update on public.compliance_adjustments
  for each row execute function public.compliance_adjustments_log();

-- ── row-level security ─────────────────────────────────────────────────────────────────────────
alter table public.compliance_cycles enable row level security;
alter table public.compliance_lines enable row level security;
alter table public.compliance_updates enable row level security;
alter table public.compliance_snapshots enable row level security;
alter table public.compliance_adjustments enable row level security;
alter table public.compliance_events enable row level security;

drop policy if exists cc_select on public.compliance_cycles;  create policy cc_select on public.compliance_cycles for select to authenticated using (true);
drop policy if exists cc_insert on public.compliance_cycles;  create policy cc_insert on public.compliance_cycles for insert to authenticated with check (public.is_preview_request() and public.is_admin());
drop policy if exists cc_update on public.compliance_cycles;  create policy cc_update on public.compliance_cycles for update to authenticated using (public.is_preview_request() and public.is_admin()) with check (public.is_preview_request() and public.is_admin());
drop policy if exists cc_delete on public.compliance_cycles;  create policy cc_delete on public.compliance_cycles for delete to authenticated using (public.is_preview_request() and public.is_admin() and status = 'planned');

drop policy if exists cl_select on public.compliance_lines;   create policy cl_select on public.compliance_lines for select to authenticated using (true);
drop policy if exists cl_write on public.compliance_lines;    create policy cl_write on public.compliance_lines for all to authenticated using (public.is_preview_request() and public.is_admin()) with check (public.is_preview_request() and public.is_admin());

drop policy if exists cu_select on public.compliance_updates; create policy cu_select on public.compliance_updates for select to authenticated using (true);
drop policy if exists cu_insert on public.compliance_updates; create policy cu_insert on public.compliance_updates for insert to authenticated with check (public.is_preview_request() and public.comp_can_update(cycle_id));

drop policy if exists cs_select on public.compliance_snapshots; create policy cs_select on public.compliance_snapshots for select to authenticated using (true);
drop policy if exists cs_insert on public.compliance_snapshots; create policy cs_insert on public.compliance_snapshots for insert to authenticated
  with check (public.is_preview_request() and exists (select 1 from public.compliance_updates u where u.id = update_id and u.entered_by = auth.uid() and u.entered_at > now() - interval '10 minutes'));

drop policy if exists ca_select on public.compliance_adjustments; create policy ca_select on public.compliance_adjustments for select to authenticated using (true);
drop policy if exists ca_insert on public.compliance_adjustments; create policy ca_insert on public.compliance_adjustments for insert to authenticated with check (public.is_preview_request() and public.comp_can_update(cycle_id));
drop policy if exists ca_update on public.compliance_adjustments; create policy ca_update on public.compliance_adjustments for update to authenticated using (public.is_preview_request() and public.is_admin()) with check (public.is_preview_request() and public.is_admin());

drop policy if exists ce_select on public.compliance_events;  create policy ce_select on public.compliance_events for select to authenticated using (true);

grant select, insert, update, delete on public.compliance_cycles, public.compliance_lines to authenticated;
grant select, insert on public.compliance_updates, public.compliance_snapshots, public.compliance_adjustments to authenticated;
grant update on public.compliance_adjustments to authenticated;
grant select on public.compliance_events to authenticated;

-- Record:
-- insert into supabase_migrations.schema_migrations (version, name) values ('20261118100000', 'compliance_p2_cycles');
