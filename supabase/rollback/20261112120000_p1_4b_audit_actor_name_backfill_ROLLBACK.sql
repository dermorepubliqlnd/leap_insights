-- ROLLBACK for 20261112120000_p1_4b_audit_actor_name_backfill
-- Before the backfill, every audit entry older than the cutoff had actor_name empty (verified: 0 named).
-- Clearing the names on those entries restores the exact previous state. Changes nothing else.
update public.audit_log set actor_name = null where ts < '2026-11-12 06:00:00+00';
delete from supabase_migrations.schema_migrations where version = '20261112120000';
-- Checksum of all other columns before the backfill (must match after rollback too):
--   fae32f8b818b94d78d506d7581346d23  (4,694 rows)
