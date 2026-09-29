-- Migration 20260928094326_add_learning_program_duration_minutes
-- Exported verbatim from supabase_migrations.schema_migrations (live project catvpurbyvsnijxpzwoh) on 2026-09-29.
-- Already applied to production. Do not re-run manually.

alter table public.learning_programs add column duration_minutes integer;
alter table public.learning_programs add constraint learning_programs_duration_minutes_positive check (duration_minutes is null or duration_minutes > 0);
