-- Server-owned Trainer Checklist timestamps and schedule milestones.
-- Apply to an isolated database for Preview testing before production release.
begin;
set local lock_timeout = '5s';

create schema if not exists trainer_checklist_private;
revoke all on schema trainer_checklist_private from public, anon;

alter table public.training_sessions
  add column if not exists confirmed_at timestamptz,
  add column if not exists confirmed_by uuid,
  add column if not exists delivery_finalized_at timestamptz,
  add column if not exists delivery_finalized_by uuid,
  add column if not exists checklist_schedule_history jsonb not null default '[]';
alter table public.training_reports
  add column if not exists checklist_submitted_at timestamptz,
  add column if not exists checklist_submitted_by uuid;

create or replace function trainer_checklist_private.trainer_checklist_last_day(s public.training_sessions)
returns date language sql stable set search_path = '' as $$
  select case when s.date_mode = 'specific' then coalesce(
    case when s.program_link_origin = 'program_selection' then
      (select max((d->>'date')::date) from jsonb_array_elements(coalesce(s.delivery_part_dates,'[]')) d)
    end, (select max(d::date) from unnest(s.session_dates) d), s.training_date)
  else coalesce(s.end_date,s.training_date) end
$$;


create or replace function trainer_checklist_private.require_finalized_records(s public.training_sessions)
returns void language plpgsql stable set search_path = '' as $$
declare
  delivery_days date[];
  assessments jsonb := coalesce(s.assessment_names,'[]');
begin
  if s.program_link_origin = 'program_selection' and jsonb_array_length(coalesce(s.delivery_part_dates,'[]'))>0 then
    select array_agg((d->>'date')::date) into delivery_days from jsonb_array_elements(s.delivery_part_dates) d where nullif(d->>'date','') is not null;
  elsif s.date_mode='specific' then
    delivery_days := s.session_dates;
  else
    select array_agg(s.training_date+n) into delivery_days from generate_series(0,greatest(0,coalesce(s.end_date,s.training_date)-s.training_date)) n;
  end if;
  if coalesce(cardinality(delivery_days),0)=0 then raise exception 'Confirm the session schedule first.'; end if;
  if not exists(select 1 from public.session_participants r where r.session_id=s.id)
    or exists(
      select 1 from public.session_participants r where r.session_id=s.id and (
        nullif(btrim(r.department_id),'') is null or
        (cardinality(delivery_days)=1 and coalesce(r.attendance_status,'pending')='pending') or
        (cardinality(delivery_days)>1 and exists(select 1 from unnest(delivery_days) d where coalesce(r.attendance_by_day->>d::text,'pending')='pending'))
      )
    ) then raise exception 'Finalize attendance for every participant first.'; end if;
  if jsonb_array_length(assessments)=0 and s.assessment_type is not null and s.assessment_type<>'None' then
    assessments := jsonb_build_array(jsonb_build_object('name','Assessment',
      'pre',s.assessment_type in ('Pre-test only','Pre & Post'),'post',s.assessment_type in ('Post-test only','Pre & Post')));
  end if;
  if exists(
    select 1 from public.session_participants r cross join jsonb_array_elements(assessments) a
    where r.session_id=s.id
      and case when cardinality(delivery_days)=1 then r.attendance_status is distinct from 'absent'
        else exists(select 1 from unnest(delivery_days) d where (r.attendance_by_day->>d::text) is distinct from 'absent') end
      and ((a->>'pre'='true' and nullif(r.pre_test_scores->>(a->>'name'),'') is null)
        or (a->>'post'='true' and nullif(r.post_test_scores->>(a->>'name'),'') is null))
  ) then raise exception 'Save all required L2 scores first.'; end if;
  if nullif(btrim(s.recording_link),'') is null then raise exception 'Add the session recording link first.'; end if;
end $$;

create or replace function trainer_checklist_private.stamp_checklist_session()
returns trigger language plpgsql set search_path = '' as $$
declare
  stamp timestamptz := clock_timestamp();
