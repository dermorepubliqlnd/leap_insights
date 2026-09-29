-- Migration 20260929095400_dedupe_standardized_audience_master
-- Exported verbatim from supabase_migrations.schema_migrations (live project catvpurbyvsnijxpzwoh) on 2026-09-29.
-- Already applied to production. Do not re-run manually.


-- Keep the canonical forward-looking audience options active.
-- Preserve duplicate legacy rows as inactive rather than deleting them.
update public.audiences
set is_active=false
where name='Individual Contributors'
  and id<>'aud_individual_contributors';
