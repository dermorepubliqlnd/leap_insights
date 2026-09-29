-- Migration 20260928091236_add_learning_program_evaluation_config
-- Exported verbatim from supabase_migrations.schema_migrations (live project catvpurbyvsnijxpzwoh) on 2026-09-29.
-- Already applied to production. Do not re-run manually.

alter table public.learning_programs
  add column evaluation_config jsonb not null default '{"l1":false,"l2":{"pre":false,"post":false},"l3":{"enabled":false,"method":"","daysAfter":null},"l4":{"enabled":false,"measure":"","baseline":"","target":""}}'::jsonb;
update public.learning_programs
set evaluation_config = jsonb_set(evaluation_config, '{l3,enabled}', 'true'::jsonb, true)
where l3_required = true;
alter table public.learning_programs
  add constraint learning_programs_evaluation_config_object check (jsonb_typeof(evaluation_config) = 'object');
