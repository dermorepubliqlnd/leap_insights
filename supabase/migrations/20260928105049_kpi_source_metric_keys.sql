-- Migration 20260928105049_kpi_source_metric_keys
-- Exported verbatim from supabase_migrations.schema_migrations (live project catvpurbyvsnijxpzwoh) on 2026-09-29.
-- Already applied to production. Do not re-run manually.

update public.kpi_targets set data_source=case kpi_key when 'facil' then 'facil' when 'obs' then 'obs' when 'pass' then 'pass' when 'report' then 'report' else data_source end where data_source in ('trainer_evaluation','assessment','training_report');
