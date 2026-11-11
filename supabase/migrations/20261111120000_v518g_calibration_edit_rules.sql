-- v5.18g (2026-11-11, per Sandra) — QA Calibration: progressive editing restrictions + amendment trail. PREVIEW.
-- What:
--   * calibration_amendments: visible trail (and in-app notice) of every change after publishing — deadline extended,
--     closed early, session date / meeting link changed, clarifications, admin corrections, archive/unarchive.
--   * calib_exercise_guard (replaced): after publishing — form + content type locked (as before); material name and
--     reference links locked once anyone has started an evaluation; instructions can never be silently replaced
--     (add a clarification instead); deadline may only be extended before it passes, or closed early; only finalized
--     calibrations can be archived. Admin corrections go through calibration_amend() (reason required, recorded).
--   * calib_subject_guard: person being evaluated locked once anyone has started an evaluation.
-- Why: no silent changes that could make evaluators assess different materials or criteria.
-- Additive; replaces only calibration functions created in 20261111090000. Asked by: Sandra Barlao.

create table if not exists public.calibration_amendments (
  id uuid primary key default gen_random_uuid(),
  exercise_id uuid not null references public.calibration_exercises(id) on delete cascade,
  kind text not null check (kind in ('deadline_extended','closed_early','session_changed','meeting_changed','clarification','correction','archived','unarchived')),
  old_value text,
  new_value text,
  note text,
  created_by uuid default auth.uid() references public.profiles(id),
  created_at timestamptz not null default now()
);
create index if not exists calibration_amendments_ex_idx on public.calibration_amendments(exercise_id, created_at desc);
alter table public.calibration_amendments enable row level security;

drop policy if exists calib_amd_select on public.calibration_amendments;
create policy calib_amd_select on public.calibration_amendments for select to authenticated
  using (public.calib_is_owner(exercise_id)
    or exists (select 1 from public.calibration_exercises e where e.id = exercise_id and e.status <> 'draft' and auth.uid() = any(e.roster)));

-- owners add clarifications directly; every other kind is written by the trigger / RPC below
drop policy if exists calib_amd_insert on public.calibration_amendments;
create policy calib_amd_insert on public.calibration_amendments for insert to authenticated
  with check (public.calib_channel_ok() and kind = 'clarification' and coalesce(trim(note), '') <> ''
    and public.calib_is_owner(exercise_id)
    and exists (select 1 from public.calibration_exercises e where e.id = exercise_id and e.status in ('open','released')));
grant select, insert on public.calibration_amendments to authenticated;

create or replace function public.calib_started(p_ex uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.calibration_submissions s where s.exercise_id = p_ex);
$$;
grant execute on function public.calib_started(uuid) to authenticated;

