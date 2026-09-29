# Supabase (LEAP Insights)

Project ref: `catvpurbyvsnijxpzwoh`. Production frontend: `index.html` on `main` (GitHub Pages).

## Layout

- `migrations/`: every migration recorded in the live `supabase_migrations.schema_migrations` table (43 files, 2026-09-28 onward). Exported verbatim, and the file names match the remote versions, so `supabase migration list` lines up. All of them are already applied to production.
- `schema/20260929_live_schema_snapshot.sql`: a catalog-generated snapshot of the full current schema (public + private). Tables created before 2026-09-28 were applied by hand in the SQL editor and have no migration, so this snapshot is the record of that baseline.
- `functions/admin-user-actions/`: an Edge Function that uses the service-role key from its environment. The key is never stored in the repo.

## Rules

- Never commit a service-role or secret key. The frontend uses only the anon key.
- New schema changes: add `supabase/migrations/<UTC timestamp>_<name>.sql`, apply it, and make sure it is recorded in the migration history. Don't edit files that are already applied.
- Don't re-run historical migrations against production. Some copy data (for example `pre_migration_training_snapshot_20260929`) or backfill it.
