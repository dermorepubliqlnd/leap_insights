-- v5.16c — Department Performance Phase 3: Committed Projects tracker
-- What:  New tables committed_projects (quarterly/annual L&D commitments) and committed_project_events (change history).
--        Seeded with the Q4 2026 baseline approved by Sandra on 2026-10-30: the four commitments presented to Brad
--        (Data Privacy one Taglish version; CSR Course 1 in Q4 with Courses 2–3 deferred to 2027; FDA Compliance Claims
--        design; DermoU Phase 2 scoping) + two approved insertions (Foundational Leadership – Engage Session 1; SCM
--        Onboarding scoping + design), plus COBC (on hold) and People Leader Onboarding (pipeline), which are not counted.
--        A commitment can only be marked Delivered with evidence (link or linked session / QA review).
-- Why:   Planned Program Delivery KPI = delivered approved commitments ÷ approved commitments (framework doc, 2026-10-30).
-- Date:  2026-10-30 · Asked by: Sandra Barlao ("Yes, build it") · Status: APPLIED LIVE 2026-10-30 (additive; not used by live v5.14a)
-- Additive/idempotent.

create table if not exists public.committed_projects (
  id uuid primary key default gen_random_uuid(),
  period_key text not null,                         -- e.g. '2026-Q4'
  title text not null,
  program_id text,                                  -- learning_programs.id (optional)
  owner_id uuid references public.profiles(id) on delete set null,
  milestone text not null default 'deploy' check (milestone in ('deploy','design','scoping','other')),
  milestone_note text,
  original_due date,
  revised_due date,
  commit_type text not null default 'original' check (commit_type in ('original','insertion','deferral','unplanned')),
  status text not null default 'open' check (status in ('proposed','open','at_risk','delivered','deferred','on_hold','pipeline')),
  evidence_url text,
  evidence_note text,
  linked_session_id text,
  linked_review_id text,
  delivered_on date,
  delivered_confirmed_by uuid references public.profiles(id),
  approval_by uuid references public.profiles(id),
  approval_at timestamptz,
  approval_note text,
  sort_order int,
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint committed_projects_delivered_evidence_chk check (
    status <> 'delivered' or coalesce(evidence_url, linked_session_id, linked_review_id) is not null)
);
create index if not exists committed_projects_period_idx on public.committed_projects(period_key, sort_order);

create table if not exists public.committed_project_events (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.committed_projects(id) on delete cascade,
  at timestamptz not null default now(),
  actor_id uuid,
  action text not null,
  detail text
);
create index if not exists committed_project_events_project_idx on public.committed_project_events(project_id, at);

alter table public.committed_projects enable row level security;
alter table public.committed_project_events enable row level security;
-- read: Department Performance viewers (admin, Reports Viewer, Dashboard Access = Full View)
drop policy if exists cp_read on public.committed_projects;
create policy cp_read on public.committed_projects for select to authenticated
  using (public.is_admin() or exists (select 1 from public.profiles p where p.id = auth.uid() and (p.is_reports_viewer or p.dash_scope = 'full')));
-- viewers may propose (status 'proposed'); everything else is admin-only (Sandra approves)
drop policy if exists cp_propose on public.committed_projects;
create policy cp_propose on public.committed_projects for insert to authenticated
  with check (public.is_admin() or (status = 'proposed' and exists (select 1 from public.profiles p where p.id = auth.uid() and (p.is_reports_viewer or p.dash_scope = 'full'))));
drop policy if exists cp_admin_update on public.committed_projects;
create policy cp_admin_update on public.committed_projects for update to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists cp_admin_delete on public.committed_projects;
create policy cp_admin_delete on public.committed_projects for delete to authenticated using (public.is_admin());
drop policy if exists cpe_read on public.committed_project_events;
create policy cpe_read on public.committed_project_events for select to authenticated
  using (public.is_admin() or exists (select 1 from public.profiles p where p.id = auth.uid() and (p.is_reports_viewer or p.dash_scope = 'full')));
drop policy if exists cpe_insert on public.committed_project_events;
create policy cpe_insert on public.committed_project_events for insert to authenticated
  with check (public.is_admin() or exists (select 1 from public.profiles p where p.id = auth.uid() and (p.is_reports_viewer or p.dash_scope = 'full')));

-- Q4 2026 baseline (approved by Sandra 2026-10-30)
do $$
declare
  v_sandra uuid := '025a9ffb-2de4-4242-b157-24d29a811374';
  v_note text := 'Q4 baseline from the slide presented to Brad + Joseph''s reply (6 Oct 2026); approved by Sandra 2026-10-30';
  r record;
begin
  if exists (select 1 from public.committed_projects where period_key = '2026-Q4') then return; end if;
  for r in select * from (values
    (1,'Data Privacy Training (All & Leaders)','deploy','Ready to deploy in Q4 — one Taglish version','original','open','Scope change approved 2026-10-30: one Taglish version instead of separate versions (per Joseph)',null::date),
    (2,'CSR Capability Training — Course 1','deploy','Course 1 of 3 (LEAP format) deployed in Q4','original','open','Revised 2026-10-30: full delivery in Q4 not possible; Course 1 in Q4, Courses 2–3 deferred to 2027 (per Joseph)',null),
    (3,'CSR Capability Training — Courses 2–3','deploy','Deferred to 2027','deferral','deferred','Deferral approved 2026-10-30 (originally part of "full delivery within Q4 2026")',null),
    (4,'FDA Compliance Claims Training','design','Full design and recommendations completed by end of Q4; roll-out Q1 2027','original','open',null,null),
    (5,'DermoU Phase 2','scoping','Requirements gathering and assessment of Phase 2 scope completed; development Q1 2027','original','open',null,null),
    (6,'Foundational Leadership — Engage, Session 1','deploy','Session 1 deployed in Q4; Session 2 likely 2027','insertion','open','Insertion approved 2026-10-30 (not on the Brad slide)',null),
    (7,'SCM Onboarding Program (Production, Fulfillment, Warehouse, Inventory, Logistics)','design','Scoping and design in Q4; development starts 2027','insertion','open','Insertion approved 2026-10-30 (not on the Brad slide)',null),
    (8,'COBC','other','On hold — SME dependency','unplanned','on_hold',null,null),
    (9,'People Leader Onboarding','other','No commitment yet — worth considering','unplanned','pipeline',null,null)
  ) as t(ord,title,milestone,mnote,ctype,status,anote,rev) loop
    with ins as (
      insert into public.committed_projects (period_key,title,milestone,milestone_note,original_due,revised_due,commit_type,status,approval_by,approval_at,approval_note,sort_order,created_by)
      values ('2026-Q4',r.title,r.milestone,r.mnote,date '2026-12-31',r.rev,r.ctype,r.status,
              case when r.anote is not null or r.ctype in ('original') then v_sandra end,
              case when r.anote is not null or r.ctype in ('original') then now() end,
              coalesce(r.anote, case when r.ctype='original' then 'Presented to Brad (Q4 2026 Commitments)' end), r.ord, v_sandra)
      returning id)
    insert into public.committed_project_events (project_id, actor_id, action, detail) select id, v_sandra, 'baseline', v_note from ins;
  end loop;
end $$;