create or replace function public.calib_exercise_guard()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_prefix text; v_amend boolean; v_started boolean;
begin
  if tg_op = 'INSERT' then
    if new.status <> 'draft' then raise exception 'New calibrations start as Draft.'; end if;
    if new.code is null then
      v_prefix := 'CAL-' || to_char(now() at time zone 'Asia/Manila', 'YYMM') || '-';
      select v_prefix || lpad((coalesce(max(nullif(substr(code, length(v_prefix) + 1), '')::int), 0) + 1)::text, 3, '0')
        into new.code from public.calibration_exercises where code like v_prefix || '%';
    end if;
    new.created_at := now(); new.updated_at := now();
    return new;
  end if;

  if old.status = 'finalized' and not public.is_admin() then
    raise exception 'This calibration is finalized (read-only).';
  end if;

  if old.status <> 'draft' then
    new.form_type := old.form_type; new.criteria_version := old.criteria_version; new.content_type := old.content_type;
    new.roster := old.roster; new.matrix_snapshot := old.matrix_snapshot; new.published_at := old.published_at;
    new.created_by := old.created_by; new.code := old.code;

    v_amend := coalesce(current_setting('calib.amend', true), '') = 'on';
    v_started := public.calib_started(old.id);

    if not v_amend and v_started and (new.title is distinct from old.title or new.item_title is distinct from old.item_title
        or new.resources is distinct from old.resources) then
      raise exception 'Evaluations have started, so the material name and reference links are locked. Ask an admin to record a correction, or create a new calibration if the material changed.';
    end if;
    if not v_amend and new.instructions is distinct from old.instructions then
      raise exception 'Instructions cannot be replaced after publishing. Add a clarification instead.';
    end if;

    if new.deadline_at is distinct from old.deadline_at then
      if now() < old.deadline_at and new.deadline_at > old.deadline_at then
        insert into public.calibration_amendments(exercise_id, kind, old_value, new_value)
          values (old.id, 'deadline_extended', old.deadline_at::text, new.deadline_at::text);
      elsif now() < old.deadline_at and new.deadline_at <= now() then
        insert into public.calibration_amendments(exercise_id, kind, old_value, new_value)
          values (old.id, 'closed_early', old.deadline_at::text, new.deadline_at::text);
      else
        raise exception 'The deadline can only be extended before it passes (or submissions closed early).';
      end if;
    end if;
    if new.discussion_at is distinct from old.discussion_at then
      insert into public.calibration_amendments(exercise_id, kind, old_value, new_value)
        values (old.id, 'session_changed', old.discussion_at::text, new.discussion_at::text);
    end if;
    if new.meeting_link is distinct from old.meeting_link then
      insert into public.calibration_amendments(exercise_id, kind, old_value, new_value)
        values (old.id, 'meeting_changed', old.meeting_link, new.meeting_link);
    end if;
    if new.archived is distinct from old.archived then
      if new.archived and old.status <> 'finalized' then
        raise exception 'Only finalized calibrations can be archived.';
      end if;
      insert into public.calibration_amendments(exercise_id, kind) values (old.id, case when new.archived then 'archived' else 'unarchived' end);
    end if;
  end if;

  if new.status is distinct from old.status then
    if old.status = 'draft' and new.status = 'open' then
      if coalesce(trim(new.title), '') = '' or coalesce(new.content_type, '') = '' then
        raise exception 'The material being evaluated and the content type are required before publishing.';
      end if;
      if new.deadline_at is null or new.deadline_at <= now() then raise exception 'The submission deadline must be in the future.'; end if;
      if new.discussion_at is null or new.discussion_at <= new.deadline_at then raise exception 'The calibration session must be after the submission deadline.'; end if;
      new.roster := array(select p.id from public.profiles p where p.is_active order by p.first_name, p.last_name);
      new.published_at := now();
    elsif old.status = 'open' and new.status = 'released' then
      if now() < coalesce(new.deadline_at, old.deadline_at) then raise exception 'Results can be released only after submissions close.'; end if;
      new.released_at := now();
    elsif old.status = 'released' and new.status = 'finalized' then
      new.finalized_at := now();
    elsif old.status = 'finalized' and new.status = 'released' and public.is_admin() then
      new.finalized_at := null;
    else
      raise exception 'Status change % -> % is not allowed.', old.status, new.status;
    end if;
  end if;

  if new.discussion_at is not null and new.deadline_at is not null and new.discussion_at <= new.deadline_at then
    raise exception 'The calibration session must be after the submission deadline.';
  end if;
  new.updated_at := now();
  return new;
end $$;

-- person being evaluated: locked once anyone has started (admin correction excepted)
create or replace function public.calib_subject_guard()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if coalesce(current_setting('calib.amend', true), '') <> 'on'
     and exists (select 1 from public.calibration_exercises e where e.id = new.exercise_id and e.status <> 'draft')
     and public.calib_started(new.exercise_id)
     and (tg_op = 'INSERT' or new.subject_profile_id is distinct from old.subject_profile_id or new.subject_name is distinct from old.subject_name) then
    raise exception 'Evaluations have started, so the person being evaluated is locked.';
  end if;
  new.updated_at := now();
  return new;
end $$;
drop trigger if exists calibration_subjects_guard on public.calibration_subjects;
create trigger calibration_subjects_guard before insert or update on public.calibration_subjects
  for each row execute function public.calib_subject_guard();

-- admin correction after evaluations started (reason required; recorded)
create or replace function public.calibration_amend(p_ex uuid, p_title text, p_resources jsonb, p_reason text)
returns void language plpgsql security definer set search_path = public as $$
declare e public.calibration_exercises;
begin
  if not public.calib_channel_ok() then raise exception 'Not available here.'; end if;
  if not public.is_admin() then raise exception 'Only admins can record a correction.'; end if;
  if coalesce(trim(p_reason), '') = '' then raise exception 'A reason is required for a correction.'; end if;
  select * into e from public.calibration_exercises where id = p_ex;
  if not found then raise exception 'Calibration not found.'; end if;
  if e.status in ('draft','finalized') then raise exception 'Corrections apply only to published, unfinalized calibrations.'; end if;
  perform set_config('calib.amend', 'on', true);
  update public.calibration_exercises
     set title = coalesce(nullif(trim(p_title), ''), title), item_title = coalesce(nullif(trim(p_title), ''), item_title),
         resources = coalesce(p_resources, resources)
   where id = p_ex;
  insert into public.calibration_amendments(exercise_id, kind, old_value, new_value, note)
    values (p_ex, 'correction',
            jsonb_build_object('title', e.title, 'resources', e.resources)::text,
            jsonb_build_object('title', coalesce(nullif(trim(p_title), ''), e.title), 'resources', coalesce(p_resources, e.resources))::text,
            trim(p_reason));
  perform set_config('calib.amend', 'off', true);
end $$;
grant execute on function public.calibration_amend(uuid, text, jsonb, text) to authenticated;
