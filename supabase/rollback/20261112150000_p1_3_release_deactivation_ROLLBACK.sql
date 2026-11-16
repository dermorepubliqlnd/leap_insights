-- ROLLBACK for 20261112150000_p1_3_release_deactivation (back to Preview-only behavior)
-- 1) Re-run the function bodies from 20261112140000_p1_3_deactivation_blocks_signin.sql (preview-gated).
-- 2) Lift the one-time ban on the account that was already inactive before release (Redrico):
update auth.users set banned_until = null
 where id in (select id from public.profiles where first_name ilike 'Redrico%' and not is_active);
delete from supabase_migrations.schema_migrations where version = '20261112150000';
-- Full removal of Fix 1.3: supabase/rollback/20261112140000_p1_3_deactivation_blocks_signin_ROLLBACK.sql
