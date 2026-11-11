-- v5.18 (2026-11-11, per Sandra) — QA Calibration, Phase 1 (CD QA form). PREVIEW.
-- What: new, separate calibration records. Team members independently rate the same output with the
--       CD QA criteria (all 17 shown, each may be rated 2/1/0 or N/A with a reason), then the exercise
--       owner releases anonymized results (Evaluator A, B, C…) for the calibration discussion and records
--       agreed ratings, applicability recommendations and learning points.
-- Tables: calibration_exercises, calibration_subjects (person being evaluated — owner/admin only),
--         calibration_submissions (one per evaluator per exercise), calibration_decisions (per criterion).
-- RPCs:   calibration_counts(), calibration_participation(uuid), calibration_results(uuid).
-- Rules:  deadline enforced server-side (no insert/update after deadline_at); results visible to the owner/admin
--         only after the deadline, to the roster only after release; evaluator names never leave the DB for
--         non-owners; nothing here touches cdqa_reviews, scorecards, KPIs or acknowledgements.
-- Statuses: draft -> open -> (closed = open past deadline, computed) -> released -> finalized.
-- Preview gate: every write requires public.calib_channel_ok() (= preview header). At release, a release
--         migration replaces calib_channel_ok() to return true. Live code does not read these tables.
-- Additive only; idempotent guards. Asked by: Sandra Barlao.

-- ── helpers ──────────────────────────────────────────────────────────────────────────────────────
create or replace function public.calib_channel_ok()
returns boolean language sql stable set search_path = public as $$
  select public.is_preview_request();
$$;

-- admins and anyone with an active direct report may create exercises
create or replace function public.calib_can_create()
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_admin() or exists (select 1 from public.profiles p where p.supervisor_id = auth.uid() and p.is_active);
$$;

