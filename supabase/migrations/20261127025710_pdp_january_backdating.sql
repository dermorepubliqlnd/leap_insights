-- Verify the expected trigger before replacing it.
DO $preflight$
BEGIN
  IF md5(pg_get_functiondef('public.pdp_items_guard()'::regprocedure)) <> '73c1c76c9a785d9e513298400f38452f' THEN
    RAISE EXCEPTION 'PDP trigger differs from the tested release baseline';
  END IF;
END
$preflight$;

-- Allow historical PDP and milestone dates from January 2026.
-- Replaces the existing trigger function without rewriting existing rows.

CREATE OR REPLACE FUNCTION public.pdp_items_guard()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  admin_  boolean := coalesce(public.is_admin(), false);
  owner_  boolean := new.profile_id = auth.uid();
  date_ok boolean := coalesce(current_setting('leap.pdp_date_ok', true), '') = '1';
  strict_ boolean := true;   -- v5.20c gate (release: true)
  floor_  date := date '2026-01-01';
  today_  date := (now() at time zone 'Asia/Manila')::date;
  can_verify boolean;
  content_changed boolean := false;
  ms_old jsonb; ms_new jsonb;
  old_milestones jsonb := '[]'::jsonb;
  milestone jsonb;
  earliest date;
begin
  new.updated_at := now();
  can_verify := public.pdp_can_verify(new.profile_id);
  earliest := greatest(new.start_date, floor_);
  if tg_op = 'UPDATE' and new.start_date is not distinct from old.start_date then
    old_milestones := coalesce(old.milestones, '[]'::jsonb);
  end if;
  for milestone in
    select e.value from jsonb_array_elements(coalesce(new.milestones, '[]'::jsonb)) e
    where not old_milestones @> jsonb_build_array(e.value)
  loop
    if nullif(milestone->>'targetDate', '')::date < earliest then
      raise exception 'Milestone target dates cannot be before the PDP start date or Jan 1, 2026.';
    end if;
    if nullif(milestone->>'doneAt', '')::date not between earliest and today_ then
      raise exception 'Milestone completion dates must be on or after the PDP start date and Jan 1, 2026, and no later than today.';
    end if;
  end loop;

  if tg_op = 'INSERT' then
    if new.status not in ('draft','pending_approval') then raise exception 'A new PDP starts as a draft.'; end if;
    if coalesce(btrim(new.title), '') = '' then raise exception 'Add a PDP title.'; end if;
    if coalesce(btrim(new.description), '') = '' then raise exception 'Add a short description.'; end if;
    if new.target_date is null then raise exception 'Add a target completion date.'; end if;
    if strict_ then
      if new.start_date is null then raise exception 'Add a start date.'; end if;
      if new.start_date < floor_ then raise exception 'The start date can''t be before Jan 1, 2026.'; end if;
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
    if new.start_date is not null and new.start_date < floor_ and not admin_ then raise exception 'The start date can''t be before Jan 1, 2026.'; end if;
    if new.target_date < floor_ and new.target_date is distinct from old.target_date then raise exception 'The target date can''t be before Jan 1, 2026.'; end if;
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
    if new.completed_on < floor_ then raise exception 'The completion date can''t be before Jan 1, 2026.'; end if;
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
end $function$;
