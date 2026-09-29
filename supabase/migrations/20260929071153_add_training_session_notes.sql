-- Migration 20260929071153_add_training_session_notes
-- Exported verbatim from supabase_migrations.schema_migrations (live project catvpurbyvsnijxpzwoh) on 2026-09-29.
-- Already applied to production. Do not re-run manually.


alter table public.training_sessions
  add column if not exists session_notes text;

comment on column public.training_sessions.session_notes is
'Optional session-specific notes. Separate from the Learning Program description and editable without changing the historical program/session setup.';