begin
  if tg_op = 'INSERT' then
    new.confirmed_at := null;
    new.confirmed_by := null;
    new.delivery_finalized_at := null;
    new.delivery_finalized_by := null;
    new.checklist_schedule_history := '[]';
    if new.delivery_type = 'ILT' and auth.uid() is not null then
      new.created_at := stamp;
      new.created_by := auth.uid();
    end if;
  else
    new.confirmed_at := old.confirmed_at;
    new.confirmed_by := old.confirmed_by;
    new.delivery_finalized_at := old.delivery_finalized_at;
    new.delivery_finalized_by := old.delivery_finalized_by;
    new.checklist_schedule_history := old.checklist_schedule_history;
    if old.delivery_type = 'ILT' then
      new.created_at := old.created_at;
      new.created_by := old.created_by;
      if old.delivery_finalized_at is not null and old.status = 'completed'
        and (old.checklist_template_id is distinct from new.checklist_template_id
          or old.delivery_type is distinct from new.delivery_type
          or old.report_required is distinct from new.report_required) then
        raise exception 'Reopen delivery before changing the checklist requirement.';
      end if;
      if old.training_date is distinct from new.training_date
        or trainer_checklist_private.trainer_checklist_last_day(old) is distinct from trainer_checklist_private.trainer_checklist_last_day(new) then
        new.checklist_schedule_history := new.checklist_schedule_history || jsonb_build_array(
          jsonb_build_object('changedAt',stamp,'actorId',auth.uid(),'previousStart',old.training_date,
            'previousEnd',trainer_checklist_private.trainer_checklist_last_day(old),'newStart',new.training_date,
            'newEnd',trainer_checklist_private.trainer_checklist_last_day(new)));
      end if;
    end if;
  end if;
  if new.delivery_type = 'ILT' then
    if new.status = 'scheduled' and new.confirmed_at is null then
      if tg_op = 'INSERT' or old.status = 'tentative' then
        new.confirmed_at := stamp;
        new.confirmed_by := auth.uid();
      end if;
    end if;
    if new.status = 'completed' and (tg_op = 'INSERT' or old.status is distinct from new.status) then
      if trainer_checklist_private.trainer_checklist_last_day(new) > (stamp at time zone 'Asia/Manila')::date then
        raise exception 'Delivery can be finalized on the final scheduled day or later.';
      end if;
      if new.checklist_template_id is not null and new.checklist_template_id <> '__NONE__'
        and new.report_required is distinct from false
        and not exists(select 1 from public.training_reports r where r.session_id=new.id and r.status in ('submitted','approved') and r.content->>'manualOverride'='true') then
        perform trainer_checklist_private.require_finalized_records(new);
        new.delivery_finalized_at := stamp;
        new.delivery_finalized_by := auth.uid();
      end if;
    end if;
  end if;
  return new;
end $$;
drop trigger if exists trg_stamp_checklist_session on public.training_sessions;
create trigger trg_stamp_checklist_session before insert or update on public.training_sessions
for each row execute function trainer_checklist_private.stamp_checklist_session();

create or replace function trainer_checklist_private.stamp_checklist_report()
returns trigger language plpgsql set search_path = '' as $$
begin
  if tg_op = 'UPDATE' then
    new.checklist_submitted_at := old.checklist_submitted_at;
    new.checklist_submitted_by := old.checklist_submitted_by;
  else
    new.checklist_submitted_at := null;
    new.checklist_submitted_by := null;
  end if;
  if new.status in ('submitted','approved')
    and (tg_op = 'INSERT' or old.status not in ('submitted','approved')) then
    new.checklist_submitted_at := clock_timestamp();
    new.checklist_submitted_by := auth.uid();
  end if;
  return new;
end $$;
drop trigger if exists trg_stamp_checklist_report on public.training_reports;
create trigger trg_stamp_checklist_report before insert or update on public.training_reports
for each row execute function trainer_checklist_private.stamp_checklist_report();

