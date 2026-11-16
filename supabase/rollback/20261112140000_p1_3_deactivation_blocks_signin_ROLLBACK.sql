-- ROLLBACK for 20261112140000_p1_3_deactivation_blocks_signin
-- Before the fix (verified 12 Nov): 0 sign-in accounts banned; 1 inactive profile (not banned).
drop trigger if exists trg_profiles_signin_sync on public.profiles;
drop function if exists public.profiles_signin_sync();

create or replace function public.is_admin()
returns boolean language sql stable set search_path to ''
as $function$ select coalesce((select p.is_admin from public.profiles p where p.id = auth.uid()), false); $function$;

create or replace function public.is_reports_viewer()
returns boolean language sql stable set search_path to ''
as $function$ select coalesce((select p.is_reports_viewer from public.profiles p where p.id = auth.uid()), false); $function$;

-- Lift any bans this fix set (all bans were set by it; none existed before):
update auth.users set banned_until = null where banned_until is not null;
delete from supabase_migrations.schema_migrations where version = '20261112140000';
