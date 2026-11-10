-- v5.16 — Department Performance, Phase 1
-- What:  (1) kpi_targets gains department KPI fields (kpi_level, tier, dimension, scored, frequency, target_max,
--            rating_scale, owner_id, sort_order) and role 'department'; 11 department KPI rows seeded with the
--            agreed targets/weights (70% Strategic / 30% Operational), effective 2026-10-01 (provisional).
--            Keys are prefixed dp_ so they never collide with the individual/Overview KPI keys.
--        (2) New table department_kpi_snapshots: frozen quarter results ("Finalize quarter"), re-open logged.
--        (3) training_sessions.cancel_reason / cancel_note: why a session was cancelled (Session Delivery Rate).
-- Why:   Department Performance scorecard (framework doc "L&D Department KPI Framework", Sandra 2026-10-30).
-- Date:  2026-10-30 · Asked by: Sandra Barlao ("ok go") · Status: APPLIED LIVE 2026-10-30 (additive; live v5.14a ignores
--        the new columns, the dp_ rows (role 'department' is not shown on live) and the new table)
-- Additive/idempotent.

-- (1) kpi_targets
alter table public.kpi_targets add column if not exists kpi_level text not null default 'individual';
alter table public.kpi_targets add column if not exists tier text;
alter table public.kpi_targets add column if not exists dimension text;
alter table public.kpi_targets add column if not exists scored boolean not null default true;
alter table public.kpi_targets add column if not exists frequency text;
alter table public.kpi_targets add column if not exists target_max numeric;
alter table public.kpi_targets add column if not exists rating_scale text;
alter table public.kpi_targets add column if not exists owner_id uuid references public.profiles(id) on delete set null;
alter table public.kpi_targets add column if not exists sort_order int;

alter table public.kpi_targets drop constraint if exists kpi_targets_role_check;
alter table public.kpi_targets add constraint kpi_targets_role_check check (role = any (array['id','cd','delivery','department']));
alter table public.kpi_targets drop constraint if exists kpi_targets_dept_fields_chk;
alter table public.kpi_targets add constraint kpi_targets_dept_fields_chk check (
  kpi_level in ('individual','department')
  and (tier is null or tier in ('strategic','operational'))
  and (dimension is null or dimension in ('execution','quality','effectiveness','capability','growth'))
  and (frequency is null or frequency in ('monthly','quarterly'))
);

insert into public.kpi_targets (role, kpi_key, kpi_name, data_source, target, target_max, weight, effective_from,
                                kpi_level, tier, dimension, scored, frequency, rating_scale, owner_id, sort_order)
select 'department', v.k, v.n, v.src, v.t, v.tmax, v.w, date '2026-10-01',
       'department', v.tier, v.dim, true, v.freq, v.scale, '025a9ffb-2de4-4242-b157-24d29a811374'::uuid, v.ord
from (values
  ('dp_ppd',  'Planned Program Delivery',          'committed_projects', 90::numeric,  null::numeric, 18::numeric, 'strategic',   'execution',     'quarterly', 'pct_target', 1),
  ('dp_csat', 'Learner Satisfaction (CSAT)',       'training_reports',   4.2,          null,          12,          'strategic',   'quality',       'monthly',   'r5_target',  2),
  ('dp_gain', 'Knowledge Gain (normalised)',       'l2_assessments',     20,           null,          17,          'strategic',   'effectiveness', 'quarterly', 'pct_target', 3),
  ('dp_l3',   'Behavioural Effectiveness (L3)',    'l3_followups',       60,           null,          14,          'strategic',   'effectiveness', 'quarterly', 'pct_target', 4),
  ('dp_cert', 'Coaching Certification L1 Pass Rate','certification',     75,           null,          9,           'strategic',   'capability',    'quarterly', 'pct_target', 5),
  ('dp_sdr',  'Session Delivery Rate',             'training_calendar',  90,           null,          6,           'operational', 'execution',     'monthly',   'pct_target', 6),
  ('dp_util', 'Trainer Utilisation',               'trainer_capacity',   65,           85,            4,           'operational', 'execution',     'monthly',   'band',       7),
  ('dp_nps',  'Net Promoter Score (NPS)',          'training_reports',   85,           null,          5,           'operational', 'quality',       'monthly',   'nps_target', 8),
  ('dp_qae',  'QA Endorse Rate (ID + CD)',         'qa_reviews',         80,           null,          5,           'operational', 'quality',       'monthly',   'pct_target', 9),
  ('dp_otd',  'On-time Deliverables (ID + CD)',    'qa_timeliness',      90,           null,          5,           'operational', 'execution',     'monthly',   'pct_target', 10),
  ('dp_sla',  'Training Report SLA',               'training_reports',   95,           null,          5,           'operational', 'execution',     'monthly',   'pct_target', 11)
) as v(k, n, src, t, tmax, w, tier, dim, freq, scale, ord)
where not exists (select 1 from public.kpi_targets x where x.role = 'department' and x.kpi_key = v.k);

-- (2) frozen quarter results
create table if not exists public.department_kpi_snapshots (
  id uuid primary key default gen_random_uuid(),
  period_key text not null unique,            -- e.g. '2026-Q4'
  results jsonb not null,
  status text not null default 'final' check (status in ('final','reopened')),
  finalized_at timestamptz not null default now(),
  finalized_by uuid references public.profiles(id),
  reopened_at timestamptz,
  reopened_by uuid references public.profiles(id),
  reopen_reason text
);
alter table public.department_kpi_snapshots enable row level security;
drop policy if exists dks_read on public.department_kpi_snapshots;
create policy dks_read on public.department_kpi_snapshots for select to authenticated
  using (public.is_admin() or exists (select 1 from public.profiles p where p.id = auth.uid() and (p.is_reports_viewer or p.dash_scope = 'full')));
drop policy if exists dks_write on public.department_kpi_snapshots;
create policy dks_write on public.department_kpi_snapshots for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- (3) cancellation reason
alter table public.training_sessions add column if not exists cancel_reason text;
alter table public.training_sessions add column if not exists cancel_note text;
alter table public.training_sessions drop constraint if exists training_sessions_cancel_reason_chk;
alter table public.training_sessions add constraint training_sessions_cancel_reason_chk check (
  cancel_reason is null or cancel_reason in ('rescheduled','business','low_enrolment','trainer','content','logistics','other'));