create or replace function trainer_checklist_private.trainer_checklist_item_kind(template_title text, item jsonb)
returns text language sql immutable set search_path = '' as $$
  select case when lower(btrim(template_title)) = 'standard ilt checklist' then
    case
      when coalesce(item->>'phase','pre') = 'pre'
        and lower(btrim(item->>'task')) = 'create / confirm training implementation in leap' then 'schedule'
      when item->>'phase' = 'post' then
        case lower(btrim(item->>'task'))
          when 'finalize attendance' then 'attendance'
          when 'finalize assessment results' then 'assessment'
          when 'complete & submit training report' then 'report'
        end
    end
  end
$$;

create or replace function trainer_checklist_private.protect_session_checklist()
returns trigger language plpgsql set search_path = '' as $$
declare
  s public.training_sessions;
  tpl public.checklist_templates;
  old_defs jsonb;
  new_defs jsonb;
begin
  select * into s from public.training_sessions where id = case when tg_op = 'DELETE' then old.session_id else new.session_id end;
  if not found and tg_op = 'DELETE' then return old; end if;
  if tg_op = 'UPDATE' and (new.session_id is distinct from old.session_id or new.id is distinct from old.id) then
    raise exception 'Checklist identity cannot be changed.';
  end if;
  if current_user not in ('authenticated','anon') then
    if tg_op = 'DELETE' then return old; end if;
    return new;
  end if;
  if auth.uid() is null or not coalesce(public.can_edit_training_session(s.trainer_id,s.co_facilitator_id,s.created_by),false) then
    raise exception 'Only the session owner, facilitator, or their manager can change this checklist.' using errcode = '42501';
  end if;
  if tg_op = 'INSERT' then
    if s.status not in ('scheduled','completed') or s.delivery_type <> 'ILT'
      or s.report_required = false or new.template_id is distinct from s.checklist_template_id then
      raise exception 'The session must have a confirmed ILT checklist template.';
    end if;
    select * into tpl from public.checklist_templates where id = s.checklist_template_id;
    if not found then raise exception 'The assigned checklist template was not found.'; end if;
    new.template_title := tpl.title;
    select coalesce(jsonb_agg(jsonb_build_object('task',i->>'task','description',coalesce(i->>'description',''),
      'phase',coalesce(i->>'phase','pre'),'timelineDays',coalesce((i->>'timelineDays')::integer,0),
      'mandatory',coalesce((i->>'mandatory')::boolean,false),'custom',false,'notes','[]'::jsonb)
      order by entry.ordinality), '[]') into new.items
      from jsonb_array_elements(tpl.items) with ordinality entry(i, ordinality)
      where trainer_checklist_private.trainer_checklist_item_kind(tpl.title,i) is distinct from 'schedule';
    return new;
  end if;
  if tg_op = 'DELETE' then
    raise exception 'Checklist history is retained with the session.';
  end if;
  select coalesce(jsonb_agg(i-'notes' order by n),'[]') into old_defs
    from jsonb_array_elements(old.items) with ordinality entries(i,n);
  select coalesce(jsonb_agg(i-'notes' order by n),'[]') into new_defs
    from jsonb_array_elements(new.items) with ordinality entries(i,n);
  if new.template_id is distinct from old.template_id or new.template_title is distinct from old.template_title
    or old_defs is distinct from new_defs then
    raise exception 'Use the checklist actions to change progress.';
  end if;
  return new;
end $$;
drop trigger if exists trg_protect_session_checklist on public.session_checklists;
create trigger trg_protect_session_checklist before insert or update or delete on public.session_checklists
for each row execute function trainer_checklist_private.protect_session_checklist();

