-- 20261112120000_p1_4b_audit_actor_name_backfill
-- What:  One-time fill of audit_log.actor_name for existing entries, from the person's CURRENT
--        profile name. Only rows with an actor_id and an empty actor_name are touched; no other
--        column changes. Entries with no actor (system / already-deleted users) stay as they are.
-- Why:   So older entries keep a readable name even if that user is deleted later (Fix 1.4).
-- Date:  2026-11-12 · Approved by: Sandra Barlao ("ok" to the one-time backfill)
-- Note:  Names reflect the profile at backfill time, not necessarily the name when the entry was made.
-- Rollback: update public.audit_log set actor_name = null where actor_name_backfilled_20261112;
--           (see supabase/rollback/20261112120000_p1_4b_audit_actor_name_backfill_ROLLBACK.sql)

update public.audit_log a
   set actor_name = nullif(btrim(coalesce(p.first_name, '') || ' ' || coalesce(p.last_name, '')), '')
  from public.profiles p
 where p.id = a.actor_id
   and a.actor_name is null
   and a.ts < '2026-11-12 06:00:00+00';   -- only entries that existed before Fix 1.4 was applied

-- Record:
-- insert into supabase_migrations.schema_migrations (version, name)
--   values ('20261112120000', 'p1_4b_audit_actor_name_backfill');
