-- Migration 20260928234728_program_allowed_modalities_and_published_content_lock
-- Exported verbatim from supabase_migrations.schema_migrations (live project catvpurbyvsnijxpzwoh) on 2026-09-29.
-- Already applied to production. Do not re-run manually.

alter table public.learning_programs add column if not exists allowed_modalities text[] not null default '{}'::text[];
create or replace function public.lock_used_learning_program_content() returns trigger language plpgsql set search_path=pg_catalog,public as $$
begin
 if old.status='active' and exists(select 1 from public.training_sessions s where s.program_id=old.id and s.status in ('scheduled','completed') and s.program_link_origin in ('program_selection','catalog_mapping')) then
   if row(new.title,new.category_id,new.delivery_type,new.description,new.resource_url,new.checklist_template_id,new.agenda,new.delivery_parts,new.assessments,new.evaluation_config,new.contributors,new.allowed_modalities) is distinct from row(old.title,old.category_id,old.delivery_type,old.description,old.resource_url,old.checklist_template_id,old.agenda,old.delivery_parts,old.assessments,old.evaluation_config,old.contributors,old.allowed_modalities) then
     raise exception 'This program version has scheduled or completed implementations. Create a new version for content changes.' using errcode='23514';
   end if;
 end if;
 return new;
end $$;
drop trigger if exists learning_program_used_content_lock on public.learning_programs;
create trigger learning_program_used_content_lock before update on public.learning_programs for each row execute function public.lock_used_learning_program_content();