create or replace function trainer_checklist_private.change_trainer_checklist_item(
  p_row text, p_index integer, p_task text, p_action text, p_reason text, p_phase text, p_days integer
)
returns public.session_checklists
language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := auth.uid();
  stamp timestamptz := clock_timestamp();
  today date := (stamp at time zone 'Asia/Manila')::date;
  s public.training_sessions;
  row_record public.session_checklists;
  item jsonb;
  item_phase text;
  days integer;
  due date;
  prior_due date;
  adjustment jsonb;
  actor_can_approve boolean;
  reason text := nullif(btrim(p_reason),'');
  missed boolean;
begin
  select * into s from public.training_sessions
    where id = (select session_id from public.session_checklists where id = p_row) for update;
  if actor is null or not found or not coalesce(public.can_edit_training_session(s.trainer_id,s.co_facilitator_id,s.created_by),false) then
    raise exception 'You cannot update this session checklist.' using errcode = '42501';
  end if;
  if s.delivery_type <> 'ILT' or s.status not in ('scheduled','completed') or s.report_required = false
    or coalesce(s.checklist_template_id,'__NONE__') = '__NONE__' or s.training_date is null
    or s.training_date < date '2026-08-01' then
    raise exception 'Checklist actions are unavailable for this session.';
  end if;
  select * into strict row_record from public.session_checklists where id = p_row for update;
  if p_action = 'add' then
    item_phase := p_phase;
  else
    item := row_record.items->p_index;
    if p_index is null or p_index < 0 or item is null or item->>'task' is distinct from p_task then
      raise exception 'The checklist changed. Refresh and try again.';
    end if;
    item_phase := coalesce(item->>'phase','pre');
    if trainer_checklist_private.trainer_checklist_item_kind(row_record.template_title,item) is not null then
      raise exception 'LEAP tracks this task automatically.';
    end if;
  end if;
  if item_phase is null or item_phase not in ('pre','post') then raise exception 'Invalid checklist phase.'; end if;
  if item_phase = 'post' and today < trainer_checklist_private.trainer_checklist_last_day(s) then
    raise exception 'Post-training opens on the final scheduled day.';
  end if;
  if p_action = 'add' then
    if nullif(btrim(p_task),'') is null or length(p_task)>250 or p_days is null or p_days not between 0 and 365 then
      raise exception 'Enter a task name and a timeline of 0 to 365 days.';
    end if;
    item := jsonb_build_object('task',btrim(p_task),'phase',item_phase,'timelineDays',p_days,
      'custom',true,'mandatory',true,'notes','[]'::jsonb);
    if trainer_checklist_private.trainer_checklist_item_kind(row_record.template_title,item) is not null then
      raise exception 'LEAP already tracks this task automatically.';
    end if;
    update public.session_checklists set items=items||jsonb_build_array(item) where id=p_row returning * into row_record;
    return row_record;
  end if;
  if p_action = 'remove' then
    if item->>'custom' is distinct from 'true' or item ? 'completionEvents'
      or item->>'completedOn' is not null or item->>'isNA' = 'true'
      or jsonb_array_length(coalesce(item->'notes','[]')) > 0 then
      raise exception 'Only a custom item with no activity can be removed.';
    end if;
    update public.session_checklists set items=items-p_index where id=p_row returning * into row_record;
    return row_record;
  end if;
  days := coalesce((item->>'timelineDays')::integer,0);
  due := case when item_phase='pre' then s.training_date-days else trainer_checklist_private.trainer_checklist_last_day(s)+days end;
  for adjustment in select value from jsonb_array_elements(s.checklist_schedule_history) loop
    prior_due := case when item_phase='pre' then (adjustment->>'previousStart')::date-days
      else (adjustment->>'previousEnd')::date+days end;
    if prior_due < ((adjustment->>'changedAt')::timestamptz at time zone 'Asia/Manila')::date then
      due := least(due,prior_due);
    end if;
  end loop;
  actor_can_approve := coalesce(public.is_admin(),false)
    or coalesce(public.is_in_my_downline(s.trainer_id),false)
    or coalesce(public.is_in_my_downline(s.co_facilitator_id),false)
    or coalesce(public.is_in_my_downline(s.created_by),false);
  missed := coalesce((item->>'deadlineMissed')::boolean,false)
    or (today > due and coalesce(item->>'completionResult','') <> 'on_time');
  case p_action
    when 'done' then
      if item->>'completionState' = 'done' then return row_record; end if;
      item := item || jsonb_build_object('completionState','done','completedOn',today,'completedOnTs',stamp,
        'isNA',false,'completionResult',case when missed then 'late' else 'on_time' end,'naReason',null,'naRequestedBy',null);
    when 'na' then
      if reason is null or length(reason)>1000 then raise exception 'Enter a reason for N/A (up to 1,000 characters).'; end if;
      if item->>'completionState' = 'waiver_requested' or item->>'completionState' = 'waived' then return row_record; end if;
      item := item || jsonb_build_object('completionState',case when item->>'mandatory'='true' then 'waiver_requested' else 'waived' end,
        'completedOn',null,'completedOnTs',null,'completionResult',null,'isNA',item->>'mandatory' is distinct from 'true',
        'naReason',reason,'naRequestedBy',actor);
    when 'approve', 'deny' then
      if item->>'completionState' is distinct from 'waiver_requested' then raise exception 'No N/A request is pending.'; end if;
      if not actor_can_approve or item->>'naRequestedBy'=actor::text then
        raise exception 'A different supervisor or admin must decide this waiver.' using errcode = '42501';
      end if;
      if p_action='approve' then missed := coalesce((item->>'deadlineMissed')::boolean,false); end if;
      item := item || jsonb_build_object('completionState',case when p_action='approve' then 'waived' else 'open' end,
        'isNA',p_action='approve','naRequestedBy',null);
    when 'undo' then
      if coalesce(item->>'completionState','open') = 'open' and item->>'completedOn' is null and item->>'isNA' is distinct from 'true' then
        return row_record;
      end if;
      item := item || jsonb_build_object('completionState','open','completedOn',null,'completedOnTs',null,
        'completionResult',null,'isNA',false,'naReason',null,'naRequestedBy',null);
    else
      raise exception 'Unknown checklist action.';
  end case;
  item := item || jsonb_build_object('deadlineMissed',coalesce(missed,false),'completionEvents',
    coalesce(item->'completionEvents','[]') || jsonb_build_array(jsonb_build_object(
      'action',p_action,'at',stamp,'actorId',actor,'dueOn',due,'reason',reason,
      'result',item->>'completionResult','deadlineMissed',coalesce(missed,false))));
  update public.session_checklists set items=jsonb_set(items,array[p_index::text],item)
    where id=p_row returning * into row_record;
  return row_record;
