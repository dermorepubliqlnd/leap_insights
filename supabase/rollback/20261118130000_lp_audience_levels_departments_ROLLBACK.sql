-- ROLLBACK for 20261118130000_lp_audience_levels_departments
-- Removes the triggers and functions, restores lp_requirements_before() from 20261118090000, reactivates "New Hire".
-- Columns are left in place (harmless; the live app ignores them). Drop them only if you are sure nothing reads them:
--   alter table public.learning_programs drop column audience_all_levels, drop column audience_level_ids,
--     drop column audience_all_departments, drop column audience_department_ids;
--   alter table public.lp_requirements drop constraint lp_requirements_scope_source_chk, drop column scope_source;
drop trigger if exists trg_lp_audience_on_activation on public.learning_programs;
drop trigger if exists trg_lp_audience_sync on public.learning_programs;
drop trigger if exists trg_lp_audience_before on public.learning_programs;
drop function if exists public.lp_audience_on_activation();
drop function if exists public.lp_audience_sync();
drop function if exists public.lp_audience_before();
drop function if exists public.lp_family_audience(text);
update public.compliance_levels set is_active = true where id = 'lvl_nh';
-- Then re-run the lp_requirements_before() definition from supabase/migrations/20261118090000_compliance_p1_requirements.sql
delete from supabase_migrations.schema_migrations where version = '20261118130000';
