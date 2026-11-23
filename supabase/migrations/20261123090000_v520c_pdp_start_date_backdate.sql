-- v5.20c (2026-11-23, per Sandra: "allow users to add and back date start and end date") — PDP Start Date + backdating
-- What:  1. New column pdp_items.start_date (date). Required for new PDPs created from Preview.
--        2. Start and target (end) dates may be in the past; floor = 2026-10-01 (scorecards start, Q4 2026).
--           Target must be on/after start. Completion date must be on/after start and on/after 2026-10-01.
--        3. Approving a plan whose start date is today or earlier moves it straight to Ongoing;
--           started_at = start date (Manila midnight). Future start dates stay Not Started as before.
--        4. Start date is part of the plan: owner editing it on an approved plan sends it back for approval;
--           locked once started (admin can still change).
--        5. pdp_items_log: approval that goes straight to Ongoing logs "approved" then "ongoing";
--           start_date edits appear in the activity history.
-- Why:   team needs to log PDPs already underway / completed since Oct 1 2026.
-- Safety: additive column; all new rules gated by is_preview_request() (live behaves exactly as before).
--         Release = re-create pdp_items_guard with strict_ := true.
-- Rollback: supabase/rollback/20261123090000_v520c_pdp_start_date_backdate_ROLLBACK.sql

alter table public.pdp_items add column if not exists start_date date;

create or replace function public.pdp_items_guard()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  admin_  boolean := coalesce(public.is_admin(), false);
  owner_  boolean := new.profile_id = auth.uid();
  date_ok boolean := coalesce(current_setting('leap.pdp_date_ok', true), '') = '1';
  strict_ boolean := coalesce(public.is_preview_request(), false);   -- v5.20c gate (release: true)
  floor_  date := date '2026-10-01';
  today_  date := (now() at time zone 'Asia/Manila')::date;
  can_verify boolean;
  content_changed boolean := false;
  ms_old jsonb; ms_new jsonb;
