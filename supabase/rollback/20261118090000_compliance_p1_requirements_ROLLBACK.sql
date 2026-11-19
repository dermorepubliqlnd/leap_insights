-- ROLLBACK for 20261118090000_compliance_p1_requirements (removes only what that migration added)
drop trigger if exists trg_lp_requirement_on_activation on public.learning_programs;
drop function if exists public.lp_requirement_on_activation();
drop table if exists public.lp_requirement_events;
drop table if exists public.lp_requirements;
drop function if exists public.lp_requirements_after();
drop function if exists public.lp_requirements_before();
drop function if exists public.lp_family_has_active(text);
drop table if exists public.compliance_levels;
delete from supabase_migrations.schema_migrations where version = '20261118090000';
