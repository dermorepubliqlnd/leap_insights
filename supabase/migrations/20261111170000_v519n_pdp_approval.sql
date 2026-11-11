-- v5.19n — PDP plan approval: Draft → Pending Approval → Approved (Not Started) → Ongoing → Submitted → Verified
-- What:  new statuses 'draft' and 'pending_approval'; approved_by / approved_at / approval_note on pdp_items.
--        The direct supervisor (admin backup) approves the plan or sends it back with a note.
--        Approval locks the commitment: target date changes after approval go through a date request;
--        an owner who edits the plan while it is still Not Started sends it back to Pending Approval.
--        Once started, the plan content is locked (milestone statuses still update).
-- Why:   Sandra, 2026-11-11: "if Ren creates a PDP, I should approve it first before it gets to a commitment stage".
-- Safety: additive. Strict rules apply ONLY to preview requests (x-app-channel: preview); live keeps v5.15a behaviour.
--        Existing 'planned' rows count as already approved (no data change).
-- Release: drop the `if not strict_` branch in pdp_items_guard and the preview test in pdp_delete.

alter table public.pdp_items add column if not exists approved_by uuid references public.profiles(id);
alter table public.pdp_items add column if not exists approved_at timestamptz;
alter table public.pdp_items add column if not exists approval_note text;
alter table public.pdp_items add column if not exists approval_requested_at timestamptz;

alter table public.pdp_items drop constraint if exists pdp_items_status_check;
alter table public.pdp_items add constraint pdp_items_status_check
  check (status in ('draft','pending_approval','planned','ongoing','submitted','verified','returned','cancelled'));

alter table public.pdp_events drop constraint if exists pdp_events_kind_check;
alter table public.pdp_events add constraint pdp_events_kind_check
  check (kind in ('created','edited','ongoing','submitted','verified','returned','cancelled','deleted','date_request','date_approved','date_rejected','comment','status','approval_requested','approved','sent_back','withdrawn'));

create or replace function public.pdp_items_guard()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  strict_ boolean := public.is_preview_request();
  admin_  boolean := coalesce(public.is_admin(), false);
  owner_  boolean := new.profile_id = auth.uid();
  date_ok boolean := coalesce(current_setting('leap.pdp_date_ok', true), '') = '1';
  can_verify boolean;
  content_changed boolean := false;
  ms_old jsonb; ms_new jsonb;
