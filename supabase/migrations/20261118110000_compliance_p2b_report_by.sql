-- 20261118110000_compliance_p2b_report_by
-- What (PREVIEW-GATED writes, via the existing policies): Compliance Phase 2b.
--   (a) Each cycle reports by ONE grouping chosen when it is planned: department (from Settings), cluster
--       (per chief) or immediate supervisor. compliance_cycles.report_by; locked once the cycle is open.
--   (b) compliance_lines: department_id becomes optional; group_label holds the cluster or supervisor name
--       (group labels only; still no employee data). One line per department / label per cycle.
--   (c) On-leave follow-up: compliance_cycles.followup_note / followup_done_at / followup_done_by. Can be
--       written on closed and finalized cycles (only these fields); logged in the cycle history.
-- Why:  Sandra 18 Nov: "we do reporting per cluster, per department, and per leader"; "have a note that we need
--       to revisit those who were on leave and got back after the deadline".
-- Date: 2026-11-18 · Approved by: Sandra Barlao
-- Rollback: supabase/rollback/20261118110000_compliance_p2b_report_by_ROLLBACK.sql

alter table public.compliance_cycles add column if not exists report_by text not null default 'department';
alter table public.compliance_cycles drop constraint if exists compliance_cycles_report_by_check;
alter table public.compliance_cycles add constraint compliance_cycles_report_by_check check (report_by in ('department','cluster','supervisor'));
alter table public.compliance_cycles add column if not exists followup_note text;
alter table public.compliance_cycles drop constraint if exists compliance_cycles_followup_note_len;
alter table public.compliance_cycles add constraint compliance_cycles_followup_note_len check (char_length(followup_note) <= 500);
alter table public.compliance_cycles add column if not exists followup_done_at timestamptz;
alter table public.compliance_cycles add column if not exists followup_done_by uuid;

alter table public.compliance_lines alter column department_id drop not null;
alter table public.compliance_lines add column if not exists group_label text;
alter table public.compliance_lines drop constraint if exists compliance_lines_group_label_len;
alter table public.compliance_lines add constraint compliance_lines_group_label_len check (group_label is null or char_length(btrim(group_label)) between 1 and 120);
alter table public.compliance_lines drop constraint if exists compliance_lines_has_group;
alter table public.compliance_lines add constraint compliance_lines_has_group check (department_id is not null or group_label is not null);
alter table public.compliance_lines drop constraint if exists compliance_lines_cycle_id_department_id_key;
create unique index if not exists compliance_lines_one_group on public.compliance_lines (cycle_id, coalesce(department_id,''), lower(coalesce(btrim(group_label),'')));

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
  -- v5.19y: the on-leave follow-up note can be recorded on closed and finalized cycles; nothing else changes.
  if old.status in ('closed','finalized') and new.status = old.status
     and (to_jsonb(new) - array['followup_note','followup_done_at','followup_done_by','updated_at','updated_by'])
       = (to_jsonb(old) - array['followup_note','followup_done_at','followup_done_by','updated_at','updated_by']) then
    if new.followup_done_at is distinct from old.followup_done_at then new.followup_done_by := case when new.followup_done_at is null then null else auth.uid() end; end if;
    return new;
  end if;
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
        raise exception 'Add at least one group before opening the cycle.' using errcode = '23514';
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
  if old.status <> 'planned' and (new.period_start is distinct from old.period_start or new.period_end is distinct from old.period_end or new.target_pct is distinct from old.target_pct or new.report_by is distinct from old.report_by) then
    raise exception 'Cycle dates, target and reporting group are locked once the cycle is open.' using errcode = '23514';
  end if;
  if old.status <> 'planned' and new.deadline is distinct from old.deadline then             -- E4: deadline change after opening
    if coalesce(btrim(new.status_reason),'') = '' or new.status_reason is not distinct from old.status_reason then
      raise exception 'Give a reason for changing the deadline.' using errcode = '23514';
    end if;
  end if;
  return new;
end;
$$;

create or replace function public.compliance_followup_log()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.followup_note is distinct from old.followup_note then
    perform public.comp_log(new.id, 'followup_note', 'On-leave follow-up note: ' || coalesce(new.followup_note, '(removed)'));
  end if;
  if new.followup_done_at is distinct from old.followup_done_at then
    perform public.comp_log(new.id, 'followup_done', case when new.followup_done_at is null then 'On-leave follow-up reopened' else 'On-leave follow-up marked done' end);
  end if;
  return null;
end;
$$;
revoke all on function public.compliance_followup_log() from public, anon, authenticated;
drop trigger if exists trg_compliance_followup_log on public.compliance_cycles;
create trigger trg_compliance_followup_log after update of followup_note, followup_done_at on public.compliance_cycles
  for each row execute function public.compliance_followup_log();

-- Record:
-- insert into supabase_migrations.schema_migrations (version, name) values ('20261118110000', 'compliance_p2b_report_by');
