-- Migration 20260929052008_pre_migration_training_snapshot_20260929
-- Exported verbatim from supabase_migrations.schema_migrations (live project catvpurbyvsnijxpzwoh) on 2026-09-29.
-- Already applied to production. Do not re-run manually.


create schema if not exists backup_pre_migration_20260929;

create table backup_pre_migration_20260929.learning_programs as
select * from public.learning_programs;

create table backup_pre_migration_20260929.training_sessions as
select * from public.training_sessions;

create table backup_pre_migration_20260929.session_participants as
select * from public.session_participants;

create table backup_pre_migration_20260929.session_checklists as
select * from public.session_checklists;

create table backup_pre_migration_20260929.training_reports as
select * from public.training_reports;

create table backup_pre_migration_20260929.evaluations as
select * from public.evaluations;

create table backup_pre_migration_20260929.audit_log as
select * from public.audit_log;

create table backup_pre_migration_20260929.snapshot_metadata (
  captured_at timestamptz not null default now(),
  source text not null,
  note text
);

insert into backup_pre_migration_20260929.snapshot_metadata(source,note)
values (
  'LEAP production public schema',
  'Pre-migration logical snapshot before Learning Program/session mapping rollout and test-data cleanup.'
);
