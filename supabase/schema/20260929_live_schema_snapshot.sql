-- LEAP Insights: live schema snapshot (reference only, NOT a migration)
-- Source: Supabase project catvpurbyvsnijxpzwoh, generated from the system catalogs on 2026-09-29
-- after migration 20260929120200. Covers the public and private schemas: tables, constraints,
-- indexes, RLS, policies, functions, triggers. Does not include auth/storage, grants or data.
--
-- Why this exists: tables created before 2026-09-28 were applied by hand in the SQL editor and
-- were never recorded as migrations, so supabase/migrations/ alone cannot rebuild the database.
-- Use this file to review or rebuild the schema. Do not run it against production.

create schema if not exists private;

-- Extensions
create extension if not exists pg_stat_statements with schema extensions;
create extension if not exists pg_trgm with schema extensions;
create extension if not exists pgcrypto with schema extensions;
create extension if not exists supabase_vault with schema vault;
create extension if not exists "uuid-ossp" with schema extensions;

-- Tables
create table if not exists public.agenda_templates (
  id text not null,
  title text not null,
  items jsonb default '[]'::jsonb not null,
  is_active boolean default true not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table if not exists public.attendance_settings (
  id text default 'default'::text not null,
  late_deduction numeric default 0.25 not null,
  left_early_deduction numeric default 0.25 not null,
  updated_at timestamp with time zone default now() not null
);

create table if not exists public.audiences (
  id text not null,
  name text not null,
  is_active boolean default true not null
);

create table if not exists public.audit_log (
  id uuid default gen_random_uuid() not null,
  ts timestamp with time zone default now() not null,
  actor_id uuid,
  action text not null,
  module text not null,
  entity_id text,
  summary text
);

create table if not exists public.categories (
  id text not null,
  name text not null,
  is_active boolean default true not null
);

create table if not exists public.cdqa_reviews (
  id text not null,
  code text,
  status text default 'draft'::text not null,
  project_title text,
  content_type text,
  author_id uuid,
  reviewer_id uuid,
  review_date date,
  target_date date,
  actual_date date,
  ratings jsonb default '{}'::jsonb not null,
  remarks jsonb default '{}'::jsonb not null,
  observations text,
  cd_notes text,
  finalized_at timestamp with time zone,
  acknowledged_at timestamp with time zone,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table if not exists public.checklist_templates (
  id text not null,
  title text not null,
  items jsonb default '[]'::jsonb not null,
  is_active boolean default true not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table if not exists public.deliverables (
  id text not null,
  name text not null,
  is_id boolean default false not null,
  is_cd boolean default false not null,
  is_default boolean default false not null,
  is_active boolean default true not null
);

create table if not exists public.departments (
  id text not null,
  name text not null,
  is_active boolean default true not null
);

create table if not exists public.evaluations (
  id text not null,
  code text,
  status text default 'draft'::text not null,
  batch_no text,
  training_date date,
  venue_id text,
  modality_id text,
  trainer_id uuid,
  evaluator_id uuid,
  session_id text,
  training_program text,
  overall_score numeric,
  ratings jsonb default '{}'::jsonb not null,
  remarks jsonb default '{}'::jsonb not null,
  observations text,
  trainee_response text,
  finalized_at timestamp with time zone,
  acknowledged_at timestamp with time zone,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  evaluation_mode text,
  evaluation_date date
);

create table if not exists public.facilitation_cost_rates (
  id text not null,
  profile_id uuid not null,
  monthly_cost_basis numeric not null,
  effective_from date not null,
  effective_to date,
  created_by uuid,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table if not exists public.idqa_reviews (
  id text not null,
  code text,
  status text default 'draft'::text not null,
  project_title text,
  deliv_type text,
  designer_id uuid,
  reviewer_id uuid,
  review_date date,
  target_date date,
  actual_date date,
  ratings jsonb default '{}'::jsonb not null,
  remarks jsonb default '{}'::jsonb not null,
  observations text,
  designer_notes text,
  finalized_at timestamp with time zone,
  acknowledged_at timestamp with time zone,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table if not exists public.kpi_monthly_snapshots (
  id uuid default gen_random_uuid() not null,
  month text not null,
  data jsonb not null,
  locked_at timestamp with time zone default now() not null,
  locked_by uuid,
  created_at timestamp with time zone default now() not null
);

create table if not exists public.kpi_settings (
  id text default 'default'::text not null,
  trainer_eval_target integer default 1 not null,
  id_assurance_target integer default 1 not null,
  cdqa_target integer default 3 not null,
  eligibility_cutoff_day integer default 15 not null,
  updated_at timestamp with time zone default now()
);

create table if not exists public.kpi_targets (
  id text default (gen_random_uuid())::text not null,
  role text not null,
  kpi_key text not null,
  target numeric not null,
  effective_from date not null,
  effective_to date,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  kpi_name text,
  data_source text,
  weight numeric
);

create table if not exists public.learning_programs (
  id text default (gen_random_uuid())::text not null,
  title text not null,
  category_id text,
  delivery_type text,
  version text default 'v1'::text not null,
  status text default 'active'::text not null,
  effective_from date not null,
  effective_to date,
  description text,
  contributors jsonb default '[]'::jsonb not null,
  components jsonb default '[]'::jsonb not null,
  l3_required boolean default false not null,
  l3_notes text,
  created_by uuid,
  updated_by uuid,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  agenda jsonb default '[]'::jsonb not null,
  assessments jsonb default '[]'::jsonb not null,
  code text,
  duration_hours numeric(8,2),
  evaluation_config jsonb default '{"l1": false, "l2": {"pre": false, "post": false}, "l3": {"method": "", "enabled": false, "daysAfter": null}, "l4": {"target": "", "enabled": false, "measure": "", "baseline": ""}}'::jsonb not null,
  duration_minutes integer,
  resource_url text,
  checklist_template_id text,
  program_family_id text not null,
  supersedes_program_id text,
  retirement_reason text,
  delivery_parts integer default 1 not null,
  allowed_modalities text[] default '{}'::text[] not null
);

create table if not exists public.modalities (
  id text not null,
  name text not null,
  is_active boolean default true not null
);

create table if not exists public.ph_holidays (
  id text not null,
  holiday_date date not null,
  name text not null
);

create table if not exists public.positions (
  id text not null,
  name text not null,
  is_active boolean default true not null
);

create table if not exists public.profiles (
  id uuid not null,
  email text not null,
  first_name text,
  last_name text,
  employee_id text,
  position_id text,
  supervisor_id uuid,
  hire_date date,
  dash_scope text,
  is_active boolean default true not null,
  is_admin boolean default false not null,
  is_reports_viewer boolean default false not null,
  form_trainer boolean default false not null,
  form_idqa boolean default false not null,
  form_cqa boolean default false not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  must_change_password boolean default false not null,
  workload_allocation_pct numeric default 60,
  can_view_training_costs boolean default false not null,
  can_manage_facilitation_rates boolean default false not null,
  role_effective_date date
);

create table if not exists public.program_types (
  id text not null,
  name text not null,
  is_active boolean default true not null
);

create table if not exists public.session_checklists (
  id text not null,
  session_id text not null,
  template_id text,
  template_title text,
  items jsonb default '[]'::jsonb not null,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null
);

create table if not exists public.session_participants (
  id text not null,
  session_id text not null,
  profile_id uuid,
  external_name text,
  attended boolean default false not null,
  notes text,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  attendance_status text default 'pending'::text not null,
  pre_test_score numeric,
  post_test_score numeric,
  remarks text,
  external_role text,
  external_supervisor text,
  employee_id text,
  department_id text,
  attendance_by_day jsonb default '{}'::jsonb not null,
  bond_signed boolean default false,
  proof_of_completion boolean default false,
  post_training_survey boolean default false,
  proof_of_knowledge_transfer boolean default false,
  pre_test_scores jsonb,
  post_test_scores jsonb
);

create table if not exists public.training_reports (
  id text not null,
  session_id text not null,
  status text default 'draft'::text not null,
  content jsonb default '{}'::jsonb not null,
  created_by uuid,
  submitted_at timestamp with time zone,
  approved_by uuid,
  approved_at timestamp with time zone,
  return_reason text,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  reopen_status text,
  reopen_requested_by uuid,
  reopen_requested_at timestamp with time zone,
  reopen_reason text,
  reopen_decided_by uuid,
  reopen_decided_at timestamp with time zone
);

create table if not exists public.training_sessions (
  id text not null,
  code text,
  trainer_id uuid,
  training_program text,
  batch_no text,
  training_date date,
  venue_id text,
  modality_id text,
  recording_link text,
  status text default 'scheduled'::text not null,
  num_participants integer,
  duration text,
  created_at timestamp with time zone default now() not null,
  updated_at timestamp with time zone default now() not null,
  delivery_type text,
  co_facilitator_id uuid,
  expected_participants integer,
  assessment_type text,
  passing_score integer,
  report_status text default 'not_started'::text not null,
  owner_id uuid,
  end_date date,
  description text,
  duration_hours numeric,
  category text,
  facilitator_name text,
  training_provider text,
  guest_trainer_name text,
  audience text[] default '{}'::text[] not null,
  created_by uuid,
  co_facilitator_guest_name text,
  is_mandatory boolean default false not null,
  checklist_template_id text,
  venue_other_name text,
  training_classification text,
  training_bond_months integer,
  training_bond_end_date date,
  rica_ticket text,
  ld_owner_id uuid,
  facilitation_hours_applied numeric,
  facilitator_rate_applied numeric,
  co_facilitator_rate_applied numeric,
  facilitation_cost_applied numeric,
  facilitation_cost_locked_at timestamp with time zone,
  date_mode text default 'range'::text,
  session_dates date[],
  assessment_names jsonb,
  l3_required boolean default false not null,
  l3_methods jsonb,
  l3_due_date date,
  l3_completed_at timestamp with time zone,
  l3_completed_by uuid,
  l3_rating text,
  l3_notes text,
  program_id text,
  program_link_origin text,
  program_linked_at timestamp with time zone,
  duration_basis text default 'per_day'::text not null,
  delivery_plan jsonb default '[]'::jsonb not null,
  delivery_part_dates jsonb default '[]'::jsonb not null,
  program_info_snapshot jsonb default '{}'::jsonb not null,
  evaluation_plan jsonb default '{}'::jsonb not null,
  l3_followups jsonb default '[]'::jsonb not null,
  l4_results jsonb default '[]'::jsonb not null,
  session_notes text
);

create table if not exists public.venues (
  id text not null,
  name text not null,
  is_active boolean default true not null,
  type text default 'physical'::text not null
);

create table if not exists public.workload_pct_history (
  id text not null,
  profile_id uuid not null,
  pct numeric not null,
  effective_date date not null,
  created_at timestamp with time zone default now() not null
);

create table if not exists public.workload_settings (
  id text default 'default'::text not null,
  monthly_capacity_hours numeric default 60 not null,
  light_max_pct numeric default 59 not null,
  balanced_max_pct numeric default 80 not null,
  high_max_pct numeric default 100 not null,
  updated_at timestamp with time zone default now() not null,
  standard_weekly_hours numeric default 37.5
);

create table if not exists private.training_batch_counters (
  program_family_id text not null,
  delivery_year integer not null,
  last_sequence integer default 0 not null,
  updated_at timestamp with time zone default now() not null
);

-- Constraints
alter table only public.agenda_templates add constraint agenda_templates_pkey PRIMARY KEY (id);

alter table only public.attendance_settings add constraint attendance_settings_pkey PRIMARY KEY (id);

alter table only public.audiences add constraint audiences_pkey PRIMARY KEY (id);

alter table only public.audit_log add constraint audit_log_pkey PRIMARY KEY (id);
alter table only public.audit_log add constraint audit_log_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES profiles(id);

alter table only public.categories add constraint categories_pkey PRIMARY KEY (id);

alter table only public.cdqa_reviews add constraint cdqa_reviews_pkey PRIMARY KEY (id);
alter table only public.cdqa_reviews add constraint cdqa_reviews_code_key UNIQUE (code);
alter table only public.cdqa_reviews add constraint cdqa_reviews_author_id_fkey FOREIGN KEY (author_id) REFERENCES profiles(id);
alter table only public.cdqa_reviews add constraint cdqa_reviews_content_type_fkey FOREIGN KEY (content_type) REFERENCES deliverables(id);
alter table only public.cdqa_reviews add constraint cdqa_reviews_reviewer_id_fkey FOREIGN KEY (reviewer_id) REFERENCES profiles(id);

alter table only public.checklist_templates add constraint checklist_templates_pkey PRIMARY KEY (id);

alter table only public.deliverables add constraint deliverables_pkey PRIMARY KEY (id);

alter table only public.departments add constraint departments_pkey PRIMARY KEY (id);

alter table only public.evaluations add constraint evaluations_pkey PRIMARY KEY (id);
alter table only public.evaluations add constraint evaluations_code_key UNIQUE (code);
alter table only public.evaluations add constraint evaluations_evaluator_id_fkey FOREIGN KEY (evaluator_id) REFERENCES profiles(id);
alter table only public.evaluations add constraint evaluations_modality_id_fkey FOREIGN KEY (modality_id) REFERENCES modalities(id);
alter table only public.evaluations add constraint evaluations_session_id_fkey FOREIGN KEY (session_id) REFERENCES training_sessions(id);
alter table only public.evaluations add constraint evaluations_trainer_id_fkey FOREIGN KEY (trainer_id) REFERENCES profiles(id);
alter table only public.evaluations add constraint evaluations_venue_id_fkey FOREIGN KEY (venue_id) REFERENCES venues(id);

alter table only public.facilitation_cost_rates add constraint facilitation_cost_rates_pkey PRIMARY KEY (id);
alter table only public.facilitation_cost_rates add constraint facilitation_cost_rates_created_by_fkey FOREIGN KEY (created_by) REFERENCES profiles(id);
alter table only public.facilitation_cost_rates add constraint facilitation_cost_rates_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id);

alter table only public.idqa_reviews add constraint idqa_reviews_pkey PRIMARY KEY (id);
alter table only public.idqa_reviews add constraint idqa_reviews_code_key UNIQUE (code);
alter table only public.idqa_reviews add constraint idqa_reviews_deliv_type_fkey FOREIGN KEY (deliv_type) REFERENCES deliverables(id);
alter table only public.idqa_reviews add constraint idqa_reviews_designer_id_fkey FOREIGN KEY (designer_id) REFERENCES profiles(id);
alter table only public.idqa_reviews add constraint idqa_reviews_reviewer_id_fkey FOREIGN KEY (reviewer_id) REFERENCES profiles(id);

alter table only public.kpi_monthly_snapshots add constraint kpi_monthly_snapshots_pkey PRIMARY KEY (id);
alter table only public.kpi_monthly_snapshots add constraint kpi_monthly_snapshots_month_key UNIQUE (month);
alter table only public.kpi_monthly_snapshots add constraint kpi_monthly_snapshots_locked_by_fkey FOREIGN KEY (locked_by) REFERENCES profiles(id);

alter table only public.kpi_settings add constraint kpi_settings_pkey PRIMARY KEY (id);

alter table only public.kpi_targets add constraint kpi_targets_pkey PRIMARY KEY (id);
alter table only public.kpi_targets add constraint kpi_targets_role_check CHECK ((role = ANY (ARRAY['id'::text, 'cd'::text, 'delivery'::text])));
alter table only public.kpi_targets add constraint kpi_targets_weight_chk CHECK (((weight >= (0)::numeric) AND (weight <= (100)::numeric)));
alter table only public.kpi_targets add constraint kpi_targets_window_chk CHECK (((effective_to IS NULL) OR (effective_to >= effective_from)));

alter table only public.learning_programs add constraint learning_programs_pkey PRIMARY KEY (id);
alter table only public.learning_programs add constraint learning_programs_active_core_fields CHECK (((status <> 'active'::text) OR ((NULLIF(btrim(COALESCE(category_id, ''::text)), ''::text) IS NOT NULL) AND (NULLIF(btrim(COALESCE(delivery_type, ''::text)), ''::text) IS NOT NULL))));
alter table only public.learning_programs add constraint learning_programs_agenda_valid CHECK (learning_program_agenda_valid(agenda));
alter table only public.learning_programs add constraint learning_programs_delivery_parts_range CHECK (((delivery_parts >= 1) AND (delivery_parts <= 30)));
alter table only public.learning_programs add constraint learning_programs_duration_hours_positive CHECK (((duration_hours IS NULL) OR (duration_hours > (0)::numeric)));
alter table only public.learning_programs add constraint learning_programs_duration_minutes_positive CHECK (((duration_minutes IS NULL) OR (duration_minutes > 0)));
alter table only public.learning_programs add constraint learning_programs_evaluation_config_object CHECK ((jsonb_typeof(evaluation_config) = 'object'::text));
alter table only public.learning_programs add constraint learning_programs_inactive_end_chk CHECK (((status <> 'inactive'::text) OR (effective_to IS NOT NULL)));
alter table only public.learning_programs add constraint learning_programs_l2_valid CHECK (learning_program_l2_valid(evaluation_config, assessments));
alter table only public.learning_programs add constraint learning_programs_levels_valid CHECK (learning_program_levels_valid(evaluation_config));
alter table only public.learning_programs add constraint learning_programs_resource_url_http CHECK (((resource_url IS NULL) OR (resource_url ~* '^https?://[^[:space:]]+$'::text)));
alter table only public.learning_programs add constraint learning_programs_status_check CHECK ((status = ANY (ARRAY['active'::text, 'inactive'::text, 'draft'::text])));
alter table only public.learning_programs add constraint learning_programs_successor_active_complete CHECK (((status <> 'active'::text) OR (supersedes_program_id IS NULL) OR ((category_id IS NOT NULL) AND (delivery_type IS NOT NULL) AND (jsonb_typeof(agenda) = 'array'::text) AND (jsonb_array_length(agenda) > 0))));
alter table only public.learning_programs add constraint learning_programs_title_not_blank CHECK ((NULLIF(btrim(title), ''::text) IS NOT NULL));
alter table only public.learning_programs add constraint learning_programs_window_chk CHECK (((effective_to IS NULL) OR (effective_to >= effective_from)));
alter table only public.learning_programs add constraint learning_programs_checklist_template_id_fkey FOREIGN KEY (checklist_template_id) REFERENCES checklist_templates(id) ON DELETE RESTRICT;
alter table only public.learning_programs add constraint learning_programs_supersedes_program_id_fkey FOREIGN KEY (supersedes_program_id) REFERENCES learning_programs(id) ON DELETE RESTRICT;

alter table only public.modalities add constraint modalities_pkey PRIMARY KEY (id);

alter table only public.ph_holidays add constraint ph_holidays_pkey PRIMARY KEY (id);
alter table only public.ph_holidays add constraint ph_holidays_holiday_date_key UNIQUE (holiday_date);

alter table only public.positions add constraint positions_pkey PRIMARY KEY (id);

alter table only public.profiles add constraint profiles_pkey PRIMARY KEY (id);
alter table only public.profiles add constraint profiles_email_key UNIQUE (email);
alter table only public.profiles add constraint profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
alter table only public.profiles add constraint profiles_position_id_fkey FOREIGN KEY (position_id) REFERENCES positions(id);
alter table only public.profiles add constraint profiles_supervisor_id_fkey FOREIGN KEY (supervisor_id) REFERENCES profiles(id);

alter table only public.program_types add constraint program_types_pkey PRIMARY KEY (id);

alter table only public.session_checklists add constraint session_checklists_pkey PRIMARY KEY (id);
alter table only public.session_checklists add constraint session_checklists_session_id_fkey FOREIGN KEY (session_id) REFERENCES training_sessions(id) ON DELETE CASCADE;

alter table only public.session_participants add constraint session_participants_pkey PRIMARY KEY (id);
alter table only public.session_participants add constraint session_participants_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id);
alter table only public.session_participants add constraint session_participants_session_id_fkey FOREIGN KEY (session_id) REFERENCES training_sessions(id) ON DELETE CASCADE;

alter table only public.training_reports add constraint training_reports_pkey PRIMARY KEY (id);
alter table only public.training_reports add constraint training_reports_approved_by_fkey FOREIGN KEY (approved_by) REFERENCES profiles(id);
alter table only public.training_reports add constraint training_reports_created_by_fkey FOREIGN KEY (created_by) REFERENCES profiles(id);
alter table only public.training_reports add constraint training_reports_reopen_decided_by_fkey FOREIGN KEY (reopen_decided_by) REFERENCES profiles(id);
alter table only public.training_reports add constraint training_reports_reopen_requested_by_fkey FOREIGN KEY (reopen_requested_by) REFERENCES profiles(id);
alter table only public.training_reports add constraint training_reports_session_id_fkey FOREIGN KEY (session_id) REFERENCES training_sessions(id) ON DELETE CASCADE;

alter table only public.training_sessions add constraint training_sessions_pkey PRIMARY KEY (id);
alter table only public.training_sessions add constraint training_sessions_code_key UNIQUE (code);
alter table only public.training_sessions add constraint training_sessions_delivery_type_check CHECK ((delivery_type = ANY (ARRAY['ILT'::text, 'VILT'::text, 'Self-led'::text, 'External'::text, 'Ad-hoc'::text])));
alter table only public.training_sessions add constraint training_sessions_duration_basis_check CHECK ((duration_basis = ANY (ARRAY['per_day'::text, 'total'::text])));
alter table only public.training_sessions add constraint training_sessions_program_link_consistency CHECK ((((program_id IS NULL) AND (program_link_origin IS NULL) AND (program_linked_at IS NULL)) OR ((program_id IS NOT NULL) AND (program_link_origin = ANY (ARRAY['catalog_mapping'::text, 'program_selection'::text])) AND (program_linked_at IS NOT NULL))));
alter table only public.training_sessions add constraint training_sessions_co_facilitator_id_fkey FOREIGN KEY (co_facilitator_id) REFERENCES profiles(id);
alter table only public.training_sessions add constraint training_sessions_created_by_fkey FOREIGN KEY (created_by) REFERENCES profiles(id);
alter table only public.training_sessions add constraint training_sessions_l3_completed_by_fkey FOREIGN KEY (l3_completed_by) REFERENCES profiles(id);
alter table only public.training_sessions add constraint training_sessions_ld_owner_id_fkey FOREIGN KEY (ld_owner_id) REFERENCES profiles(id);
alter table only public.training_sessions add constraint training_sessions_modality_id_fkey FOREIGN KEY (modality_id) REFERENCES modalities(id);
alter table only public.training_sessions add constraint training_sessions_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES profiles(id);
alter table only public.training_sessions add constraint training_sessions_program_id_fkey FOREIGN KEY (program_id) REFERENCES learning_programs(id) ON DELETE RESTRICT;
alter table only public.training_sessions add constraint training_sessions_trainer_id_fkey FOREIGN KEY (trainer_id) REFERENCES profiles(id);
alter table only public.training_sessions add constraint training_sessions_venue_id_fkey FOREIGN KEY (venue_id) REFERENCES venues(id);

alter table only public.venues add constraint venues_pkey PRIMARY KEY (id);
alter table only public.venues add constraint venues_type_check CHECK ((type = ANY (ARRAY['physical'::text, 'platform'::text])));

alter table only public.workload_pct_history add constraint workload_pct_history_pkey PRIMARY KEY (id);
alter table only public.workload_pct_history add constraint workload_pct_history_profile_id_fkey FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;

alter table only public.workload_settings add constraint workload_settings_pkey PRIMARY KEY (id);

alter table only private.training_batch_counters add constraint training_batch_counters_pkey PRIMARY KEY (program_family_id, delivery_year);
alter table only private.training_batch_counters add constraint training_batch_counters_delivery_year_check CHECK (((delivery_year >= 2000) AND (delivery_year <= 2100)));
alter table only private.training_batch_counters add constraint training_batch_counters_last_sequence_check CHECK ((last_sequence >= 0));

-- Indexes
CREATE INDEX idx_facilitation_cost_rates_profile ON public.facilitation_cost_rates USING btree (profile_id);
CREATE UNIQUE INDEX learning_programs_code_version_unique ON public.learning_programs USING btree (code, version) WHERE (code IS NOT NULL);
CREATE INDEX learning_programs_family_idx ON public.learning_programs USING btree (program_family_id);
CREATE UNIQUE INDEX learning_programs_root_code_unique ON public.learning_programs USING btree (code) WHERE ((supersedes_program_id IS NULL) AND (code IS NOT NULL));
CREATE UNIQUE INDEX learning_programs_supersedes_once_idx ON public.learning_programs USING btree (supersedes_program_id) WHERE (supersedes_program_id IS NOT NULL);
CREATE UNIQUE INDEX session_checklists_session_id_key ON public.session_checklists USING btree (session_id);
CREATE INDEX training_sessions_program_id_idx ON public.training_sessions USING btree (program_id) WHERE (program_id IS NOT NULL);
CREATE INDEX idx_wph_profile_date ON public.workload_pct_history USING btree (profile_id, effective_date);

-- Functions
CREATE OR REPLACE FUNCTION private.enforce_program_selected_batch()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_family text;
  v_year integer;
  v_count integer := 0;
  v_max_seq integer := 0;
  v_last integer := 0;
  v_next integer;
begin
  if new.program_id is null or new.program_link_origin <> 'program_selection' then
    return new;
  end if;

  -- Unrelated edits to an already-assigned session must never renumber it.
  if tg_op='UPDATE' and old.batch_no is not distinct from new.batch_no then
    return new;
  end if;

  v_year := extract(year from coalesce(
    new.training_date,
    new.session_dates[1],
    (
      select min((j.value->>'date')::date)
      from jsonb_array_elements(coalesce(new.delivery_part_dates,'[]'::jsonb)) j(value)
      where (j.value->>'date') ~ '^\d{4}-\d{2}-\d{2}$'
    )
  ))::integer;

  if v_year is null then
    return new;
  end if;

  select lp.program_family_id into v_family
  from public.learning_programs lp
  where lp.id = new.program_id;

  if v_family is null then
    return new;
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_family || ':' || v_year::text, 0)
  );

  select count(*)::integer,
         coalesce(max(
           case
             when ts.batch_no ~ ('^' || v_year::text || '-[0-9]+$')
             then split_part(ts.batch_no,'-',2)::integer
             else null
           end
         ),0)::integer
    into v_count, v_max_seq
  from public.training_sessions ts
  join public.learning_programs lp on lp.id = ts.program_id
  where lp.program_family_id = v_family
    and ts.id is distinct from new.id
    and extract(year from coalesce(
      ts.training_date,
      ts.session_dates[1],
      (
        select min((j.value->>'date')::date)
        from jsonb_array_elements(coalesce(ts.delivery_part_dates,'[]'::jsonb)) j(value)
        where (j.value->>'date') ~ '^\d{4}-\d{2}-\d{2}$'
      )
    ))::integer = v_year;

  insert into private.training_batch_counters(program_family_id,delivery_year,last_sequence,updated_at)
  values (v_family,v_year,greatest(v_count,v_max_seq),now())
  on conflict (program_family_id,delivery_year)
  do update set
    last_sequence = greatest(private.training_batch_counters.last_sequence, excluded.last_sequence),
    updated_at = now()
  returning last_sequence into v_last;

  v_next := greatest(v_last,v_count,v_max_seq) + 1;
  new.batch_no := v_year::text || '-' || lpad(v_next::text,3,'0');

  update private.training_batch_counters
  set last_sequence=v_next, updated_at=now()
  where program_family_id=v_family and delivery_year=v_year;

  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION private.sync_training_batch_counter_from_session()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_family text;
  v_year integer;
  v_seq integer;
begin
  if new.program_id is null or new.program_link_origin <> 'catalog_mapping' then
    return new;
  end if;

  select lp.program_family_id into v_family
  from public.learning_programs lp
  where lp.id = new.program_id;

  v_year := extract(year from coalesce(
    new.training_date,
    new.session_dates[1],
    (
      select min((j.value->>'date')::date)
      from jsonb_array_elements(coalesce(new.delivery_part_dates,'[]'::jsonb)) j(value)
      where (j.value->>'date') ~ '^\d{4}-\d{2}-\d{2}$'
    )
  ))::integer;

  if v_family is null or v_year is null then
    return new;
  end if;

  if coalesce(new.batch_no,'') ~ ('^' || v_year::text || '-[0-9]+$') then
    v_seq := split_part(new.batch_no,'-',2)::integer;
  else
    return new;
  end if;

  insert into private.training_batch_counters(program_family_id,delivery_year,last_sequence,updated_at)
  values (v_family,v_year,v_seq,now())
  on conflict (program_family_id,delivery_year)
  do update set
    last_sequence = greatest(private.training_batch_counters.last_sequence, excluded.last_sequence),
    updated_at = now();

  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.apply_learning_program_session_snapshot()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare
  program_row public.learning_programs%rowtype;
begin
  if tg_op = 'INSERT' and new.program_link_origin = 'program_selection' then
    select * into program_row
    from public.learning_programs
    where id = new.program_id;

    if not found or program_row.status <> 'active' then
      raise exception 'Select an active Learning Program.' using errcode = '23514';
    end if;

    if program_row.duration_minutes is null or program_row.duration_minutes <= 0 then
      raise exception 'The Learning Program needs a valid agenda duration before a session can be created.'
        using errcode = '23514';
    end if;

    -- Batch numbering is intentionally NOT handled here.
    -- private.enforce_program_selected_batch is the single authoritative allocator and uses
    -- program family + delivery year + mapped historical baseline.

    new.training_program := program_row.title;
    new.duration_hours := program_row.duration_minutes::numeric/60;
    new.duration_basis := 'total';
    select c.name into new.category
    from public.categories c
    where c.id = program_row.category_id;

    new.assessment_names :=
      case
        when coalesce((program_row.evaluation_config->'l2'->>'enabled')::boolean,false)
          then program_row.assessments
        else '[]'::jsonb
      end;

  elsif tg_op = 'UPDATE'
    and old.program_link_origin = 'program_selection'
    and new.program_id is not distinct from old.program_id then

    new.training_program := old.training_program;
    new.duration_hours := old.duration_hours;
    new.duration_basis := old.duration_basis;
    new.category := old.category;
    new.delivery_type := old.delivery_type;

    -- Do not overwrite batch_no here. The dedicated batch allocator owns it.
  end if;

  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.assign_training_session_batch(p_session_id text, p_program_id text, p_delivery_year integer)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_family text;
  v_existing text;
  v_created_by uuid;
  v_is_admin boolean := false;
  v_count integer := 0;
  v_max_seq integer := 0;
  v_last integer := 0;
  v_next integer;
  v_batch text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  select coalesce(p.is_admin,false)
    into v_is_admin
  from public.profiles p
  where p.id = auth.uid();

  if p_delivery_year < 2000 or p_delivery_year > 2100 then
    raise exception 'Invalid delivery year.';
  end if;

  select lp.program_family_id
    into v_family
  from public.learning_programs lp
  where lp.id = p_program_id;

  if v_family is null then
    raise exception 'Learning Program not found or missing program family.';
  end if;

  select ts.batch_no, ts.created_by
    into v_existing, v_created_by
  from public.training_sessions ts
  where ts.id = p_session_id
    and ts.program_id = p_program_id
  for update;

  if not found then
    raise exception 'Training session not found or is not linked to the selected Learning Program.';
  end if;

  if v_created_by is distinct from auth.uid() and not v_is_admin then
    raise exception 'Only the session creator or an administrator can assign its initial batch code.';
  end if;

  if coalesce(trim(v_existing),'') <> '' then
    return v_existing;
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_family || ':' || p_delivery_year::text, 0)
  );

  select count(*)::integer,
         coalesce(max(
           case
             when ts.batch_no ~ ('^' || p_delivery_year::text || '-[0-9]+$')
             then split_part(ts.batch_no,'-',2)::integer
             else null
           end
         ),0)::integer
    into v_count, v_max_seq
  from public.training_sessions ts
  join public.learning_programs lp on lp.id = ts.program_id
  where lp.program_family_id = v_family
    and ts.id <> p_session_id
    and extract(year from coalesce(
      ts.training_date,
      ts.session_dates[1],
      (
        select min((j.value->>'date')::date)
        from jsonb_array_elements(coalesce(ts.delivery_part_dates,'[]'::jsonb)) j(value)
        where (j.value->>'date') ~ '^\d{4}-\d{2}-\d{2}$'
      )
    ))::integer = p_delivery_year;

  insert into private.training_batch_counters(program_family_id,delivery_year,last_sequence,updated_at)
  values (v_family,p_delivery_year,greatest(v_count,v_max_seq),now())
  on conflict (program_family_id,delivery_year)
  do update set
    last_sequence = greatest(private.training_batch_counters.last_sequence, excluded.last_sequence),
    updated_at = now()
  returning last_sequence into v_last;

  v_next := greatest(v_last,v_count,v_max_seq) + 1;
  v_batch := p_delivery_year::text || '-' || lpad(v_next::text,3,'0');

  update private.training_batch_counters
  set last_sequence=v_next, updated_at=now()
  where program_family_id=v_family and delivery_year=p_delivery_year;

  update public.training_sessions
  set batch_no=v_batch, updated_at=now()
  where id=p_session_id;

  return v_batch;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.global_search(p_query text, p_scope text DEFAULT 'all'::text, p_field text DEFAULT 'any'::text, p_status text DEFAULT NULL::text, p_year integer DEFAULT NULL::integer, p_limit integer DEFAULT 60)
 RETURNS TABLE(result_type text, record_id text, extra_id text, code text, title text, subtitle text, status text, result_date date, rank_score numeric)
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog', 'public', 'extensions'
AS $function$
with params as (
  select
    lower(trim(coalesce(p_query,''))) as q,
    greatest(1,least(coalesce(p_limit,60),100)) as lim
),
raw as (
  /* Training Sessions */
  select
    'sessions'::text result_type,
    ts.id::text record_id,
    null::text extra_id,
    coalesce(ts.code,ts.id)::text code,
    coalesce(ts.training_program,'Untitled Training')::text title,
    concat_ws(' · ',
      ts.batch_no,
      ts.delivery_type,
      coalesce(nullif(trim(concat_ws(' ',trainer.first_name,trainer.last_name)),''),ts.guest_trainer_name,ts.facilitator_name),
      ts.training_date::text
    )::text subtitle,
    ts.status::text status,
    ts.training_date::date result_date,
    concat_ws(' ',
      ts.id,ts.code,ts.batch_no,ts.training_program,ts.category,ts.delivery_type,
      ts.description,ts.session_notes,ts.recording_link,ts.venue_other_name,
      array_to_string(ts.audience,' '),
      coalesce(nullif(trim(concat_ws(' ',trainer.first_name,trainer.last_name)),''),''),
      coalesce(nullif(trim(concat_ws(' ',cofac.first_name,cofac.last_name)),''),''),
      lp.code,lp.title,lp.version
    ) search_any,
    concat_ws(' ',ts.id,ts.code,ts.batch_no,lp.code,lp.version) search_id,
    concat_ws(' ',ts.training_program,lp.title,
      coalesce(nullif(trim(concat_ws(' ',trainer.first_name,trainer.last_name)),''),''),
      coalesce(nullif(trim(concat_ws(' ',cofac.first_name,cofac.last_name)),''),'')
    ) search_name
  from public.training_sessions ts
  left join public.learning_programs lp on lp.id=ts.program_id
  left join public.profiles trainer on trainer.id=ts.trainer_id
  left join public.profiles cofac on cofac.id=ts.co_facilitator_id
  where p_scope in ('all','sessions')
    and (p_status is null or p_status='' or ts.status=p_status)
    and (p_year is null or extract(year from coalesce(ts.training_date,ts.end_date))::integer=p_year)

  union all

  /* Learning Programs */
  select
    'programs', lp.id, null, coalesce(lp.code,lp.id), coalesce(lp.title,'Untitled Program'),
    concat_ws(' · ',lp.version,lp.delivery_type,lp.status),
    lp.status, lp.effective_from,
    concat_ws(' ',lp.id,lp.code,lp.version,lp.title,lp.description,lp.delivery_type,lp.status,lp.resource_url,lp.contributors::text),
    concat_ws(' ',lp.id,lp.code,lp.version,lp.program_family_id),
    concat_ws(' ',lp.title)
  from public.learning_programs lp
  where p_scope in ('all','programs')
    and (p_status is null or p_status='' or lp.status=p_status)
    and (p_year is null or extract(year from lp.effective_from)::integer=p_year)

  union all

  /* Trainer Evaluations */
  select
    'evaluations', e.id, e.session_id, coalesce(e.code,e.id),
    coalesce(e.training_program,ts.training_program,'Trainer Evaluation'),
    concat_ws(' · ',ts.code,e.evaluation_mode,e.status,
      nullif(trim(concat_ws(' ',ev.first_name,ev.last_name)),'')
    ),
    e.status, coalesce(e.evaluation_date,e.training_date),
    concat_ws(' ',e.id,e.code,e.session_id,ts.code,e.batch_no,e.training_program,ts.training_program,
      e.status,e.evaluation_mode,e.observations,
      nullif(trim(concat_ws(' ',tr.first_name,tr.last_name)),''),
      nullif(trim(concat_ws(' ',ev.first_name,ev.last_name)),'')
    ),
    concat_ws(' ',e.id,e.code,e.session_id,ts.code,e.batch_no),
    concat_ws(' ',e.training_program,ts.training_program,
      nullif(trim(concat_ws(' ',tr.first_name,tr.last_name)),''),
      nullif(trim(concat_ws(' ',ev.first_name,ev.last_name)),'')
    )
  from public.evaluations e
  left join public.training_sessions ts on ts.id=e.session_id
  left join public.profiles tr on tr.id=e.trainer_id
  left join public.profiles ev on ev.id=e.evaluator_id
  where p_scope in ('all','evaluations')
    and (p_status is null or p_status='' or e.status=p_status)
    and (p_year is null or extract(year from coalesce(e.evaluation_date,e.training_date))::integer=p_year)

  union all

  /* ID QA */
  select
    'idqa', r.id, null, coalesce(r.code,r.id), coalesce(r.project_title,'ID QA Review'),
    concat_ws(' · ',r.deliv_type,r.status,nullif(trim(concat_ws(' ',d.first_name,d.last_name)),'')),
    r.status, coalesce(r.actual_date,r.review_date,r.target_date),
    concat_ws(' ',r.id,r.code,r.project_title,r.deliv_type,r.status,r.observations,r.designer_notes,
      nullif(trim(concat_ws(' ',d.first_name,d.last_name)),''),
      nullif(trim(concat_ws(' ',rv.first_name,rv.last_name)),'')
    ),
    concat_ws(' ',r.id,r.code),
    concat_ws(' ',r.project_title,
      nullif(trim(concat_ws(' ',d.first_name,d.last_name)),''),
      nullif(trim(concat_ws(' ',rv.first_name,rv.last_name)),'')
    )
  from public.idqa_reviews r
  left join public.profiles d on d.id=r.designer_id
  left join public.profiles rv on rv.id=r.reviewer_id
  where p_scope in ('all','idqa')
    and (p_status is null or p_status='' or r.status=p_status)
    and (p_year is null or extract(year from coalesce(r.actual_date,r.review_date,r.target_date))::integer=p_year)

  union all

  /* Content QA */
  select
    'cqa', r.id, null, coalesce(r.code,r.id), coalesce(r.project_title,'Content QA Review'),
    concat_ws(' · ',r.content_type,r.status,nullif(trim(concat_ws(' ',a.first_name,a.last_name)),'')),
    r.status, coalesce(r.actual_date,r.review_date,r.target_date),
    concat_ws(' ',r.id,r.code,r.project_title,r.content_type,r.status,r.observations,r.cd_notes,
      nullif(trim(concat_ws(' ',a.first_name,a.last_name)),''),
      nullif(trim(concat_ws(' ',rv.first_name,rv.last_name)),'')
    ),
    concat_ws(' ',r.id,r.code),
    concat_ws(' ',r.project_title,
      nullif(trim(concat_ws(' ',a.first_name,a.last_name)),''),
      nullif(trim(concat_ws(' ',rv.first_name,rv.last_name)),'')
    )
  from public.cdqa_reviews r
  left join public.profiles a on a.id=r.author_id
  left join public.profiles rv on rv.id=r.reviewer_id
  where p_scope in ('all','cqa')
    and (p_status is null or p_status='' or r.status=p_status)
    and (p_year is null or extract(year from coalesce(r.actual_date,r.review_date,r.target_date))::integer=p_year)

  union all

  /* Training Reports */
  select
    'reports', tr.id, tr.session_id, coalesce(ts.code,tr.id), coalesce(ts.training_program,'Training Report'),
    concat_ws(' · ',tr.status,tr.submitted_at::date::text,nullif(trim(concat_ws(' ',p.first_name,p.last_name)),'')),
    tr.status, coalesce(tr.submitted_at::date,tr.created_at::date),
    concat_ws(' ',tr.id,tr.session_id,ts.code,ts.training_program,tr.status,tr.return_reason,tr.reopen_reason,tr.content::text,
      nullif(trim(concat_ws(' ',p.first_name,p.last_name)),'')
    ),
    concat_ws(' ',tr.id,tr.session_id,ts.code),
    concat_ws(' ',ts.training_program,nullif(trim(concat_ws(' ',p.first_name,p.last_name)),''))
  from public.training_reports tr
  left join public.training_sessions ts on ts.id=tr.session_id
  left join public.profiles p on p.id=tr.created_by
  where p_scope in ('all','reports')
    and (p_status is null or p_status='' or tr.status=p_status)
    and (p_year is null or extract(year from coalesce(tr.submitted_at,tr.created_at))::integer=p_year)

  union all

  /* Users */
  select
    'users', p.id::text, null, coalesce(p.employee_id,p.id::text),
    coalesce(nullif(trim(concat_ws(' ',p.first_name,p.last_name)),''),p.email,p.id::text),
    concat_ws(' · ',p.employee_id,p.email,pos.name,case when p.is_active then 'Active' else 'Inactive' end),
    case when p.is_active then 'active' else 'inactive' end,
    p.hire_date,
    concat_ws(' ',p.id::text,p.employee_id,p.email,p.first_name,p.last_name,pos.name),
    concat_ws(' ',p.id::text,p.employee_id,p.email),
    concat_ws(' ',p.first_name,p.last_name,pos.name)
  from public.profiles p
  left join public.positions pos on pos.id=p.position_id
  where p_scope in ('all','users')
    and (p_status is null or p_status='' or (case when p.is_active then 'active' else 'inactive' end)=p_status)
    and (p_year is null or extract(year from p.hire_date)::integer=p_year)
),
scored as (
  select r.*,
    lower(case p_field when 'id' then r.search_id when 'name' then r.search_name else r.search_any end) haystack,
    lower(coalesce(r.code,'')) lc_code,
    p.q,
    case
      when p.q='' then 1.0
      when lower(coalesce(r.code,''))=p.q then 1000.0
      when lower(r.record_id)=p.q then 950.0
      when lower(coalesce(r.code,'')) like p.q||'%' then 800.0
      when lower(coalesce(r.title,''))=p.q then 760.0
      when lower(coalesce(r.title,'')) like p.q||'%' then 700.0
      when lower(case p_field when 'id' then r.search_id when 'name' then r.search_name else r.search_any end) like '%'||p.q||'%' then 500.0
      else 100.0 * greatest(
        extensions.similarity(lower(case p_field when 'id' then r.search_id when 'name' then r.search_name else r.search_any end), p.q),
        extensions.word_similarity(p.q, lower(case p_field when 'id' then r.search_id when 'name' then r.search_name else r.search_any end))
      )
    end::numeric rank_score
  from raw r cross join params p
),
filtered as (
  select *
  from scored
  where q=''
     or haystack like '%'||q||'%'
     or extensions.similarity(haystack,q)>=0.18
     or (length(q)>=4 and q !~ '[0-9]' and extensions.word_similarity(q,haystack)>=0.5)
)
select result_type,record_id,extra_id,code,title,subtitle,status,result_date,rank_score
from filtered
order by rank_score desc, result_date desc nulls last, title
limit (select lim from params);
$function$
;

