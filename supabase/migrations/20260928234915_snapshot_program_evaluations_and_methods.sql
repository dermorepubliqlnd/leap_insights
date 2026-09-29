-- Migration 20260928234915_snapshot_program_evaluations_and_methods
-- Exported verbatim from supabase_migrations.schema_migrations (live project catvpurbyvsnijxpzwoh) on 2026-09-29.
-- Already applied to production. Do not re-run manually.

alter table public.training_sessions add column if not exists evaluation_plan jsonb not null default '{}'::jsonb;
create or replace function public.snapshot_selected_program_information() returns trigger language plpgsql set search_path=pg_catalog,public as $$
declare p public.learning_programs%rowtype;
begin
 if tg_op='INSERT' and new.program_link_origin='program_selection' then
   select * into p from public.learning_programs where id=new.program_id;
   if not found then raise exception 'Learning Program not found.' using errcode='23514'; end if;
   new.program_info_snapshot:=jsonb_build_object('code',p.code,'title',p.title,'version',p.version,'description',p.description,'agenda',p.agenda,'deliveryType',p.delivery_type,'resourceUrl',p.resource_url,'allowedModalities',p.allowed_modalities,'effectiveFrom',p.effective_from,'effectiveTo',p.effective_to);
   new.evaluation_plan:=coalesce(p.evaluation_config,'{}'::jsonb);
   new.l3_required:=coalesce((p.evaluation_config->'l3'->>'enabled')::boolean,false);
   new.l3_methods:=coalesce((select jsonb_agg(x->>'method') from jsonb_array_elements(coalesce(p.evaluation_config->'l3'->'items','[]'::jsonb)) x),'[]'::jsonb);
 elsif tg_op='UPDATE' and old.program_link_origin='program_selection' and new.program_id is not distinct from old.program_id then
   new.program_info_snapshot:=old.program_info_snapshot;
   new.evaluation_plan:=old.evaluation_plan;
   new.l3_required:=old.l3_required;
 end if;
 return new;
end $$;
