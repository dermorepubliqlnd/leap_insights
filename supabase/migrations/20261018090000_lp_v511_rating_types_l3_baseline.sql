-- Migration 20261018090000_lp_v511_rating_types_l3_baseline
-- v5.11 (2026-10-18, per Sandra):
--  1. L2 rating types (Confidence Self-Assessment, Commitment / Action Plan) are 1–5 self-ratings: no passing % required.
--  2. L3 items can be a Baseline (start of session): stored as daysAfter 0 + timing 'baseline'.
--  3. Session snapshot now carries L3 responsible + timing, and L4 daysAfter + unit (previously dropped on session create).
-- Replaces function bodies only (constraints/triggers unchanged). Idempotent.

create or replace function public.learning_program_l2_valid(config jsonb, items jsonb)
returns boolean language plpgsql immutable set search_path to 'public' as $function$
declare item jsonb; score text;
begin
  if coalesce(config #>> '{l2,enabled}','false') <> 'true' then return true; end if;
  if jsonb_typeof(items) <> 'array' or jsonb_array_length(items)=0 then return false; end if;
  for item in select value from jsonb_array_elements(items) loop
    if nullif(btrim(item->>'name'),'') is null then return false; end if;
    if item->'pre' is distinct from 'true'::jsonb and item->'post' is distinct from 'true'::jsonb then return false; end if;
    if item->'post' = 'true'::jsonb
       and coalesce(btrim(item->>'type'),'') not in ('Confidence Self-Assessment','Commitment / Action Plan') then
      score := item->>'passingScore';
      if score is null or score !~ '^[0-9]+(\.[0-9]+)?$' then return false; end if;
      if score::numeric < 0 or score::numeric > 100 then return false; end if;
    end if;
  end loop;
  return true;
end $function$;

create or replace function public.learning_program_levels_valid(config jsonb)
returns boolean language plpgsql immutable set search_path to 'public' as $function$
declare item jsonb; days text; items jsonb; is_baseline boolean;
begin
  if config #>> '{l3,enabled}'='true' then
    items:=config #> '{l3,items}';
    if jsonb_typeof(items)<>'array' or jsonb_array_length(items)=0 then return false; end if;
    for item in select value from jsonb_array_elements(items) loop
      days:=item->>'daysAfter';
      is_baseline:=coalesce(item->>'timing','')='baseline';
      if nullif(btrim(item->>'method'),'') is null or days is null or days !~ '^[0-9]+$' or length(days)>4 or days::integer>3650 then return false; end if;
      if days::integer<1 and not (is_baseline and days::integer=0) then return false; end if;
    end loop;
  end if;
  if config #>> '{l4,enabled}'='true' then
    items:=config #> '{l4,items}';
    if jsonb_typeof(items)<>'array' or jsonb_array_length(items)=0 then return false; end if;
    for item in select value from jsonb_array_elements(items) loop
      if nullif(btrim(item->>'measure'),'') is null then return false; end if;
    end loop;
  end if;
  return true;
end $function$;

create or replace function public.snapshot_selected_program_information()
returns trigger language plpgsql set search_path to 'pg_catalog', 'public' as $function$
declare p public.learning_programs%rowtype;
begin
 if tg_op='INSERT' and new.program_link_origin='program_selection' then
   select * into p from public.learning_programs where id=new.program_id;
   if not found then raise exception 'Learning Program not found.' using errcode='23514'; end if;
   new.program_info_snapshot:=jsonb_build_object('code',p.code,'title',p.title,'version',p.version,'revision',p.revision,'description',p.description,'agenda',p.agenda,'deliveryType',p.delivery_type,'resourceUrl',p.resource_url,'allowedModalities',p.allowed_modalities,'effectiveFrom',p.effective_from,'effectiveTo',p.effective_to,'contributors',p.contributors);
   new.evaluation_plan:=coalesce(p.evaluation_config,'{}'::jsonb);
   new.l3_required:=coalesce((p.evaluation_config->'l3'->>'enabled')::boolean,false);
   new.l3_methods:=coalesce((select jsonb_agg(x->>'method') from jsonb_array_elements(coalesce(p.evaluation_config->'l3'->'items','[]'::jsonb)) x),'[]'::jsonb);
   new.l3_followups:=coalesce((select jsonb_agg(jsonb_build_object('method',x->>'method','responsible',coalesce(x->>'responsible',''),'timing',coalesce(x->>'timing','followup'),'daysAfter',nullif(x->>'daysAfter','')::integer,'notes',coalesce(x->>'notes',''),'dueDate',null,'rating',null,'evidence','','completedAt',null)) from jsonb_array_elements(coalesce(p.evaluation_config->'l3'->'items','[]'::jsonb)) x),'[]'::jsonb);
   new.l4_results:=coalesce((select jsonb_agg(jsonb_build_object('measure',x->>'measure','baseline',coalesce(x->>'baseline',''),'target',coalesce(x->>'target',''),'unit',coalesce(x->>'unit',''),'daysAfter',case when coalesce(x->>'daysAfter','') ~ '^[0-9]+$' then (x->>'daysAfter')::integer end,'actual','','notes','')) from jsonb_array_elements(coalesce(p.evaluation_config->'l4'->'items','[]'::jsonb)) x),'[]'::jsonb);
 elsif tg_op='UPDATE' and old.program_link_origin='program_selection' and new.program_id is not distinct from old.program_id then
   new.program_info_snapshot:=old.program_info_snapshot;
   new.evaluation_plan:=old.evaluation_plan;
   new.l3_required:=old.l3_required;
 end if;
 return new;
end $function$;