-- ── exercises ────────────────────────────────────────────────────────────────────────────────────
create table if not exists public.calibration_exercises (
  id uuid primary key default gen_random_uuid(),
  code text unique,
  title text not null,
  form_type text not null default 'cdqa' check (form_type in ('cdqa','idqa','trainer_eval')),
  criteria_version integer not null default 2,
  content_type text,
  item_title text,
  resources jsonb not null default '[]'::jsonb,
  instructions text,
  deadline_at timestamptz,
  discussion_at timestamptz,
  discussion_end_at timestamptz,
  meeting_link text,
  location text,
  status text not null default 'draft' check (status in ('draft','open','released','finalized')),
  roster uuid[] not null default '{}',
  matrix_snapshot jsonb,
  summary jsonb not null default '{}'::jsonb,
  archived boolean not null default false,
  created_by uuid references public.profiles(id) default auth.uid(),
  published_at timestamptz,
  released_at timestamptz,
  finalized_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- owner = creator or admin
create or replace function public.calib_is_owner(p_ex uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select public.is_admin() or exists (select 1 from public.calibration_exercises e where e.id = p_ex and e.created_by = auth.uid());
$$;

create or replace function public.calib_exercise_guard()
returns trigger language plpgsql security definer set search_path = public as $$
declare v_prefix text;
begin
  if tg_op = 'INSERT' then
    if new.status <> 'draft' then raise exception 'New calibration exercises start as Draft.'; end if;
    if new.code is null then
      v_prefix := 'CAL-' || to_char(now() at time zone 'Asia/Manila', 'YYMM') || '-';
      select v_prefix || lpad((coalesce(max(nullif(substr(code, length(v_prefix) + 1), '')::int), 0) + 1)::text, 3, '0')
        into new.code from public.calibration_exercises where code like v_prefix || '%';
    end if;
    new.created_at := now(); new.updated_at := now();
    return new;
  end if;

  -- UPDATE
  if old.status = 'finalized' and not public.is_admin() then
    raise exception 'This calibration exercise is finalized (read-only).';
  end if;
  if old.status <> 'draft' then
    -- locked after publication
    new.form_type := old.form_type; new.criteria_version := old.criteria_version; new.content_type := old.content_type;
    new.roster := old.roster; new.matrix_snapshot := old.matrix_snapshot; new.published_at := old.published_at;
    new.created_by := old.created_by; new.code := old.code;
  end if;

  if new.status is distinct from old.status then
    if old.status = 'draft' and new.status = 'open' then
      if coalesce(trim(new.title), '') = '' or coalesce(trim(new.item_title), '') = '' or coalesce(new.content_type, '') = '' then
        raise exception 'Title, content type and the output being evaluated are required before publishing.';
      end if;
      if new.deadline_at is null or new.deadline_at <= now() then raise exception 'The submission deadline must be in the future.'; end if;
      if new.discussion_at is null or new.discussion_at <= new.deadline_at then raise exception 'The calibration discussion must be scheduled after the submission deadline.'; end if;
      new.roster := array(select p.id from public.profiles p where p.is_active order by p.first_name, p.last_name);
      new.published_at := now();
    elsif old.status = 'open' and new.status = 'released' then
      if now() < coalesce(new.deadline_at, old.deadline_at) then raise exception 'Results can be released only after the submission deadline.'; end if;
      new.released_at := now();
    elsif old.status = 'released' and new.status = 'finalized' then
      new.finalized_at := now();
    elsif old.status = 'finalized' and new.status = 'released' and public.is_admin() then
      new.finalized_at := null; -- admin reopen (audit-logged by the app)
    else
      raise exception 'Status change % -> % is not allowed.', old.status, new.status;
    end if;
  end if;

  if new.discussion_at is not null and new.deadline_at is not null and new.discussion_at <= new.deadline_at then
    raise exception 'The calibration discussion must be scheduled after the submission deadline.';
  end if;
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists calibration_exercises_guard on public.calibration_exercises;
create trigger calibration_exercises_guard before insert or update on public.calibration_exercises
  for each row execute function public.calib_exercise_guard();

alter table public.calibration_exercises enable row level security;

drop policy if exists calib_ex_select on public.calibration_exercises;
create policy calib_ex_select on public.calibration_exercises for select to authenticated
  using (public.is_admin() or created_by = auth.uid() or (status <> 'draft' and auth.uid() = any(roster)));

drop policy if exists calib_ex_insert on public.calibration_exercises;
create policy calib_ex_insert on public.calibration_exercises for insert to authenticated
  with check (public.calib_channel_ok() and public.calib_can_create() and created_by = auth.uid());

drop policy if exists calib_ex_update on public.calibration_exercises;
create policy calib_ex_update on public.calibration_exercises for update to authenticated
  using (public.calib_channel_ok() and (public.is_admin() or created_by = auth.uid()))
  with check (public.calib_channel_ok() and (public.is_admin() or created_by = auth.uid()));

drop policy if exists calib_ex_delete on public.calibration_exercises;
create policy calib_ex_delete on public.calibration_exercises for delete to authenticated
  using (public.calib_channel_ok() and status = 'draft' and (public.is_admin() or created_by = auth.uid()));

grant select, insert, update, delete on public.calibration_exercises to authenticated;

-- ── person being evaluated (owner/admin only) ────────────────────────────────────────────────────
create table if not exists public.calibration_subjects (
  exercise_id uuid primary key references public.calibration_exercises(id) on delete cascade,
  subject_profile_id uuid references public.profiles(id),
  subject_name text,
  updated_at timestamptz not null default now()
);
alter table public.calibration_subjects enable row level security;

drop policy if exists calib_subj_select on public.calibration_subjects;
create policy calib_subj_select on public.calibration_subjects for select to authenticated
  using (public.calib_is_owner(exercise_id));

drop policy if exists calib_subj_write on public.calibration_subjects;
create policy calib_subj_write on public.calibration_subjects for all to authenticated
  using (public.calib_channel_ok() and public.calib_is_owner(exercise_id))
  with check (public.calib_channel_ok() and public.calib_is_owner(exercise_id));

grant select, insert, update, delete on public.calibration_subjects to authenticated;

-- ── submissions ──────────────────────────────────────────────────────────────────────────────────
create table if not exists public.calibration_submissions (
  id uuid primary key default gen_random_uuid(),
  exercise_id uuid not null references public.calibration_exercises(id) on delete cascade,
  evaluator_id uuid not null default auth.uid() references public.profiles(id),
  ratings jsonb not null default '{}'::jsonb,   -- {C1: 2|1|0|"NA"}
  remarks jsonb not null default '{}'::jsonb,
  observations text,
  score_pct numeric(5,2),
  disposition text,
  status text not null default 'draft' check (status in ('draft','submitted')),
  submitted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (exercise_id, evaluator_id)
);
create index if not exists calibration_submissions_ex_idx on public.calibration_submissions(exercise_id);

-- true while the exercise is open, before its deadline, and the caller is on the roster
create or replace function public.calib_can_submit(p_ex uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.calibration_exercises e
                 where e.id = p_ex and e.status = 'open' and now() < e.deadline_at and auth.uid() = any(e.roster));
$$;

create or replace function public.calib_submission_guard()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'UPDATE' then
    if old.status = 'submitted' then raise exception 'This calibration evaluation was already submitted.'; end if;
    new.exercise_id := old.exercise_id; new.evaluator_id := old.evaluator_id; new.created_at := old.created_at;
  end if;
  if not public.calib_can_submit(new.exercise_id) then
    raise exception 'Submissions for this calibration exercise are closed.';
  end if;
  if new.status = 'submitted' then new.submitted_at := now(); else new.submitted_at := null; end if;
  new.updated_at := now();
  return new;
end $$;

drop trigger if exists calibration_submissions_guard on public.calibration_submissions;
create trigger calibration_submissions_guard before insert or update on public.calibration_submissions
  for each row execute function public.calib_submission_guard();

alter table public.calibration_submissions enable row level security;

-- own rows always; owner/admin sees others only after the deadline (so an owner who also rates stays independent)
drop policy if exists calib_sub_select on public.calibration_submissions;
create policy calib_sub_select on public.calibration_submissions for select to authenticated
  using (evaluator_id = auth.uid()
    or (public.calib_is_owner(exercise_id) and exists (select 1 from public.calibration_exercises e
          where e.id = exercise_id and (e.status in ('released','finalized') or now() >= e.deadline_at))));

drop policy if exists calib_sub_insert on public.calibration_submissions;
create policy calib_sub_insert on public.calibration_submissions for insert to authenticated
  with check (public.calib_channel_ok() and evaluator_id = auth.uid() and public.calib_can_submit(exercise_id));

drop policy if exists calib_sub_update on public.calibration_submissions;
create policy calib_sub_update on public.calibration_submissions for update to authenticated
  using (public.calib_channel_ok() and evaluator_id = auth.uid() and status = 'draft')
  with check (public.calib_channel_ok() and evaluator_id = auth.uid() and public.calib_can_submit(exercise_id));

drop policy if exists calib_sub_delete on public.calibration_submissions;
create policy calib_sub_delete on public.calibration_submissions for delete to authenticated
  using (public.calib_channel_ok() and evaluator_id = auth.uid() and status = 'draft' and public.calib_can_submit(exercise_id));

grant select, insert, update, delete on public.calibration_submissions to authenticated;

-- ── decisions (per criterion) ────────────────────────────────────────────────────────────────────
create table if not exists public.calibration_decisions (
  exercise_id uuid not null references public.calibration_exercises(id) on delete cascade,
  criterion_id text not null,
  agreed_rating text check (agreed_rating in ('2','1','0','NA')),
  matrix_rec text check (matrix_rec in ('keep','update','conditional','separate','review')),
  rationale text,
  unresolved boolean not null default false,
  follow_up text,
  updated_by uuid default auth.uid() references public.profiles(id),
  updated_at timestamptz not null default now(),
  primary key (exercise_id, criterion_id)
);
alter table public.calibration_decisions enable row level security;

drop policy if exists calib_dec_select on public.calibration_decisions;
create policy calib_dec_select on public.calibration_decisions for select to authenticated
  using (public.calib_is_owner(exercise_id)
    or exists (select 1 from public.calibration_exercises e where e.id = exercise_id
               and e.status in ('released','finalized') and auth.uid() = any(e.roster)));

drop policy if exists calib_dec_write on public.calibration_decisions;
create policy calib_dec_write on public.calibration_decisions for all to authenticated
  using (public.calib_channel_ok() and public.calib_is_owner(exercise_id)
    and exists (select 1 from public.calibration_exercises e where e.id = exercise_id and e.status = 'released'))
  with check (public.calib_channel_ok() and public.calib_is_owner(exercise_id)
    and exists (select 1 from public.calibration_exercises e where e.id = exercise_id and e.status = 'released'));

grant select, insert, update, delete on public.calibration_decisions to authenticated;

-- ── RPCs ─────────────────────────────────────────────────────────────────────────────────────────
-- participation counts for every exercise the caller can see (no names, no ratings)
create or replace function public.calibration_counts()
returns table (exercise_id uuid, roster_count integer, submitted_count integer, draft_count integer)
language sql stable security definer set search_path = public as $$
  select e.id, coalesce(array_length(e.roster, 1), 0),
         (select count(*)::int from public.calibration_submissions s where s.exercise_id = e.id and s.status = 'submitted'),
         (select count(*)::int from public.calibration_submissions s where s.exercise_id = e.id and s.status = 'draft')
  from public.calibration_exercises e
  where public.is_admin() or e.created_by = auth.uid() or (e.status <> 'draft' and auth.uid() = any(e.roster));
$$;

-- who has / hasn't submitted (owner/admin only; no ratings)
create or replace function public.calibration_participation(p_ex uuid)
returns table (profile_id uuid, status text, submitted_at timestamptz, updated_at timestamptz)
language sql stable security definer set search_path = public as $$
  select r.pid, coalesce(s.status, 'not_started'), s.submitted_at, s.updated_at
  from public.calibration_exercises e
  cross join lateral unnest(e.roster) as r(pid)
  left join public.calibration_submissions s on s.exercise_id = e.id and s.evaluator_id = r.pid
  where e.id = p_ex and public.calib_is_owner(p_ex);
$$;

-- anonymized results: owner/admin after the deadline (with evaluator ids); roster after release (ids hidden)
create or replace function public.calibration_results(p_ex uuid)
returns table (label text, evaluator_id uuid, is_me boolean, ratings jsonb, remarks jsonb, observations text,
               score_pct numeric, disposition text, submitted_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
declare e public.calibration_exercises; v_owner boolean;
begin
  select * into e from public.calibration_exercises where id = p_ex;
  if not found then return; end if;
  v_owner := public.calib_is_owner(p_ex);
  if not ((v_owner and (e.status in ('released','finalized') or now() >= e.deadline_at))
          or (e.status in ('released','finalized') and auth.uid() = any(e.roster))) then
    raise exception 'Results are not available yet.';
  end if;
  return query
    select 'Evaluator ' || chr(64 + (row_number() over (order by s.id))::int),
           case when v_owner then s.evaluator_id else null end,
           s.evaluator_id = auth.uid(), s.ratings, s.remarks, s.observations, s.score_pct, s.disposition, s.submitted_at
    from public.calibration_submissions s
    where s.exercise_id = p_ex and s.status = 'submitted'
    order by s.id;
end $$;

grant execute on function public.calib_channel_ok() to authenticated;
grant execute on function public.calib_can_create() to authenticated;
grant execute on function public.calib_is_owner(uuid) to authenticated;
grant execute on function public.calib_can_submit(uuid) to authenticated;
grant execute on function public.calibration_counts() to authenticated;
grant execute on function public.calibration_participation(uuid) to authenticated;
grant execute on function public.calibration_results(uuid) to authenticated;