CREATE OR REPLACE FUNCTION public.guard_profile_privileged_columns()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if auth.uid() is null or public.is_admin() then
    return new;
  end if;
  if new.is_admin is distinct from old.is_admin
     or new.is_reports_viewer is distinct from old.is_reports_viewer
     or new.can_manage_facilitation_rates is distinct from old.can_manage_facilitation_rates
     or new.can_view_training_costs is distinct from old.can_view_training_costs
     or new.dash_scope is distinct from old.dash_scope
     or new.form_trainer is distinct from old.form_trainer
     or new.form_idqa is distinct from old.form_idqa
     or new.form_cqa is distinct from old.form_cqa
     or new.position_id is distinct from old.position_id
     or new.supervisor_id is distinct from old.supervisor_id
     or new.is_active is distinct from old.is_active
     or new.email is distinct from old.email
     or new.employee_id is distinct from old.employee_id
     or new.workload_allocation_pct is distinct from old.workload_allocation_pct
     or new.role_effective_date is distinct from old.role_effective_date
     or new.id is distinct from old.id
  then
    raise exception 'Only an administrator can change access, role, or reporting-line fields on a profile.'
      using errcode = '42501';
  end if;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.guard_training_report_submission()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_status text;
  v_delivery_type text;
begin
  if new.status in ('submitted','approved') then
    select ts.status, ts.delivery_type
      into v_status, v_delivery_type
    from public.training_sessions ts
    where ts.id = new.session_id;

    if not found then
      raise exception 'Training session not found.';
    end if;

    if coalesce(v_delivery_type,'') <> 'Self-led'
       and v_status <> 'completed' then
      raise exception 'Training Report cannot be submitted before Delivery Complete.';
    end if;
  end if;

  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.guard_training_session_program_link()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'public'
