-- v5.19g — PDP workflow: continuous list, activity history, date-change requests, milestones, cancel
-- What:  pdp_items gets description, completion notes, supporting link, original target date, started /
--        submitted / cancelled timestamps, cancel reason, milestones (optional checklist) and a
--        'cancelled' status. New tables pdp_events (activity history + comments; written by the database
--        for every change) and pdp_date_requests (target-date change requests decided by the supervisor).
--        Verification = direct supervisor, admin as backup (an admin with no supervisor may verify own).
-- Why:   Sandra, 2026-11-11 (brief briefs/pdp_workflow_assessment_2026-11-11.md): one continuous PDP list;
--        KPI counts verified completions by actual completion date; delete only while Not Started,
--        cancel with a reason once started; date changes after Start need supervisor approval; full
--        history and comments.
-- Safety: additive. New status / field rules apply ONLY to preview requests (x-app-channel: preview);
--        live keeps the v5.15a behaviour until release. Event logging runs everywhere (additive).
--        Existing rows are not rewritten.
-- Release: remove the `if not strict_` branch in pdp_items_guard and the preview test in pdp_delete.

alter table public.pdp_items add column if not exists description text;
alter table public.pdp_items add column if not exists completion_notes text;
alter table public.pdp_items add column if not exists supporting_url text;
alter table public.pdp_items add column if not exists original_target_date date;
alter table public.pdp_items add column if not exists started_at timestamptz;
alter table public.pdp_items add column if not exists submitted_at timestamptz;
alter table public.pdp_items add column if not exists cancelled_at timestamptz;
alter table public.pdp_items add column if not exists cancel_reason text;
alter table public.pdp_items add column if not exists milestones jsonb not null default '[]'::jsonb;

alter table public.pdp_items drop constraint if exists pdp_items_status_check;
alter table public.pdp_items add constraint pdp_items_status_check
  check (status in ('planned','ongoing','submitted','verified','returned','cancelled'));

-- who may verify / return a PDP and decide date changes: the direct supervisor, or an admin
-- (an admin may act on their own PDP only when they have no supervisor)
create or replace function public.pdp_can_verify(p_profile uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.profiles where id = p_profile and supervisor_id = auth.uid())
      or (coalesce(public.is_admin(), false)
          and (p_profile <> auth.uid()
               or (select supervisor_id from public.profiles where id = p_profile) is null));
$$;
grant execute on function public.pdp_can_verify(uuid) to authenticated;

create or replace function public.pdp_quarter_of(d date)
returns text language sql immutable as $$ select to_char(d,'YYYY') || '-Q' || to_char(d,'Q'); $$;

create or replace function public.pdp_items_guard()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  strict_ boolean := public.is_preview_request();
  admin_  boolean := coalesce(public.is_admin(), false);
  owner_  boolean := new.profile_id = auth.uid();
  date_ok boolean := coalesce(current_setting('leap.pdp_date_ok', true), '') = '1';
  can_verify boolean;
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
    if new.status <> 'planned' then raise exception 'A new PDP starts as Not Started.'; end if;
    if coalesce(btrim(new.title), '') = '' then raise exception 'Add a PDP title.'; end if;
    if coalesce(btrim(new.description), '') = '' then raise exception 'Add a short description.'; end if;
    if new.target_date is null then raise exception 'Add a target completion date.'; end if;
    new.original_target_date := new.target_date;
    new.quarter := public.pdp_quarter_of(new.target_date);
    new.verified_by := null; new.verified_at := null;
    return new;
  end if;

  if old.status in ('verified','cancelled') and not admin_ then
    raise exception 'This PDP is closed. Ask an admin to change it.';
  end if;
  if new.status is distinct from old.status then
    if not (
         (old.status = 'planned' and new.status = 'ongoing' and (owner_ or admin_))
      or (old.status in ('ongoing','returned') and new.status = 'submitted' and (owner_ or admin_))
      or (old.status = 'returned' and new.status = 'ongoing' and (owner_ or admin_))
      or (old.status = 'submitted' and new.status in ('verified','returned') and can_verify)
      or (old.status in ('ongoing','returned','submitted') and new.status = 'cancelled' and (owner_ or admin_))
      or (admin_ and old.status in ('verified','cancelled'))
    ) then
      raise exception 'That status change is not allowed (% to %).', old.status, new.status;
    end if;
    if old.status = 'planned' and new.status = 'ongoing' then
      new.started_at := coalesce(old.started_at, now());
      new.original_target_date := new.target_date;   -- the committed date
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
    if old.status <> 'planned' and not date_ok and not admin_ then
      raise exception 'Request a date change. Your supervisor approves it.';
    end if;
    if old.status = 'planned' then new.original_target_date := new.target_date; end if;
    new.quarter := public.pdp_quarter_of(new.target_date);
  end if;
  return new;
