-- Migration 20260928084506_add_learning_program_duration_hours
-- Exported verbatim from supabase_migrations.schema_migrations (live project catvpurbyvsnijxpzwoh) on 2026-09-29.
-- Already applied to production. Do not re-run manually.

alter table public.learning_programs add column duration_hours numeric(8,2);
alter table public.learning_programs add constraint learning_programs_duration_hours_positive check (duration_hours is null or duration_hours > 0);
