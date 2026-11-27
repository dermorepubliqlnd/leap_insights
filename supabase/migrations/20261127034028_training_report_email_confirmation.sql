-- Verify the expected Live Training Report guard before applying this release.
DO $preflight$
BEGIN
  IF md5(pg_get_functiondef('public.training_reports_guard()'::regprocedure)) <> '05819e4ee3dbb5aa7b05bff91f5ea1ab' THEN
    RAISE EXCEPTION 'Training Report guard differs from the tested baseline';
  END IF;
END
$preflight$;

-- Add email confirmation and session-scoped write permissions.
create unique index training_reports_one_per_session on public.training_reports(session_id);

alter table public.training_reports
  add column email_sent_on date,
  add column email_last_sent_on date,
  add column email_confirmed_by uuid references public.profiles(id),
  add column email_confirmed_at timestamptz;

CREATE OR REPLACE FUNCTION public.can_edit_training_report(p_session text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select exists (select 1 from public.profiles where id = auth.uid() and is_active) and (
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

drop policy training_reports_write on public.training_reports;
create policy training_reports_write on public.training_reports
  for all to authenticated
  using (public.can_edit_training_report(session_id))
  with check (public.can_edit_training_report(session_id));

create or replace function public.training_reports_guard()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare
  actor uuid := auth.uid();
  admin boolean := coalesce(public.is_admin(), false);
  session_row public.training_sessions%rowtype;
  session_end date;
  manila_today date := (now() at time zone 'Asia/Manila')::date;
  old_status text;
  old_first_date date;
  old_last_date date;
  confirms_email boolean := false;
  exempt boolean;
  old_exemption jsonb;
  new_exemption jsonb;
  requester uuid;
  can_reopen boolean := false;
begin
  if actor is null then
    return new;
  end if;

  new.updated_by := actor;
  select * into session_row from public.training_sessions where id = new.session_id;
  if not found then
    raise exception 'Training session not found.';
  end if;
  if session_row.date_mode = 'specific' then
    select max(d) into session_end from unnest(session_row.session_dates) d;
  end if;
  session_end := coalesce(session_end, session_row.end_date, session_row.training_date);
  exempt := coalesce(session_row.delivery_type in ('ILT','VILT'), false) and session_row.report_required is false;

  if tg_op = 'UPDATE' then
    old_status := old.status;
    old_first_date := old.email_sent_on;
    old_last_date := old.email_last_sent_on;
    old_exemption := old.content -> 'recordingExemption';
    if new.session_id is distinct from old.session_id then
      raise exception 'A Training Report cannot be moved to another session.';
    end if;
  end if;

  if new.reopen_status is distinct from (case when tg_op = 'UPDATE' then old.reopen_status end) then
    if new.reopen_status = 'pending' then
      if old_status is distinct from 'submitted' or nullif(btrim(new.reopen_reason), '') is null then
        raise exception 'Only a submitted report with a reason can be reopened.';
      end if;
      new.reopen_requested_by := actor;
      new.reopen_requested_at := now();
      new.reopen_decided_by := null;
      new.reopen_decided_at := null;
    elsif new.reopen_status in ('approved','denied') then
      if tg_op = 'UPDATE' then
        requester := old.reopen_requested_by;
      end if;
      if tg_op <> 'UPDATE' or old.reopen_status is distinct from 'pending' or requester is null
         or requester = actor or not (admin or public.is_in_my_downline(requester)) then
        raise exception 'A different authorized supervisor or admin must decide this reopen request.' using errcode = '42501';
      end if;
      new.reopen_requested_by := requester;
      new.reopen_requested_at := old.reopen_requested_at;
      new.reopen_reason := old.reopen_reason;
      new.reopen_decided_by := actor;
      new.reopen_decided_at := now();
      can_reopen := new.reopen_status = 'approved';
    elsif new.reopen_status is null and tg_op = 'UPDATE'
       and old.reopen_status = 'pending' then
      raise exception 'A pending reopen request requires a decision.';
    end if;
  elsif tg_op = 'UPDATE' then
    new.reopen_requested_by := old.reopen_requested_by;
    new.reopen_requested_at := old.reopen_requested_at;
    new.reopen_reason := old.reopen_reason;
    new.reopen_decided_by := old.reopen_decided_by;
    new.reopen_decided_at := old.reopen_decided_at;
  end if;

  new_exemption := new.content -> 'recordingExemption';
  if new_exemption ->> 'status' is distinct from old_exemption ->> 'status' then
    if new_exemption ->> 'status' = 'pending' then
      new_exemption := new_exemption || jsonb_build_object(
        'requestedBy', actor, 'requestedAt', now(), 'decidedBy', null, 'decidedAt', null);
    elsif new_exemption ->> 'status' in ('approved','denied') then
      requester := nullif(old_exemption ->> 'requestedBy', '')::uuid;
      if old_exemption ->> 'status' is distinct from 'pending' or requester is null
         or requester = actor or not (admin or public.is_in_my_downline(requester)) then
        raise exception 'A different authorized supervisor or admin must decide this recording exemption.' using errcode = '42501';
      end if;
      new_exemption := old_exemption || jsonb_build_object(
        'status', new_exemption ->> 'status', 'decidedBy', actor, 'decidedAt', now());
    elsif old_exemption ->> 'status' = 'pending' then
      raise exception 'A pending recording exemption requires a decision.';
    end if;
    if new_exemption is not null then
      new.content := jsonb_set(new.content, '{recordingExemption}', new_exemption);
    end if;
  elsif new_exemption is distinct from old_exemption and old_exemption is not null then
    new.content := jsonb_set(new.content, '{recordingExemption}', old_exemption);
  end if;

  if old_status in ('submitted','approved') and new.status is distinct from old_status
     and not (new.status = 'draft' and
       (admin or can_reopen or coalesce(old.content ->> 'manualOverride', 'false') = 'true')) then
    raise exception 'Reopen the Training Report before editing it.' using errcode = '42501';
  end if;

  new.email_sent_on := old_first_date;
  if tg_op = 'UPDATE' then
    new.email_confirmed_by := old.email_confirmed_by;
    new.email_confirmed_at := old.email_confirmed_at;
    new.submitted_at := old.submitted_at;
  else
    new.email_confirmed_by := null;
    new.email_confirmed_at := null;
    if new.status not in ('submitted','approved') then
      new.submitted_at := null;
    end if;
  end if;

  if new.status = 'awaiting_email' and new.status is distinct from old_status then
    if exempt or session_end is null or session_end > manila_today
       or (session_row.delivery_type <> 'Self-led' and session_row.status <> 'completed') then
      raise exception 'Finish the training delivery before marking its report ready to email.';
    end if;
    new.created_by := actor;
  end if;

  if new.email_last_sent_on is distinct from old_last_date
     or (old_status = 'awaiting_email' and new.status = 'submitted') then
    if new.email_last_sent_on is null or new.status is distinct from 'submitted'
       or exempt or not coalesce(old_status = 'awaiting_email'
         or (old_status = 'submitted' and old_first_date is null), false) then
      raise exception 'An email sent date can only be confirmed for a report ready to email or a previous submission.';
    end if;
    if session_end is null or new.email_last_sent_on < session_end
       or new.email_last_sent_on > manila_today
       or (old_last_date is not null and new.email_last_sent_on < old_last_date) then
      raise exception 'Use a sent date on or after the session end and previous send, and no later than today.';
    end if;
    new.email_sent_on := coalesce(old_first_date, new.email_last_sent_on);
    new.email_confirmed_by := actor;
    new.email_confirmed_at := now();
    confirms_email := true;
  end if;

  if new.status in ('submitted','approved') and new.status is distinct from old_status then
    if not exempt and not confirms_email then
      if not coalesce((session_row.training_date < date '2026-08-01' and session_end < manila_today
              and coalesce(new.content ->> 'manualOverride', 'false') = 'true'
              and nullif(btrim(new.content ->> 'manualReportLink'), '') is not null
              and nullif(new.content ->> 'manualSubmittedDate', '')::date between session_end and manila_today), false) then
        raise exception 'Mark the report ready to email and confirm the date it was sent.';
      end if;
      new.submitted_at := (new.content ->> 'manualSubmittedDate')::date::timestamp at time zone 'Asia/Manila';
    else
      new.submitted_at := now();
    end if;
  end if;

  if tg_op = 'UPDATE' and old_status in ('submitted','approved','awaiting_email')
     and new.status <> 'draft'
     and (new.content - 'recordingExemption') is distinct from (old.content - 'recordingExemption') then
    raise exception 'Return the Training Report to Draft before changing its content.';
  end if;
  return new;
end;
$function$;
