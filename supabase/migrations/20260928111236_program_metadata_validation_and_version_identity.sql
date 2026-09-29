-- Migration 20260928111236_program_metadata_validation_and_version_identity
-- Exported verbatim from supabase_migrations.schema_migrations (live project catvpurbyvsnijxpzwoh) on 2026-09-29.
-- Already applied to production. Do not re-run manually.

alter table public.learning_programs add constraint learning_programs_title_not_blank check (nullif(btrim(title),'') is not null);
alter table public.learning_programs add constraint learning_programs_active_core_fields check (status <> 'active' or (nullif(btrim(coalesce(category_id,'')),'') is not null and nullif(btrim(coalesce(delivery_type,'')),'') is not null));
create unique index if not exists learning_programs_root_code_unique on public.learning_programs(code) where supersedes_program_id is null and code is not null;
create or replace function public.learning_program_agenda_valid(items jsonb) returns boolean language plpgsql immutable set search_path=public as $$
declare item jsonb; duration_text text;
begin
  if jsonb_typeof(items)<>'array' then return false; end if;
  for item in select value from jsonb_array_elements(items) loop
    duration_text:=item->>'duration';
    if nullif(btrim(item->>'topic'),'') is null or duration_text is null or duration_text !~ '^[0-9]+$' or length(duration_text)>8 or duration_text::integer<1 then return false; end if;
  end loop;
  return true;
end $$;
alter table public.learning_programs add constraint learning_programs_agenda_valid check (public.learning_program_agenda_valid(agenda));
create or replace function public.learning_program_levels_valid(config jsonb) returns boolean language plpgsql immutable set search_path=public as $$
declare item jsonb; days text; items jsonb;
begin
  if config #>> '{l3,enabled}'='true' then
    items:=config #> '{l3,items}';
    if jsonb_typeof(items)<>'array' or jsonb_array_length(items)=0 then return false; end if;
    for item in select value from jsonb_array_elements(items) loop
      days:=item->>'daysAfter';
      if nullif(btrim(item->>'method'),'') is null or days is null or days !~ '^[0-9]+$' or length(days)>4 or days::integer<1 or days::integer>3650 then return false; end if;
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
end $$;
alter table public.learning_programs add constraint learning_programs_levels_valid check (public.learning_program_levels_valid(evaluation_config));
alter table public.learning_programs add constraint learning_programs_resource_url_http check (resource_url is null or resource_url ~* '^https?://[^[:space:]]+$');
create or replace function public.learning_program_version_identity() returns trigger language plpgsql set search_path=public as $$
declare parent_record public.learning_programs%rowtype;
begin
  if new.supersedes_program_id is not null then
    select * into parent_record from public.learning_programs where id=new.supersedes_program_id;
    if not found or new.code is distinct from parent_record.code or new.program_family_id is distinct from parent_record.program_family_id then
      raise exception 'Version must retain its parent program code and family';
    end if;
  elsif tg_op='UPDATE' and new.code is distinct from old.code and exists(select 1 from public.learning_programs where supersedes_program_id=old.id) then
    raise exception 'Cannot change a program code after a new version exists';
  end if;
  return new;
end $$;
create trigger learning_program_version_identity before insert or update of code,supersedes_program_id,program_family_id on public.learning_programs for each row execute function public.learning_program_version_identity();