begin
  new.updated_at := now();
  can_verify := public.pdp_can_verify(new.profile_id);
  if tg_op = 'INSERT' then
    if new.status not in ('draft','pending_approval') then raise exception 'A new PDP starts as a draft.'; end if;
    if coalesce(btrim(new.title), '') = '' then raise exception 'Add a PDP title.'; end if;
    if coalesce(btrim(new.description), '') = '' then raise exception 'Add a short description.'; end if;
    if new.target_date is null then raise exception 'Add a target completion date.'; end if;
    if strict_ then
      if new.start_date is null then raise exception 'Add a start date.'; end if;
      if new.start_date < floor_ then raise exception 'The start date can''t be before Oct 1, 2026.'; end if;
      if new.target_date < new.start_date then raise exception 'The target date can''t be before the start date.'; end if;
    end if;
    new.original_target_date := new.target_date;
    new.quarter := public.pdp_quarter_of(new.target_date);
    new.verified_by := null; new.verified_at := null; new.approved_by := null; new.approved_at := null;
    if new.status = 'pending_approval' then new.approval_requested_at := now(); end if;
    return new;
  end if;

  if old.status in ('verified','cancelled') and not admin_ then
    raise exception 'This PDP is closed. Ask an admin to change it.';
  end if;

  select coalesce(jsonb_agg(jsonb_build_array(e->>'title', e->>'targetDate') order by ord), '[]'::jsonb) into ms_old
    from jsonb_array_elements(coalesce(old.milestones,'[]'::jsonb)) with ordinality as t(e, ord);
  select coalesce(jsonb_agg(jsonb_build_array(e->>'title', e->>'targetDate') order by ord), '[]'::jsonb) into ms_new
    from jsonb_array_elements(coalesce(new.milestones,'[]'::jsonb)) with ordinality as t(e, ord);
  content_changed := new.title is distinct from old.title or new.description is distinct from old.description
                  or new.target_date is distinct from old.target_date or ms_old is distinct from ms_new
                  or new.start_date is distinct from old.start_date;

  if content_changed and old.status = 'planned' and new.status = 'planned' and owner_ and not date_ok then
    new.status := 'pending_approval';
  end if;
  if content_changed and old.status in ('ongoing','returned','submitted') and not admin_ then
    if not (date_ok and ms_old = ms_new and new.title is not distinct from old.title and new.description is not distinct from old.description
            and new.start_date is not distinct from old.start_date) then
      raise exception 'The plan is locked once started. Use Request date change, or ask your supervisor.';
    end if;
  end if;
  if content_changed and old.status = 'pending_approval' and new.status = 'pending_approval' and not admin_ and (owner_ or not can_verify) then
    raise exception 'The plan is waiting for approval. Withdraw it to make changes, or ask your supervisor.';
  end if;

  if strict_ and (new.start_date is distinct from old.start_date or new.target_date is distinct from old.target_date) then
    if new.start_date is null and old.start_date is not null then raise exception 'A start date is required.'; end if;
    if new.start_date is not null and new.start_date < floor_ and not admin_ then raise exception 'The start date can''t be before Oct 1, 2026.'; end if;
    if new.start_date is not null and new.target_date < new.start_date then raise exception 'The target date can''t be before the start date.'; end if;
  end if;

  if new.status is distinct from old.status then
    if not (
         (old.status = 'draft' and new.status = 'pending_approval' and (owner_ or admin_))
      or (old.status = 'pending_approval' and new.status = 'draft' and (owner_ or can_verify))
      or (old.status = 'pending_approval' and new.status = 'planned' and can_verify)
      or (old.status = 'planned' and new.status = 'pending_approval' and (owner_ or admin_))
      or (old.status = 'planned' and new.status = 'ongoing' and (owner_ or admin_))
      or (old.status in ('ongoing','returned') and new.status = 'submitted' and (owner_ or admin_))
      or (old.status = 'returned' and new.status = 'ongoing' and (owner_ or admin_))
      or (old.status = 'submitted' and new.status in ('verified','returned') and can_verify)
      or (old.status in ('ongoing','returned','submitted') and new.status = 'cancelled' and (owner_ or admin_))
      or (admin_ and old.status in ('verified','cancelled'))
    ) then
      raise exception 'That status change is not allowed (% to %).', old.status, new.status;
    end if;
    if new.status = 'pending_approval' then
      new.approval_requested_at := now(); new.approved_by := null; new.approved_at := null;
    end if;
    if old.status = 'pending_approval' and new.status = 'draft' and not owner_ then
      if coalesce(btrim(new.approval_note), '') = '' then raise exception 'Add a note saying what to change.'; end if;
    end if;
    if new.status = 'planned' and old.status = 'pending_approval' then
      new.approved_by := auth.uid(); new.approved_at := now(); new.original_target_date := new.target_date;
      -- v5.20c: already underway -> straight to Ongoing, started on the start date
      if strict_ and new.start_date is not null and new.start_date <= today_ and old.started_at is null then
        new.status := 'ongoing';
        new.started_at := (new.start_date::timestamp at time zone 'Asia/Manila');
      end if;
    end if;
    if old.status = 'planned' and new.status = 'ongoing' then
      new.started_at := coalesce(old.started_at, now());
    end if;
    if new.status = 'submitted' then
      if new.completed_on is null then raise exception 'Add the actual completion date.'; end if;
      if new.completed_on > today_ then raise exception 'The completion date can''t be in the future.'; end if;
      if coalesce(btrim(new.completion_notes), '') = '' then raise exception 'Add completion notes.'; end if;
      if coalesce(btrim(new.supporting_url), '') = '' then raise exception 'Add a link to your proof of completion.'; end if;
      new.submitted_at := now(); new.return_reason := null;
    end if;
    if new.status = 'returned' and coalesce(btrim(new.return_reason), '') = '' then raise exception 'Say what needs to be fixed.'; end if;
    if new.status = 'cancelled' then
      if coalesce(btrim(new.cancel_reason), '') = '' then raise exception 'Give a reason for cancelling.'; end if;
      new.cancelled_at := now();
    end if;
    if new.status = 'verified' then
      if new.completed_on is null then raise exception 'Confirm the completion date.'; end if;
      new.verified_by := auth.uid(); new.verified_at := now();
    end if;
  end if;
  if strict_ and new.completed_on is not null and new.completed_on is distinct from old.completed_on and not admin_ then
    if new.completed_on < floor_ then raise exception 'The completion date can''t be before Oct 1, 2026.'; end if;
    if new.start_date is not null and new.completed_on < new.start_date then raise exception 'The completion date can''t be before the start date.'; end if;
  end if;
  if new.status <> 'verified' then new.verified_by := null; new.verified_at := null; end if;
  if new.target_date is distinct from old.target_date then
    if new.target_date is null then raise exception 'A target date is required.'; end if;
    if old.status not in ('draft','pending_approval','planned') and not date_ok and not admin_ then
      raise exception 'Request a date change. Your supervisor approves it.';
    end if;
    if old.status in ('draft','pending_approval') then new.original_target_date := new.target_date; end if;
    new.quarter := public.pdp_quarter_of(new.target_date);
  end if;
  return new;
