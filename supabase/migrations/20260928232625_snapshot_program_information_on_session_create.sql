-- Migration 20260928232625_snapshot_program_information_on_session_create
-- Exported verbatim from supabase_migrations.schema_migrations (live project catvpurbyvsnijxpzwoh) on 2026-09-29.
-- Already applied to production. Do not re-run manually.

alter table public.training_sessions add column if not exists program_info_snapshot jsonb not null default '{}'::jsonb;
create or replace function public.snapshot_selected_program_information() returns trigger language plpgsql set search_path=pg_catalog,public as $$
declare p public.learning_programs%rowtype;
begin
 if tg_op='INSERT' and new.program_link_origin='program_selection' then
   select * into p from public.learning_programs where id=new.program_id;
   if not found then raise exception 'Learning Program not found.' using errcode='23514'; end if;
   new.program_info_snapshot:=jsonb_build_object('code',p.code,'title',p.title,'version',p.version,'description',p.description,'agenda',p.agenda,'deliveryType',p.delivery_type);
 elsif tg_op='UPDATE' and old.program_link_origin='program_selection' and new.program_id is not distinct from old.program_id then
   new.program_info_snapshot:=old.program_info_snapshot;
 end if;
 return new;
end $$;
drop trigger if exists zz_snapshot_selected_program_information on public.training_sessions;
create trigger zz_snapshot_selected_program_information before insert or update on public.training_sessions for each row execute function public.snapshot_selected_program_information();
