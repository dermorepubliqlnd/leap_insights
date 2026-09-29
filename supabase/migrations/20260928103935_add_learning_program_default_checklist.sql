-- Migration 20260928103935_add_learning_program_default_checklist
-- Exported verbatim from supabase_migrations.schema_migrations (live project catvpurbyvsnijxpzwoh) on 2026-09-29.
-- Already applied to production. Do not re-run manually.

alter table public.learning_programs add column checklist_template_id text references public.checklist_templates(id) on delete restrict;