end $$;

create or replace function public.pdp_items_log()
returns trigger language plpgsql security definer set search_path = public as $$
declare b jsonb; a jsonb; k text;
begin
  if tg_op = 'INSERT' then
    insert into public.pdp_events(pdp_id, profile_id, actor_id, kind, body, after)
    values (new.id, new.profile_id, auth.uid(), 'created', new.title,
            jsonb_build_object('title', new.title, 'description', new.description, 'start_date', new.start_date, 'target_date', new.target_date));
    if new.status = 'pending_approval' then
      insert into public.pdp_events(pdp_id, profile_id, actor_id, kind) values (new.id, new.profile_id, auth.uid(), 'approval_requested');
    end if;
    return new;
  elsif tg_op = 'DELETE' then
    insert into public.pdp_events(pdp_id, profile_id, actor_id, kind, body, before)
    values (old.id, old.profile_id, auth.uid(), 'deleted', old.title, to_jsonb(old));
    return old;
  end if;
  if new.status is distinct from old.status then
    -- v5.20c: approval of a backdated plan goes straight to Ongoing -> log "approved" first
    if old.status = 'pending_approval' and new.status = 'ongoing' then
      insert into public.pdp_events(pdp_id, profile_id, actor_id, kind, before, after)
      values (new.id, new.profile_id, auth.uid(), 'approved', jsonb_build_object('status', old.status), jsonb_build_object('status', 'planned'));
    end if;
    k := case
      when new.status = 'pending_approval' then 'approval_requested'
      when old.status = 'pending_approval' and new.status = 'planned' then 'approved'
      when old.status = 'pending_approval' and new.status = 'draft' then case when new.profile_id = auth.uid() then 'withdrawn' else 'sent_back' end
      when new.status in ('ongoing','submitted','verified','returned','cancelled') then new.status
      else 'status' end;
    insert into public.pdp_events(pdp_id, profile_id, actor_id, kind, body, before, after)
    values (new.id, new.profile_id, auth.uid(), k,
            case new.status when 'returned' then new.return_reason when 'cancelled' then new.cancel_reason
                            when 'submitted' then new.completion_notes
                            when 'draft' then case when new.profile_id = auth.uid() then null else new.approval_note end
                            else null end,
            jsonb_build_object('status', case when old.status = 'pending_approval' and new.status = 'ongoing' then 'planned' else old.status end),
            jsonb_build_object('status', new.status, 'completed_on', new.completed_on, 'supporting_url', new.supporting_url));
  end if;
  select jsonb_object_agg(e.key, e.value) into b
    from jsonb_each(to_jsonb(old)) e
   where e.key in ('title','description','supporting_url','start_date','target_date','milestones','completed_on')
     and (to_jsonb(new) -> e.key) is distinct from e.value;
  if b is not null then
    select jsonb_object_agg(x, to_jsonb(new) -> x) into a from jsonb_object_keys(b) x;
    insert into public.pdp_events(pdp_id, profile_id, actor_id, kind, before, after)
    values (new.id, new.profile_id, auth.uid(), 'edited', b, a);
  end if;
  return new;
end $$;
