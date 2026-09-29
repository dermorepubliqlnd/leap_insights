-- Migration 20260928102059_add_learning_program_session_mapping
-- Exported verbatim from supabase_migrations.schema_migrations (live project catvpurbyvsnijxpzwoh) on 2026-09-29.
-- Already applied to production. Do not re-run manually.

alter table public.training_sessions
  add column program_id text references public.learning_programs(id) on delete restrict,
  add column program_link_origin text,
  add column program_linked_at timestamptz,
  add constraint training_sessions_program_link_consistency check (
    (program_id is null and program_link_origin is null and program_linked_at is null)
    or (program_id is not null and program_link_origin in ('catalog_mapping','program_selection') and program_linked_at is not null)
  );
create index training_sessions_program_id_idx on public.training_sessions(program_id) where program_id is not null;
