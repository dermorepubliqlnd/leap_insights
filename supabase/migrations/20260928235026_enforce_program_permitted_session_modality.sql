-- Migration 20260928235026_enforce_program_permitted_session_modality
-- Exported verbatim from supabase_migrations.schema_migrations (live project catvpurbyvsnijxpzwoh) on 2026-09-29.
-- Already applied to production. Do not re-run manually.

create or replace function public.validate_selected_program_modality() returns trigger language plpgsql set search_path=pg_catalog,public as $$
begin
 if new.program_link_origin='program_selection' and new.modality_id is not null and jsonb_array_length(coalesce(new.program_info_snapshot->'allowedModalities','[]'::jsonb))>0 and not exists(select 1 from jsonb_array_elements_text(new.program_info_snapshot->'allowedModalities') x where x=new.modality_id) then
   raise exception 'This delivery method is not permitted by the selected Learning Program.' using errcode='23514';
 end if;
 return new;
end $$;
drop trigger if exists zzz_validate_selected_program_modality on public.training_sessions;
create trigger zzz_validate_selected_program_modality before insert or update on public.training_sessions for each row execute function public.validate_selected_program_modality();
