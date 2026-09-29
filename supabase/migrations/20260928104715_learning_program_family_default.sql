-- Migration 20260928104715_learning_program_family_default
-- Exported verbatim from supabase_migrations.schema_migrations (live project catvpurbyvsnijxpzwoh) on 2026-09-29.
-- Already applied to production. Do not re-run manually.

create or replace function public.set_learning_program_family() returns trigger language plpgsql set search_path=public as $$ begin if new.program_family_id is null then new.program_family_id:=new.id; end if; return new; end $$; drop trigger if exists learning_program_family_default on public.learning_programs; create trigger learning_program_family_default before insert on public.learning_programs for each row execute function public.set_learning_program_family();
