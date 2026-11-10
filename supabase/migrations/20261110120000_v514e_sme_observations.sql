-- v5.14e (2026-11-10, per Sandra) — SME Facilitation Observation.
-- What: new table sme_observations. For sessions tagged "Training Report not required — SME-led",
--       the co-facilitator (or anyone with Trainer Evaluation form access) completes the Basic
--       Facilitation Skills – Facilitation Validation Form for the SME: 16 behaviors (8 critical),
--       N/O + 1–4 ratings, evidence notes, capability summary, recommended + final decision.
--       Workflow is Draft -> Submitted (complete). No acknowledgement (SMEs have no LEAP access);
--       feedback is sent externally as a PDF. Not counted in any L&D scorecard.
-- Why:  SME-led sessions skip the Training Report; Sandra wants SME facilitation feedback instead.
-- Additive only. Released straight to live per Sandra ("go", 2026-11-10).
-- RELEASED 2026-11-10

create table if not exists public.sme_observations (
  id text primary key,
  session_id text not null references public.training_sessions(id) on delete cascade,
  sme_name text,
  sme_dept_role text,
  assessor_id uuid references public.profiles(id),
  assessor_role text,
  validation_date date,
  validation_type text,
  topic text,
  duration_observed text,
  setting text,
  ratings jsonb not null default '{}'::jsonb,
  evidence jsonb not null default '{}'::jsonb,
  overall_avg numeric(4,2),
  critical_below integer,
  critical_unobserved integer,
  recommended_decision text,
  final_decision text,
  strengths text,
  priority_dev text,
  follow_up text,
  follow_up_focus text,
  comments text,
  status text not null default 'draft' check (status in ('draft','submitted')),
  submitted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists sme_observations_session_idx on public.sme_observations(session_id);

alter table public.sme_observations enable row level security;

drop policy if exists sme_obs_select on public.sme_observations;
create policy sme_obs_select on public.sme_observations for select to authenticated
  using (
    assessor_id = auth.uid() or public.is_admin() or public.is_reports_viewer()
    or exists (select 1 from public.profiles p where p.id = auth.uid() and coalesce(p.form_trainer,false))
    or exists (select 1 from public.training_sessions s where s.id = session_id
               and public.can_edit_training_session(s.trainer_id, s.co_facilitator_id, s.created_by))
  );

drop policy if exists sme_obs_insert on public.sme_observations;
create policy sme_obs_insert on public.sme_observations for insert to authenticated
  with check (
    (assessor_id = auth.uid() or public.is_admin())
    and (public.is_admin()
      or exists (select 1 from public.profiles p where p.id = auth.uid() and coalesce(p.form_trainer,false))
      or exists (select 1 from public.training_sessions s where s.id = session_id
                 and public.can_edit_training_session(s.trainer_id, s.co_facilitator_id, s.created_by)))
  );

drop policy if exists sme_obs_update on public.sme_observations;
create policy sme_obs_update on public.sme_observations for update to authenticated
  using ((assessor_id = auth.uid() and status = 'draft') or public.is_admin())
  with check (assessor_id = auth.uid() or public.is_admin());

drop policy if exists sme_obs_delete on public.sme_observations;
create policy sme_obs_delete on public.sme_observations for delete to authenticated
  using ((assessor_id = auth.uid() and status = 'draft') or public.is_admin());

grant select, insert, update, delete on public.sme_observations to authenticated;