AS $function$
begin
  if tg_op = 'INSERT' and new.program_id is not null then
    if new.program_link_origin = 'program_selection'
       and exists (
         select 1 from public.learning_programs p
         where p.id = new.program_id and p.status = 'active'
           and (
             (new.delivery_type = 'ILT' and p.delivery_type in ('ILT','ILT/VILT','Blended'))
             or (new.delivery_type = 'VILT' and p.delivery_type = 'VILT')
             or (new.delivery_type = 'Self-led' and p.delivery_type in ('SLT','Self-led'))
           )
       ) then return new; end if;
    if not public.is_admin() then
      raise exception 'Only an administrator may add a catalogue mapping' using errcode = '42501';
    end if;
  elsif tg_op = 'UPDATE' and (
      old.program_id is distinct from new.program_id
      or old.program_link_origin is distinct from new.program_link_origin
      or old.program_linked_at is distinct from new.program_linked_at
    ) then
    if not public.is_admin() then
      raise exception 'Only an administrator may change an existing session program link' using errcode = '42501';
    end if;
  end if;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.guard_training_session_protected_changes()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_end date;
begin
  if auth.uid() is null or public.is_admin() then
    return coalesce(new, old);
  end if;

  if tg_op = 'DELETE' then
    if old.status = 'completed' then
      raise exception 'Delivery Complete sessions can only be deleted by an administrator.'
        using errcode = '42501';
    end if;
    return old;
  end if;

  -- UPDATE
  if old.program_id is null
     or old.program_link_origin not in ('program_selection','catalog_mapping')
     or old.status is distinct from 'completed' then
    return new;
  end if;

  if old.date_mode = 'specific' and old.session_dates is not null and cardinality(old.session_dates) > 0 then
    select max(d) into v_end from unnest(old.session_dates) as d;
  end if;
  v_end := coalesce(v_end, old.end_date, old.training_date);
  if v_end is null or v_end >= date '2026-10-01' then
    return new;
  end if;

  if new.training_program is distinct from old.training_program
     or new.delivery_type is distinct from old.delivery_type
     or new.status is distinct from old.status
     or new.training_date is distinct from old.training_date
     or new.end_date is distinct from old.end_date
     or new.date_mode is distinct from old.date_mode
     or new.session_dates is distinct from old.session_dates
     or new.delivery_part_dates is distinct from old.delivery_part_dates
     or new.trainer_id is distinct from old.trainer_id
     or new.co_facilitator_id is distinct from old.co_facilitator_id
     or new.guest_trainer_name is distinct from old.guest_trainer_name
     or new.co_facilitator_guest_name is distinct from old.co_facilitator_guest_name
     or new.facilitator_name is distinct from old.facilitator_name
     or new.venue_id is distinct from old.venue_id
     or new.venue_other_name is distinct from old.venue_other_name
     or new.modality_id is distinct from old.modality_id
     or new.audience is distinct from old.audience
     or new.batch_no is distinct from old.batch_no
     or new.code is distinct from old.code
     or new.duration is distinct from old.duration
     or new.duration_hours is distinct from old.duration_hours
     or new.num_participants is distinct from old.num_participants
     or new.expected_participants is distinct from old.expected_participants
     or new.program_id is distinct from old.program_id
     or new.program_link_origin is distinct from old.program_link_origin
     or new.program_linked_at is distinct from old.program_linked_at
  then
    raise exception 'Historical mapped sessions are read-only for core delivery facts. Only Session Notes can be updated.'
      using errcode = '42501';
  end if;
  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.is_admin()
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
  select coalesce((select p.is_admin from public.profiles p where p.id = auth.uid()), false);