end $$;

create or replace function public.change_trainer_checklist_item(
  p_row text, p_index integer, p_task text, p_action text, p_reason text default null,
  p_phase text default null, p_days integer default null
)
returns public.session_checklists language sql security invoker set search_path = '' as $$
  select trainer_checklist_private.change_trainer_checklist_item(p_row,p_index,p_task,p_action,p_reason,p_phase,p_days)
$$;

-- Only the exposed, invoker-mode wrapper is callable as a Data API RPC.
grant usage on schema trainer_checklist_private to authenticated;
revoke all on function trainer_checklist_private.change_trainer_checklist_item(text,integer,text,text,text,text,integer) from public, anon;
revoke all on function public.change_trainer_checklist_item(text,integer,text,text,text,text,integer) from public, anon;
grant execute on function trainer_checklist_private.change_trainer_checklist_item(text,integer,text,text,text,text,integer) to authenticated;
grant execute on function public.change_trainer_checklist_item(text,integer,text,text,text,text,integer) to authenticated;

update public.checklist_templates t set items=(
  select coalesce(jsonb_agg(i order by n),'[]') from jsonb_array_elements(t.items) with ordinality entries(i,n)
    where trainer_checklist_private.trainer_checklist_item_kind(t.title,i) is distinct from 'schedule'
)
where lower(btrim(t.title))='standard ilt checklist';

commit;
