-- 20261116090000_p1_2_p1_6_report_editors_admin_locks
-- What (PREVIEW-GATED — applies only to requests from the Preview site until released):
--   Fix 1.2 — Training reports:
--     * Only these people can create/edit/delete a session's training report:
--         the session's trainer, co-facilitator, owner (self-led), or — only when none of those is set
--         (e.g. external sessions) — the person who created the session;
--         anyone ABOVE them in the CURRENT reporting line (supervisor, supervisor's manager…);
--         admins (override).
--     * Reopen and Recording-Exemption DECISIONS (approve/deny) can only be made by someone above the
--       requester in the reporting line, or an admin — never by the requester themselves.
--       The decider and time are stamped by the database.
--     * A submitted report can only go back to Draft through an approved reopen, an admin, or the
--       manual-override reopen (by someone allowed to edit the report).
--     * New column training_reports.updated_by = who last saved the report (stamped by the database).
--   Fix 1.6 — Admin-only settings:
--     * Checklist templates: everyone can still read/use them; only admins can create/edit/delete.
--     * Program-level L1 targets: only admins can set them (defaults were already admin-only).
-- Why:   Assessment 02 / Revision 1 (Phase 1 fixes 1.2 + 1.6). Sandra 16 Nov: trainers own their
--        sessions; supervisor can edit on their behalf (e.g. on leave); admin can always override;
--        co-facilitators can edit too.
-- Check: 120-day audit — every report edit fits the new rule except Joseph's 4 September approvals
--        (TS-2026-044/054) made when the trainers reported to him (they now report to Sandra).
-- Date:  2026-11-16 · Approved by: Sandra Barlao
-- Rollback: supabase/rollback/20261116090000_p1_2_p1_6_report_editors_admin_locks_ROLLBACK.sql
-- Release: re-create the policies/functions without the `not public.is_preview_request() or` parts
--          and without the early return in training_reports_guard().

-- ── Fix 1.2 ──────────────────────────────────────────────────────────────────────────────────
alter table public.training_reports add column if not exists updated_by uuid;

create or replace function public.can_edit_training_report(p_session text)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select auth.uid() is not null and (
    coalesce(public.is_admin(), false)
    or exists (
      select 1 from public.training_sessions s
       where s.id = p_session
         and (
           auth.uid() in (s.trainer_id, s.co_facilitator_id, s.owner_id)
           or public.is_in_my_downline(s.trainer_id)
           or public.is_in_my_downline(s.co_facilitator_id)
           or public.is_in_my_downline(s.owner_id)
           or (s.trainer_id is null and s.co_facilitator_id is null and s.owner_id is null
               and (auth.uid() = s.created_by or public.is_in_my_downline(s.created_by)))
         )
    )
  );
$function$;

revoke all on function public.can_edit_training_report(text) from public, anon;
grant execute on function public.can_edit_training_report(text) to authenticated;

drop policy if exists training_reports_write on public.training_reports;
create policy training_reports_write on public.training_reports
  for all to authenticated
  using (auth.role() = 'authenticated' and (not public.is_preview_request() or public.can_edit_training_report(session_id)))
  with check (auth.role() = 'authenticated' and (not public.is_preview_request() or public.can_edit_training_report(session_id)));

create or replace function public.training_reports_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  me uuid := auth.uid();
  adm boolean := coalesce(public.is_admin(), false);
  ex_old text;
  ex_new text;
  ex_req uuid;
  reopen_ok boolean := false;
begin
  if not public.is_preview_request() or me is null then
    return new;
  end if;

  new.updated_by := me;

  if tg_op = 'UPDATE' then
    -- Reopen decision (pending -> approved / denied)
    if new.reopen_status in ('approved','denied')
       and new.reopen_status is distinct from old.reopen_status then
      if not adm and (new.reopen_requested_by is null
                      or new.reopen_requested_by = me
                      or not public.is_in_my_downline(new.reopen_requested_by)) then
        raise exception 'Only the requester''s supervisor (or an admin) can approve or deny a reopen request.'
          using errcode = '42501';
      end if;
      new.reopen_decided_by := me;
      new.reopen_decided_at := now();
      reopen_ok := (new.reopen_status = 'approved');
    end if;

    -- Recording exemption decision (pending -> approved / denied), stored in content
    ex_old := old.content #>> '{recordingExemption,status}';
    ex_new := new.content #>> '{recordingExemption,status}';
    if ex_new in ('approved','denied') and ex_new is distinct from ex_old then
      ex_req := nullif(new.content #>> '{recordingExemption,requestedBy}', '')::uuid;
      if not adm and (ex_req is null or ex_req = me or not public.is_in_my_downline(ex_req)) then
        raise exception 'Only the requester''s supervisor (or an admin) can approve or deny a recording exemption.'
          using errcode = '42501';
      end if;
      new.content := jsonb_set(jsonb_set(new.content, '{recordingExemption,decidedBy}', to_jsonb(me::text)),
                               '{recordingExemption,decidedAt}', to_jsonb(now()));
    end if;

    -- Unlocking a submitted report
    if old.status = 'submitted' and new.status is distinct from 'submitted' then
      if not (adm or reopen_ok or coalesce((old.content ->> 'manualOverride')::boolean, false)) then
        raise exception 'A submitted report can only be reopened through an approved reopen request (or by an admin).'
          using errcode = '42501';
      end if;
    end if;
  end if;
  return new;
end;
$function$;

revoke all on function public.training_reports_guard() from public, anon, authenticated;

drop trigger if exists trg_training_reports_guard on public.training_reports;
create trigger trg_training_reports_guard
  before insert or update on public.training_reports
  for each row execute function public.training_reports_guard();

-- ── Fix 1.6 ──────────────────────────────────────────────────────────────────────────────────
drop policy if exists checklist_templates_all on public.checklist_templates;
drop policy if exists checklist_templates_select on public.checklist_templates;
drop policy if exists checklist_templates_write on public.checklist_templates;
create policy checklist_templates_select on public.checklist_templates
  for select using (true);
create policy checklist_templates_write on public.checklist_templates
  for all using (not public.is_preview_request() or public.is_admin())
  with check (not public.is_preview_request() or public.is_admin());

drop policy if exists l1_targets_write on public.l1_targets;
create policy l1_targets_write on public.l1_targets
  for all
  using ((auth.uid() is not null) and (public.is_admin() or (program_family_id is not null and not public.is_preview_request())))
  with check ((auth.uid() is not null) and (public.is_admin() or (program_family_id is not null and not public.is_preview_request())));

-- Record:
-- insert into supabase_migrations.schema_migrations (version, name)
--   values ('20261116090000', 'p1_2_p1_6_report_editors_admin_locks');