begin
  new.updated_at := now();
  if not strict_ then
    -- live (v5.15a) behaviour, unchanged until release
    can_verify := admin_ or public.is_in_my_downline(new.profile_id);
    if tg_op = 'UPDATE' and old.status = 'verified' and not admin_ then
      raise exception 'This PDP is already verified. Ask an admin to change it.';
    end if;
    if new.status in ('verified','returned') and (tg_op = 'INSERT' or old.status is distinct from new.status) then
      if not can_verify then raise exception 'Only your supervisor can verify or return a PDP.'; end if;
      if new.status = 'verified' then new.verified_by := auth.uid(); new.verified_at := now(); end if;
    end if;
    if new.status <> 'verified' then new.verified_by := null; new.verified_at := null; end if;
    return new;
  end if;

  can_verify := public.pdp_can_verify(new.profile_id);
  if tg_op = 'INSERT' then
    if new.status not in ('draft','pending_approval') then raise exception 'A new PDP starts as a draft.'; end if;
    if coalesce(btrim(new.title), '') = '' then raise exception 'Add a PDP title.'; end if;
    if coalesce(btrim(new.description), '') = '' then raise exception 'Add a short description.'; end if;
    if new.target_date is null then raise exception 'Add a target completion date.'; end if;
    new.original_target_date := new.target_date;
    new.quarter := public.pdp_quarter_of(new.target_date);
    new.verified_by := null; new.verified_at := null; new.approved_by := null; new.approved_at := null;
    if new.status = 'pending_approval' then new.approval_requested_at := now(); end if;
    return new;
  end if;

  if old.status in ('verified','cancelled') and not admin_ then
    raise exception 'This PDP is closed. Ask an admin to change it.';
  end if;

  -- did the plan content change? (title, description, target date, milestone titles/dates/count)
  select coalesce(jsonb_agg(jsonb_build_array(e->>'title', e->>'targetDate') order by ord), '[]'::jsonb) into ms_old
    from jsonb_array_elements(coalesce(old.milestones,'[]'::jsonb)) with ordinality as t(e, ord);
  select coalesce(jsonb_agg(jsonb_build_array(e->>'title', e->>'targetDate') order by ord), '[]'::jsonb) into ms_new
    from jsonb_array_elements(coalesce(new.milestones,'[]'::jsonb)) with ordinality as t(e, ord);
  content_changed := new.title is distinct from old.title or new.description is distinct from old.description
                  or new.target_date is distinct from old.target_date or ms_old is distinct from ms_new;

  -- owner edits an approved, not-started plan -> back to Pending Approval (re-approval)
  if content_changed and old.status = 'planned' and new.status = 'planned' and owner_ and not date_ok then
    new.status := 'pending_approval';
  end if;
  -- once started, plan content is locked (date moves only through an approved request)
  if content_changed and old.status in ('ongoing','returned','submitted') and not admin_ then
    if not (date_ok and ms_old = ms_new and new.title is not distinct from old.title and new.description is not distinct from old.description) then
      raise exception 'The plan is locked once started. Use Request date change, or ask your supervisor.';
    end if;
  end if;
  if content_changed and old.status = 'pending_approval' and new.status = 'pending_approval' and not admin_ then
    raise exception 'The plan is waiting for approval. Withdraw it to make changes.';
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
    end if;
    if old.status = 'planned' and new.status = 'ongoing' then
      new.started_at := coalesce(old.started_at, now());
    end if;
    if new.status = 'submitted' then
      if new.completed_on is null then raise exception 'Add the actual completion date.'; end if;
      if new.completed_on > (now() at time zone 'Asia/Manila')::date then raise exception 'The completion date can''t be in the future.'; end if;
      if coalesce(btrim(new.completion_notes), '') = '' then raise exception 'Add completion notes.'; end if;
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

-- activity history: name the approval steps
create or replace function public.pdp_items_log()
returns trigger language plpgsql security definer set search_path = public as $$
declare b jsonb; a jsonb; k text;
begin
  if tg_op = 'INSERT' then
    insert into public.pdp_events(pdp_id, profile_id, actor_id, kind, body, after)
    values (new.id, new.profile_id, auth.uid(), 'created', new.title,
            jsonb_build_object('title', new.title, 'description', new.description, 'target_date', new.target_date));
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
            jsonb_build_object('status', old.status),
            jsonb_build_object('status', new.status, 'completed_on', new.completed_on, 'supporting_url', new.supporting_url));
  end if;
  select jsonb_object_agg(e.key, e.value) into b
    from jsonb_each(to_jsonb(old)) e
   where e.key in ('title','description','supporting_url','target_date','milestones','completed_on')
     and (to_jsonb(new) -> e.key) is distinct from e.value;
  if b is not null then
    select jsonb_object_agg(x, to_jsonb(new) -> x) into a from jsonb_object_keys(b) x;
    insert into public.pdp_events(pdp_id, profile_id, actor_id, kind, before, after)
    values (new.id, new.profile_id, auth.uid(), 'edited', b, a);
  end if;
  return new;
end $$;

-- delete on preview: only before it has started (draft / pending approval / approved but not started)
drop policy if exists pdp_delete on public.pdp_items;
create policy pdp_delete on public.pdp_items for delete to authenticated
  using ((profile_id = auth.uid() and status <> 'verified'
          and (not public.is_preview_request() or (status in ('draft','pending_approval','planned') and started_at is null)))
         or coalesce(public.is_admin(), false));