end $$;

-- ── activity history (the audit trail + comments) ──
create table if not exists public.pdp_events (
  id uuid primary key default gen_random_uuid(),
  pdp_id uuid not null,               -- no FK: history survives a deleted Not Started PDP
  profile_id uuid not null references public.profiles(id) on delete cascade,
  actor_id uuid default auth.uid(),
  kind text not null check (kind in ('created','edited','ongoing','submitted','verified','returned','cancelled','deleted','date_request','date_approved','date_rejected','comment','status')),
  body text check (body is null or char_length(body) <= 2000),
  before jsonb,
  after jsonb,
  created_at timestamptz not null default now()
);
create index if not exists pdp_events_pdp_idx on public.pdp_events(pdp_id, created_at);

create or replace function public.pdp_items_log()
returns trigger language plpgsql security definer set search_path = public as $$
declare b jsonb; a jsonb; k text;
begin
  if tg_op = 'INSERT' then
    insert into public.pdp_events(pdp_id, profile_id, actor_id, kind, body, after)
    values (new.id, new.profile_id, auth.uid(), 'created', new.title,
            jsonb_build_object('title', new.title, 'description', new.description, 'target_date', new.target_date));
    return new;
  elsif tg_op = 'DELETE' then
    insert into public.pdp_events(pdp_id, profile_id, actor_id, kind, body, before)
    values (old.id, old.profile_id, auth.uid(), 'deleted', old.title, to_jsonb(old));
    return old;
  end if;
  if new.status is distinct from old.status then
    k := case when new.status in ('ongoing','submitted','verified','returned','cancelled') then new.status else 'status' end;
    insert into public.pdp_events(pdp_id, profile_id, actor_id, kind, body, before, after)
    values (new.id, new.profile_id, auth.uid(), k,
            case new.status when 'returned' then new.return_reason when 'cancelled' then new.cancel_reason
                            when 'submitted' then new.completion_notes else null end,
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
drop trigger if exists pdp_items_log on public.pdp_items;
create trigger pdp_items_log after insert or update or delete on public.pdp_items
  for each row execute function public.pdp_items_log();

alter table public.pdp_events enable row level security;
drop policy if exists pdp_events_select on public.pdp_events;
create policy pdp_events_select on public.pdp_events for select to authenticated
  using (profile_id = auth.uid() or public.is_in_my_downline(profile_id) or coalesce(public.is_admin(), false));
drop policy if exists pdp_events_comment on public.pdp_events;
create policy pdp_events_comment on public.pdp_events for insert to authenticated
  with check (kind = 'comment' and actor_id = auth.uid() and char_length(coalesce(btrim(body),'')) between 1 and 500
              and exists (select 1 from public.pdp_items p where p.id = pdp_id and p.profile_id = pdp_events.profile_id)
              and (profile_id = auth.uid() or public.is_in_my_downline(profile_id) or coalesce(public.is_admin(), false)));
grant select, insert on public.pdp_events to authenticated;

-- ── target-date change requests ──
create table if not exists public.pdp_date_requests (
  id uuid primary key default gen_random_uuid(),
  pdp_id uuid not null references public.pdp_items(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  requested_by uuid default auth.uid(),
  from_date date,
  proposed_date date not null,
  reason text not null check (char_length(btrim(reason)) between 1 and 500),
  status text not null default 'pending' check (status in ('pending','approved','rejected')),
  decided_by uuid references public.profiles(id),
  decided_at timestamptz,
  decision_note text,
  created_at timestamptz not null default now()
);
create unique index if not exists pdp_date_requests_one_pending on public.pdp_date_requests(pdp_id) where status = 'pending';

create or replace function public.pdp_date_requests_before()
returns trigger language plpgsql security definer set search_path = public as $$
declare p public.pdp_items;
begin
  select * into p from public.pdp_items where id = new.pdp_id;
  if p.id is null then raise exception 'PDP not found.'; end if;
  if p.profile_id <> auth.uid() then raise exception 'Only the PDP owner can request a date change.'; end if;
  if p.status not in ('ongoing','returned') then raise exception 'Date changes are requested while the PDP is Ongoing.'; end if;
  if new.proposed_date = p.target_date then raise exception 'Pick a different date.'; end if;
  new.profile_id := p.profile_id; new.from_date := p.target_date; new.requested_by := auth.uid();
  new.status := 'pending'; new.decided_by := null; new.decided_at := null; new.decision_note := null;
  return new;
end $$;
drop trigger if exists pdp_date_requests_before on public.pdp_date_requests;
create trigger pdp_date_requests_before before insert on public.pdp_date_requests
  for each row execute function public.pdp_date_requests_before();

create or replace function public.pdp_date_requests_after()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.pdp_events(pdp_id, profile_id, actor_id, kind, body, before, after)
  values (new.pdp_id, new.profile_id, auth.uid(), 'date_request', new.reason,
          jsonb_build_object('target_date', new.from_date), jsonb_build_object('target_date', new.proposed_date));
  return new;
end $$;
drop trigger if exists pdp_date_requests_after on public.pdp_date_requests;
create trigger pdp_date_requests_after after insert on public.pdp_date_requests
  for each row execute function public.pdp_date_requests_after();

alter table public.pdp_date_requests enable row level security;
drop policy if exists pdp_dr_select on public.pdp_date_requests;
create policy pdp_dr_select on public.pdp_date_requests for select to authenticated
  using (profile_id = auth.uid() or public.is_in_my_downline(profile_id) or coalesce(public.is_admin(), false));
drop policy if exists pdp_dr_insert on public.pdp_date_requests;
create policy pdp_dr_insert on public.pdp_date_requests for insert to authenticated
  with check (requested_by = auth.uid());
grant select, insert on public.pdp_date_requests to authenticated;

-- supervisor decision (approve moves the target date; reject keeps it)
create or replace function public.pdp_decide_date(p_request uuid, p_approve boolean, p_note text default null)
returns public.pdp_date_requests language plpgsql security definer set search_path = public as $$
declare r public.pdp_date_requests;
begin
  select * into r from public.pdp_date_requests where id = p_request for update;
  if r.id is null then raise exception 'Request not found.'; end if;
  if r.status <> 'pending' then raise exception 'This request was already decided.'; end if;
  if not public.pdp_can_verify(r.profile_id) then raise exception 'Only the supervisor can decide date changes.'; end if;
  if not p_approve and coalesce(btrim(p_note), '') = '' then raise exception 'Add a note when rejecting.'; end if;
  update public.pdp_date_requests
     set status = case when p_approve then 'approved' else 'rejected' end,
         decided_by = auth.uid(), decided_at = now(), decision_note = nullif(btrim(coalesce(p_note,'')), '')
   where id = p_request returning * into r;
  if p_approve then
    perform set_config('leap.pdp_date_ok', '1', true);
    update public.pdp_items set target_date = r.proposed_date where id = r.pdp_id;
    perform set_config('leap.pdp_date_ok', '', true);
  end if;
  insert into public.pdp_events(pdp_id, profile_id, actor_id, kind, body, before, after)
  values (r.pdp_id, r.profile_id, auth.uid(), case when p_approve then 'date_approved' else 'date_rejected' end, r.decision_note,
          jsonb_build_object('target_date', r.from_date), jsonb_build_object('target_date', r.proposed_date));
  return r;
end $$;
grant execute on function public.pdp_decide_date(uuid, boolean, text) to authenticated;

-- delete: preview = only while Not Started (never started); live unchanged until release
drop policy if exists pdp_delete on public.pdp_items;
create policy pdp_delete on public.pdp_items for delete to authenticated
  using ((profile_id = auth.uid() and status <> 'verified'
          and (not public.is_preview_request() or (status = 'planned' and started_at is null)))
         or coalesce(public.is_admin(), false));
