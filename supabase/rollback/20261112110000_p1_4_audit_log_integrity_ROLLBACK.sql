-- ROLLBACK for 20261112110000_p1_4_audit_log_integrity (Fix 1.4)
-- Removes the audit-log stamping rule. Run only if Sandra approves a rollback.
-- Option A (keeps names already captured): remove trigger + function only.
drop trigger if exists trg_audit_log_stamp on public.audit_log;
drop function if exists public.audit_log_stamp();
delete from supabase_migrations.schema_migrations where version = '20261112110000';
-- Option B (full removal, also deletes captured names): uncomment the next line.
-- alter table public.audit_log drop column if exists actor_name;

-- Verify (expect 0 / 0):
select (select count(*) from pg_trigger where tgname = 'trg_audit_log_stamp') as trigger_left,
       (select count(*) from pg_proc where proname = 'audit_log_stamp') as function_left;
