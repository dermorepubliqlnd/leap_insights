-- ROLLBACK for 20261112100000_p1_1_last_admin_guard (Fix 1.1)
-- Removes the last-admin safeguard completely. Changes no data.
-- Run in the Supabase SQL editor only if Sandra approves a rollback.
drop trigger if exists trg_guard_last_admin on public.profiles;
drop function if exists public.guard_last_admin();
delete from supabase_migrations.schema_migrations where version = '20261112100000';

-- Verify (expect 0 / 0):
select (select count(*) from pg_trigger where tgname = 'trg_guard_last_admin') as trigger_left,
       (select count(*) from pg_proc where proname = 'guard_last_admin') as function_left;