$function$
;

CREATE OR REPLACE FUNCTION public.is_reports_viewer()
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO ''
AS $function$
  select coalesce((select p.is_reports_viewer from public.profiles p where p.id = auth.uid()), false);
$function$
;

CREATE OR REPLACE FUNCTION public.learning_program_agenda_valid(items jsonb)
 RETURNS boolean
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
declare item jsonb; duration_text text;
begin
  if jsonb_typeof(items)<>'array' then return false; end if;
  for item in select value from jsonb_array_elements(items) loop
    duration_text:=item->>'duration';
    if nullif(btrim(item->>'topic'),'') is null or duration_text is null or duration_text !~ '^[0-9]+$' or length(duration_text)>8 or duration_text::integer<1 then return false; end if;
  end loop;
  return true;
end $function$
;

CREATE OR REPLACE FUNCTION public.learning_program_l2_valid(config jsonb, items jsonb)
 RETURNS boolean
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
declare item jsonb; score text;
begin
  if coalesce(config #>> '{l2,enabled}','false') <> 'true' then return true; end if;
  if jsonb_typeof(items) <> 'array' or jsonb_array_length(items)=0 then return false; end if;
  for item in select value from jsonb_array_elements(items) loop
    if nullif(btrim(item->>'name'),'') is null then return false; end if;
    if item->'pre' is distinct from 'true'::jsonb and item->'post' is distinct from 'true'::jsonb then return false; end if;
    if item->'post' = 'true'::jsonb then
      score := item->>'passingScore';
      if score is null or score !~ '^[0-9]+(\.[0-9]+)?$' then return false; end if;
      if score::numeric < 0 or score::numeric > 100 then return false; end if;
    end if;
  end loop;
  return true;
end $function$
;

CREATE OR REPLACE FUNCTION public.learning_program_levels_valid(config jsonb)
 RETURNS boolean
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
declare item jsonb; days text; items jsonb;
begin
  if config #>> '{l3,enabled}'='true' then
    items:=config #> '{l3,items}';
    if jsonb_typeof(items)<>'array' or jsonb_array_length(items)=0 then return false; end if;
    for item in select value from jsonb_array_elements(items) loop
      days:=item->>'daysAfter';
      if nullif(btrim(item->>'method'),'') is null or days is null or days !~ '^[0-9]+$' or length(days)>4 or days::integer<1 or days::integer>3650 then return false; end if;
    end loop;
  end if;
  if config #>> '{l4,enabled}'='true' then
    items:=config #> '{l4,items}';
    if jsonb_typeof(items)<>'array' or jsonb_array_length(items)=0 then return false; end if;
    for item in select value from jsonb_array_elements(items) loop
      if nullif(btrim(item->>'measure'),'') is null then return false; end if;
    end loop;
  end if;
  return true;
end $function$
;

CREATE OR REPLACE FUNCTION public.learning_program_version_identity()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare parent_record public.learning_programs%rowtype;
begin
  if new.supersedes_program_id is not null then
    select * into parent_record from public.learning_programs where id=new.supersedes_program_id;
    if not found or new.code is distinct from parent_record.code or new.program_family_id is distinct from parent_record.program_family_id then
      raise exception 'Version must retain its parent program code and family';
    end if;
  elsif tg_op='UPDATE' and new.code is distinct from old.code and exists(select 1 from public.learning_programs where supersedes_program_id=old.id) then
    raise exception 'Cannot change a program code after a new version exists';
  end if;
  return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.lock_used_learning_program_content()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'public'
AS $function$
begin
 if old.status='active' and exists(select 1 from public.training_sessions s where s.program_id=old.id and s.status in ('scheduled','completed') and s.program_link_origin in ('program_selection','catalog_mapping')) then
   if row(new.title,new.category_id,new.delivery_type,new.description,new.resource_url,new.checklist_template_id,new.agenda,new.delivery_parts,new.assessments,new.evaluation_config,new.contributors,new.allowed_modalities) is distinct from row(old.title,old.category_id,old.delivery_type,old.description,old.resource_url,old.checklist_template_id,old.agenda,old.delivery_parts,old.assessments,old.evaluation_config,old.contributors,old.allowed_modalities) then
     raise exception 'This program version has scheduled or completed implementations. Create a new version for content changes.' using errcode='23514';
   end if;
 end if;
 return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.reject_archived_learning_program_changes()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
begin
  if old.status = 'inactive' then
    raise exception 'Archived learning program versions are read only.' using errcode = '23514';
  end if;
  if tg_op = 'UPDATE' then
    return new;
  end if;
  return old;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.replace_learning_program(p_old_id text, p_end_date date, p_new_start date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare old_record public.learning_programs%rowtype; new_record public.learning_programs%rowtype; next_version text;
begin
  perform pg_advisory_xact_lock(hashtext('learning_program_version_'||p_old_id));
  select * into old_record from public.learning_programs where id=p_old_id for update;
  if not found then raise exception 'Program not found'; end if;
  if old_record.status <> 'active' then raise exception 'Only active programs can be replaced'; end if;
  if p_end_date is null or p_end_date < old_record.effective_from then raise exception 'Enter a valid end date'; end if;
  if p_new_start is null or p_new_start <= p_end_date then raise exception 'New version must start after the old version ends'; end if;
  if exists(select 1 from public.learning_programs where supersedes_program_id=p_old_id) then raise exception 'A replacement version already exists'; end if;
  next_version := case when old_record.version ~* '^v[0-9]+$' then 'v'||((substring(old_record.version from 2)::integer)+1)::text else old_record.version||'.1' end;
  update public.learning_programs set status='inactive',effective_to=p_end_date,retirement_reason='replaced',updated_at=now(),updated_by=auth.uid() where id=p_old_id;
  insert into public.learning_programs (code,title,category_id,delivery_type,version,status,effective_from,effective_to,description,contributors,components,l3_required,l3_notes,agenda,assessments,duration_hours,duration_minutes,evaluation_config,resource_url,checklist_template_id,created_by,updated_by,program_family_id,supersedes_program_id)
  values (old_record.code,old_record.title,null,null,next_version,'draft',p_new_start,null,null,'[]'::jsonb,'[]'::jsonb,false,null,'[]'::jsonb,'[]'::jsonb,null,null,'{"l1":false,"l2":{"enabled":false},"l3":{"enabled":false,"items":[]},"l4":{"enabled":false,"items":[]}}'::jsonb,null,null,auth.uid(),auth.uid(),coalesce(old_record.program_family_id,old_record.id),old_record.id) returning * into new_record;
  return jsonb_build_object('old',to_jsonb((select x from public.learning_programs x where x.id=p_old_id)),'new',to_jsonb(new_record));
end $function$
;

CREATE OR REPLACE FUNCTION public.rls_auto_enable()
 RETURNS event_trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog'
AS $function$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$function$
;

CREATE OR REPLACE FUNCTION public.set_learning_program_family()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$ begin if new.program_family_id is null then new.program_family_id:=new.id; end if; return new; end $function$
;

CREATE OR REPLACE FUNCTION public.snapshot_learning_program_delivery_plan()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare p public.learning_programs%rowtype;
declare plan jsonb;
begin
 if tg_op='INSERT' and new.program_link_origin='program_selection' then
   select * into p from public.learning_programs where id=new.program_id;
   if not found or p.status<>'active' then raise exception 'Select an active Learning Program.' using errcode='23514'; end if;
   if p.delivery_parts>1 then
     if jsonb_typeof(p.agenda)<>'array' or jsonb_array_length(p.agenda)=0 or exists(select 1 from jsonb_array_elements(p.agenda) a where coalesce(a->>'part','') !~ '^[1-9][0-9]*$' or (a->>'part')::int>p.delivery_parts or coalesce(a->>'duration','') !~ '^[1-9][0-9]*$') then
       raise exception 'The program agenda needs a valid part and duration for every topic.' using errcode='23514';
     end if;
     select jsonb_agg(jsonb_build_object('part',n,'minutes',coalesce((select sum((a->>'duration')::integer) from jsonb_array_elements(p.agenda) a where (a->>'part')::integer=n),0)) order by n) into plan from generate_series(1,p.delivery_parts) n;
     if exists(select 1 from jsonb_array_elements(plan) x where (x->>'minutes')::int<=0) then raise exception 'Each delivery part needs at least one agenda item.' using errcode='23514'; end if;
   else
     plan:=jsonb_build_array(jsonb_build_object('part',1,'minutes',p.duration_minutes));
   end if;
   new.delivery_plan:=plan;
   new.delivery_part_dates:='[]'::jsonb;
 elsif tg_op='UPDATE' and old.program_link_origin='program_selection' and new.program_id is not distinct from old.program_id then
   new.delivery_plan:=old.delivery_plan;
 end if;
 return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.snapshot_selected_program_information()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare p public.learning_programs%rowtype;
begin
 if tg_op='INSERT' and new.program_link_origin='program_selection' then
   select * into p from public.learning_programs where id=new.program_id;
   if not found then raise exception 'Learning Program not found.' using errcode='23514'; end if;
   new.program_info_snapshot:=jsonb_build_object('code',p.code,'title',p.title,'version',p.version,'description',p.description,'agenda',p.agenda,'deliveryType',p.delivery_type,'resourceUrl',p.resource_url,'allowedModalities',p.allowed_modalities,'effectiveFrom',p.effective_from,'effectiveTo',p.effective_to);
   new.evaluation_plan:=coalesce(p.evaluation_config,'{}'::jsonb);
   new.l3_required:=coalesce((p.evaluation_config->'l3'->>'enabled')::boolean,false);
   new.l3_methods:=coalesce((select jsonb_agg(x->>'method') from jsonb_array_elements(coalesce(p.evaluation_config->'l3'->'items','[]'::jsonb)) x),'[]'::jsonb);
   new.l3_followups:=coalesce((select jsonb_agg(jsonb_build_object('method',x->>'method','daysAfter',(x->>'daysAfter')::integer,'notes',coalesce(x->>'notes',''),'dueDate',null,'rating',null,'evidence','','completedAt',null)) from jsonb_array_elements(coalesce(p.evaluation_config->'l3'->'items','[]'::jsonb)) x),'[]'::jsonb);
   new.l4_results:=coalesce((select jsonb_agg(jsonb_build_object('measure',x->>'measure','baseline',coalesce(x->>'baseline',''),'target',coalesce(x->>'target',''),'actual','','notes','')) from jsonb_array_elements(coalesce(p.evaluation_config->'l4'->'items','[]'::jsonb)) x),'[]'::jsonb);
 elsif tg_op='UPDATE' and old.program_link_origin='program_selection' and new.program_id is not distinct from old.program_id then
   new.program_info_snapshot:=old.program_info_snapshot;
   new.evaluation_plan:=old.evaluation_plan;
   new.l3_required:=old.l3_required;
 end if;
 return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.validate_historical_program_mapping()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  last_day date;
begin
  if new.program_link_origin <> 'catalog_mapping' or new.program_id is null then
    return new;
  end if;

  if tg_op = 'UPDATE'
     and new.program_id is not distinct from old.program_id
     and new.program_link_origin is not distinct from old.program_link_origin then
    return new;
  end if;

  -- training_sessions.session_dates is a native date[] column, not jsonb.
  if new.date_mode = 'specific'
     and new.session_dates is not null
     and cardinality(new.session_dates) > 0 then
    select max(d) into last_day
    from unnest(new.session_dates) as d;
  end if;

  last_day := coalesce(last_day, new.end_date, new.training_date);

  if new.status in ('cancelled','tentative')
     or (
       new.status is distinct from 'completed'
       and (
         last_day is null
         or last_day >= (now() at time zone 'Asia/Manila')::date
       )
     ) then
    raise exception
      'Only Completed sessions or sessions whose last training date has passed can be mapped to a Learning Program.'
      using errcode = '23514';
  end if;

  return new;
end;
$function$
;

CREATE OR REPLACE FUNCTION public.validate_learning_program_delivery_dates()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare date_count integer;
begin
 if new.program_link_origin='program_selection' and jsonb_array_length(new.delivery_plan)>0 then
   if tg_op='UPDATE' and old.program_link_origin='program_selection' and new.program_id is not distinct from old.program_id then
     new.checklist_template_id:=old.checklist_template_id;
     new.assessment_names:=old.assessment_names;
   end if;
   if (select sum((x->>'minutes')::numeric) from jsonb_array_elements(new.delivery_plan) x)<>round(new.duration_hours*60) then raise exception 'Delivery parts must equal the agenda total.' using errcode='23514'; end if;
   if jsonb_typeof(new.delivery_part_dates)<>'array' then raise exception 'Delivery part dates must be an array.' using errcode='23514'; end if;
   date_count:=jsonb_array_length(new.delivery_part_dates);
   if date_count<>0 then
     if date_count<>jsonb_array_length(new.delivery_plan) or exists(select 1 from jsonb_array_elements(new.delivery_part_dates) with ordinality x(value,i) where coalesce(x.value->>'date','') !~ '^\d{4}-\d{2}-\d{2}$' or (x.value->>'part')::integer<>x.i) or (select count(distinct x->>'date') from jsonb_array_elements(new.delivery_part_dates) x)<>date_count then
       raise exception 'Assign one distinct date to every delivery part.' using errcode='23514';
     end if;
     if new.date_mode<>'specific' or new.session_dates is null or cardinality(new.session_dates)<>date_count or exists(select 1 from jsonb_array_elements(new.delivery_part_dates) x where not (x->>'date')::date=any(new.session_dates)) then raise exception 'Session dates must match the delivery part dates.' using errcode='23514'; end if;
   end if;
 end if;
 return new;
end $function$
;

CREATE OR REPLACE FUNCTION public.validate_selected_program_modality()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'public'
AS $function$
begin
 if new.program_link_origin='program_selection' and new.modality_id is not null and jsonb_array_length(coalesce(new.program_info_snapshot->'allowedModalities','[]'::jsonb))>0 and not exists(select 1 from jsonb_array_elements_text(new.program_info_snapshot->'allowedModalities') x where x=new.modality_id) then
   raise exception 'This delivery method is not permitted by the selected Learning Program.' using errcode='23514';
 end if;
 return new;
end $function$
;

-- Triggers
CREATE TRIGGER learning_program_archived_read_only BEFORE DELETE OR UPDATE ON public.learning_programs FOR EACH ROW EXECUTE FUNCTION reject_archived_learning_program_changes();
CREATE TRIGGER learning_program_family_default BEFORE INSERT ON public.learning_programs FOR EACH ROW EXECUTE FUNCTION set_learning_program_family();
CREATE TRIGGER learning_program_used_content_lock BEFORE UPDATE ON public.learning_programs FOR EACH ROW EXECUTE FUNCTION lock_used_learning_program_content();
CREATE TRIGGER learning_program_version_identity BEFORE INSERT OR UPDATE OF code, supersedes_program_id, program_family_id ON public.learning_programs FOR EACH ROW EXECUTE FUNCTION learning_program_version_identity();
CREATE TRIGGER trg_guard_profile_privileged_columns BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION guard_profile_privileged_columns();
CREATE TRIGGER trg_training_report_requires_delivery_complete BEFORE INSERT OR UPDATE OF status, session_id ON public.training_reports FOR EACH ROW EXECUTE FUNCTION guard_training_report_submission();
CREATE TRIGGER guard_training_session_program_link BEFORE INSERT OR UPDATE ON public.training_sessions FOR EACH ROW EXECUTE FUNCTION guard_training_session_program_link();
CREATE TRIGGER training_session_historical_mapping_guard BEFORE INSERT OR UPDATE OF program_id, program_link_origin ON public.training_sessions FOR EACH ROW EXECUTE FUNCTION validate_historical_program_mapping();
CREATE TRIGGER trg_enforce_program_selected_batch BEFORE INSERT OR UPDATE OF batch_no, program_id, program_link_origin, training_date, session_dates, delivery_part_dates ON public.training_sessions FOR EACH ROW EXECUTE FUNCTION private.enforce_program_selected_batch();
CREATE TRIGGER trg_guard_training_session_protected_changes BEFORE DELETE OR UPDATE ON public.training_sessions FOR EACH ROW EXECUTE FUNCTION guard_training_session_protected_changes();
CREATE TRIGGER trg_sync_training_batch_counter_from_mapping AFTER INSERT OR UPDATE OF program_id, program_link_origin, batch_no, training_date, session_dates, delivery_part_dates ON public.training_sessions FOR EACH ROW EXECUTE FUNCTION private.sync_training_batch_counter_from_session();
CREATE TRIGGER z_training_session_program_snapshot BEFORE INSERT OR UPDATE ON public.training_sessions FOR EACH ROW EXECUTE FUNCTION apply_learning_program_session_snapshot();
CREATE TRIGGER zz_snapshot_learning_program_delivery_plan BEFORE INSERT OR UPDATE ON public.training_sessions FOR EACH ROW EXECUTE FUNCTION snapshot_learning_program_delivery_plan();
CREATE TRIGGER zz_snapshot_selected_program_information BEFORE INSERT OR UPDATE ON public.training_sessions FOR EACH ROW EXECUTE FUNCTION snapshot_selected_program_information();
CREATE TRIGGER zzz_validate_learning_program_delivery_dates BEFORE INSERT OR UPDATE ON public.training_sessions FOR EACH ROW EXECUTE FUNCTION validate_learning_program_delivery_dates();
CREATE TRIGGER zzz_validate_selected_program_modality BEFORE INSERT OR UPDATE ON public.training_sessions FOR EACH ROW EXECUTE FUNCTION validate_selected_program_modality();

-- Row level security
alter table private.training_batch_counters enable row level security;
alter table public.agenda_templates enable row level security;
alter table public.attendance_settings enable row level security;
alter table public.audiences enable row level security;
alter table public.audit_log enable row level security;
alter table public.categories enable row level security;
alter table public.cdqa_reviews enable row level security;
alter table public.checklist_templates enable row level security;
alter table public.deliverables enable row level security;
alter table public.departments enable row level security;
alter table public.evaluations enable row level security;
alter table public.facilitation_cost_rates enable row level security;
alter table public.idqa_reviews enable row level security;
alter table public.kpi_monthly_snapshots enable row level security;
alter table public.kpi_settings enable row level security;
alter table public.kpi_targets enable row level security;
alter table public.learning_programs enable row level security;
alter table public.modalities enable row level security;
alter table public.ph_holidays enable row level security;
alter table public.positions enable row level security;
alter table public.profiles enable row level security;
alter table public.program_types enable row level security;
alter table public.session_checklists enable row level security;
alter table public.session_participants enable row level security;
alter table public.training_reports enable row level security;
alter table public.training_sessions enable row level security;
alter table public.venues enable row level security;
alter table public.workload_pct_history enable row level security;
alter table public.workload_settings enable row level security;

-- Policies
create policy agenda_templates_select on public.agenda_templates as PERMISSIVE for SELECT to public
  using ((auth.role() = 'authenticated'::text));

create policy agenda_templates_write on public.agenda_templates as PERMISSIVE for ALL to public
  using (is_admin())
  with check (is_admin());

create policy attendance_settings_select on public.attendance_settings as PERMISSIVE for SELECT to public
  using ((auth.role() = 'authenticated'::text));

create policy attendance_settings_write on public.attendance_settings as PERMISSIVE for ALL to public
  using (is_admin())
  with check (is_admin());

create policy audiences_select on public.audiences as PERMISSIVE for SELECT to public
  using ((auth.role() = 'authenticated'::text));

create policy audiences_write on public.audiences as PERMISSIVE for ALL to public
  using (is_admin())
  with check (is_admin());

create policy audit_insert on public.audit_log as PERMISSIVE for INSERT to public
  with check ((auth.role() = 'authenticated'::text));

create policy audit_select on public.audit_log as PERMISSIVE for SELECT to authenticated
  using (true);

create policy categories_select on public.categories as PERMISSIVE for SELECT to public
  using ((auth.role() = 'authenticated'::text));

create policy categories_write on public.categories as PERMISSIVE for ALL to public
  using (is_admin())
  with check (is_admin());

create policy cdqa_delete on public.cdqa_reviews as PERMISSIVE for DELETE to public
  using ((((reviewer_id = auth.uid()) AND (status = 'draft'::text)) OR is_admin()));

create policy cdqa_insert on public.cdqa_reviews as PERMISSIVE for INSERT to public
  with check (((reviewer_id = auth.uid()) OR is_admin()));

create policy cdqa_select on public.cdqa_reviews as PERMISSIVE for SELECT to public
  using (((author_id = auth.uid()) OR (reviewer_id = auth.uid()) OR is_admin() OR is_reports_viewer()));

create policy cdqa_update on public.cdqa_reviews as PERMISSIVE for UPDATE to public
  using ((((reviewer_id = auth.uid()) AND (status = 'draft'::text)) OR ((author_id = auth.uid()) AND (status = 'pending_ack'::text)) OR is_admin()))
  with check (((reviewer_id = auth.uid()) OR ((author_id = auth.uid()) AND (status = 'completed'::text)) OR is_admin()));

create policy checklist_templates_all on public.checklist_templates as PERMISSIVE for ALL to authenticated
  using (true)
  with check (true);

create policy deliverables_select on public.deliverables as PERMISSIVE for SELECT to public
  using ((auth.role() = 'authenticated'::text));

create policy deliverables_write on public.deliverables as PERMISSIVE for ALL to public
  using (is_admin())
  with check (is_admin());

create policy departments_select on public.departments as PERMISSIVE for SELECT to public
  using ((auth.role() = 'authenticated'::text));

create policy departments_write on public.departments as PERMISSIVE for ALL to public
  using (is_admin())
  with check (is_admin());

create policy evaluations_delete on public.evaluations as PERMISSIVE for DELETE to public
  using ((((evaluator_id = auth.uid()) AND (status = 'draft'::text)) OR is_admin()));

create policy evaluations_insert on public.evaluations as PERMISSIVE for INSERT to public
  with check (((evaluator_id = auth.uid()) OR is_admin()));

create policy evaluations_select on public.evaluations as PERMISSIVE for SELECT to public
  using (((evaluator_id = auth.uid()) OR (trainer_id = auth.uid()) OR is_admin() OR is_reports_viewer()));

create policy evaluations_update on public.evaluations as PERMISSIVE for UPDATE to public
  using ((((evaluator_id = auth.uid()) AND (status = 'draft'::text)) OR ((trainer_id = auth.uid()) AND (status = 'pending_ack'::text)) OR is_admin()))
  with check (((evaluator_id = auth.uid()) OR ((trainer_id = auth.uid()) AND (status = 'completed'::text)) OR is_admin()));

create policy "cost rates: manage" on public.facilitation_cost_rates as PERMISSIVE for ALL to public
  using ((EXISTS ( SELECT 1
   FROM profiles p
  WHERE ((p.id = auth.uid()) AND p.can_manage_facilitation_rates))))
  with check ((EXISTS ( SELECT 1
   FROM profiles p
  WHERE ((p.id = auth.uid()) AND p.can_manage_facilitation_rates))));

create policy "cost rates: view" on public.facilitation_cost_rates as PERMISSIVE for SELECT to public
  using ((EXISTS ( SELECT 1
   FROM profiles p
  WHERE ((p.id = auth.uid()) AND (p.can_view_training_costs OR p.can_manage_facilitation_rates)))));

create policy idqa_delete on public.idqa_reviews as PERMISSIVE for DELETE to public
  using ((((reviewer_id = auth.uid()) AND (status = 'draft'::text)) OR is_admin()));

create policy idqa_insert on public.idqa_reviews as PERMISSIVE for INSERT to public
  with check (((reviewer_id = auth.uid()) OR is_admin()));

create policy idqa_select on public.idqa_reviews as PERMISSIVE for SELECT to public
  using (((designer_id = auth.uid()) OR (reviewer_id = auth.uid()) OR is_admin() OR is_reports_viewer()));

create policy idqa_update on public.idqa_reviews as PERMISSIVE for UPDATE to public
  using ((((reviewer_id = auth.uid()) AND (status = 'draft'::text)) OR ((designer_id = auth.uid()) AND (status = 'pending_ack'::text)) OR is_admin()))
  with check (((reviewer_id = auth.uid()) OR ((designer_id = auth.uid()) AND (status = 'completed'::text)) OR is_admin()));

create policy kpi_snapshots_delete on public.kpi_monthly_snapshots as PERMISSIVE for DELETE to authenticated
  using (is_admin());

create policy kpi_snapshots_insert on public.kpi_monthly_snapshots as PERMISSIVE for INSERT to authenticated
  with check (is_admin());

create policy kpi_snapshots_select on public.kpi_monthly_snapshots as PERMISSIVE for SELECT to authenticated
  using (true);

create policy kpi_settings_select on public.kpi_settings as PERMISSIVE for SELECT to authenticated
  using (true);

create policy kpi_settings_update on public.kpi_settings as PERMISSIVE for UPDATE to authenticated
  using (is_admin())
  with check (is_admin());

create policy kpi_targets_delete on public.kpi_targets as PERMISSIVE for DELETE to authenticated
  using (is_admin());

create policy kpi_targets_insert on public.kpi_targets as PERMISSIVE for INSERT to authenticated
  with check (is_admin());

create policy kpi_targets_select on public.kpi_targets as PERMISSIVE for SELECT to authenticated
  using (true);

create policy kpi_targets_update on public.kpi_targets as PERMISSIVE for UPDATE to authenticated
  using (is_admin())
  with check (is_admin());

create policy learning_programs_delete on public.learning_programs as PERMISSIVE for DELETE to authenticated
  using (is_admin());

create policy learning_programs_insert on public.learning_programs as PERMISSIVE for INSERT to authenticated
  with check ((is_admin() OR (EXISTS ( SELECT 1
   FROM profiles p
  WHERE ((p.id = auth.uid()) AND (p.position_id = ANY (ARRAY['pos_1'::text, 'pos_2'::text, 'pos_3'::text, 'pos_4'::text, 'pos_5'::text, 'pos_7'::text]))))) OR (EXISTS ( SELECT 1
   FROM profiles q
  WHERE (q.supervisor_id = auth.uid())))));

create policy learning_programs_select on public.learning_programs as PERMISSIVE for SELECT to authenticated
  using (true);

create policy learning_programs_update on public.learning_programs as PERMISSIVE for UPDATE to authenticated
  using ((is_admin() OR (EXISTS ( SELECT 1
   FROM profiles p
  WHERE ((p.id = auth.uid()) AND (p.position_id = ANY (ARRAY['pos_1'::text, 'pos_2'::text, 'pos_3'::text, 'pos_4'::text, 'pos_5'::text, 'pos_7'::text]))))) OR (EXISTS ( SELECT 1
   FROM profiles q
  WHERE (q.supervisor_id = auth.uid())))))
  with check ((is_admin() OR (EXISTS ( SELECT 1
   FROM profiles p
  WHERE ((p.id = auth.uid()) AND (p.position_id = ANY (ARRAY['pos_1'::text, 'pos_2'::text, 'pos_3'::text, 'pos_4'::text, 'pos_5'::text, 'pos_7'::text]))))) OR (EXISTS ( SELECT 1
   FROM profiles q
  WHERE (q.supervisor_id = auth.uid())))));

create policy modalities_select on public.modalities as PERMISSIVE for SELECT to public
  using ((auth.role() = 'authenticated'::text));

create policy modalities_write on public.modalities as PERMISSIVE for ALL to public
  using (is_admin())
  with check (is_admin());

create policy ph_holidays_select on public.ph_holidays as PERMISSIVE for SELECT to public
  using ((auth.role() = 'authenticated'::text));

create policy ph_holidays_write on public.ph_holidays as PERMISSIVE for ALL to public
  using (is_admin())
  with check (is_admin());

create policy positions_select on public.positions as PERMISSIVE for SELECT to public
  using ((auth.role() = 'authenticated'::text));

create policy positions_write on public.positions as PERMISSIVE for ALL to public
  using (is_admin())
  with check (is_admin());

create policy profiles_admin_delete on public.profiles as PERMISSIVE for DELETE to public
  using (is_admin());

create policy profiles_admin_write on public.profiles as PERMISSIVE for INSERT to public
  with check (is_admin());

create policy profiles_select on public.profiles as PERMISSIVE for SELECT to public
  using ((auth.role() = 'authenticated'::text));

create policy profiles_update_self_or_admin on public.profiles as PERMISSIVE for UPDATE to public
  using (((id = auth.uid()) OR is_admin()))
  with check (((id = auth.uid()) OR is_admin()));

create policy program_types_select on public.program_types as PERMISSIVE for SELECT to public
  using ((auth.role() = 'authenticated'::text));

create policy program_types_write on public.program_types as PERMISSIVE for ALL to public
  using (is_admin())
  with check (is_admin());

create policy session_checklists_all on public.session_checklists as PERMISSIVE for ALL to authenticated
  using (true)
  with check (true);

create policy session_participants_select on public.session_participants as PERMISSIVE for SELECT to public
  using ((auth.role() = 'authenticated'::text));

create policy session_participants_write on public.session_participants as PERMISSIVE for ALL to public
  using ((auth.role() = 'authenticated'::text))
  with check ((auth.role() = 'authenticated'::text));

create policy training_reports_select on public.training_reports as PERMISSIVE for SELECT to public
  using ((auth.role() = 'authenticated'::text));

create policy training_reports_write on public.training_reports as PERMISSIVE for ALL to public
  using ((auth.role() = 'authenticated'::text))
  with check ((auth.role() = 'authenticated'::text));

create policy sessions_select on public.training_sessions as PERMISSIVE for SELECT to public
  using ((auth.role() = 'authenticated'::text));

create policy sessions_write on public.training_sessions as PERMISSIVE for ALL to public
  using ((auth.role() = 'authenticated'::text))
  with check ((auth.role() = 'authenticated'::text));

create policy venues_select on public.venues as PERMISSIVE for SELECT to public
  using ((auth.role() = 'authenticated'::text));

create policy venues_write on public.venues as PERMISSIVE for ALL to public
  using (is_admin())
  with check (is_admin());

create policy workload_pct_history_select on public.workload_pct_history as PERMISSIVE for SELECT to public
  using ((auth.role() = 'authenticated'::text));

create policy workload_pct_history_write on public.workload_pct_history as PERMISSIVE for ALL to public
  using (is_admin())
  with check (is_admin());

create policy workload_settings_select on public.workload_settings as PERMISSIVE for SELECT to public
  using ((auth.role() = 'authenticated'::text));

create policy workload_settings_write on public.workload_settings as PERMISSIVE for ALL to public
  using (is_admin())
  with check (is_admin());
