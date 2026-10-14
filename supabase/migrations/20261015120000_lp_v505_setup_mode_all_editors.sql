-- Migration 20261015120000_lp_v505_setup_mode_all_editors
-- v5.05 (2026-10-15, per Sandra): while Setup Mode (app_flags.lp_versioning_paused) is ON, every user who can
-- edit Learning Programs -- not only admins -- may change in-use programs in place. Archived versions stay read
-- only, revision history stays append-only, contributor history rules (incl. admin-only date corrections) are
-- unchanged. Turning Setup Mode on/off stays admin-only (app_flags RLS).

begin;

create or replace function public.lock_used_learning_program_content()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  used boolean;
  paused boolean;
  today date := (now() at time zone 'Asia/Manila')::date;
  e jsonb;
  m jsonb;
  old_total numeric;
  new_total numeric;
begin
  if new.revision is distinct from old.revision or new.revision_history is distinct from old.revision_history then
    if new.revision <> old.revision + 1
       or jsonb_array_length(new.revision_history) <> jsonb_array_length(old.revision_history) + 1
       or (new.revision_history - (jsonb_array_length(new.revision_history) - 1)) <> old.revision_history
       or nullif(btrim(coalesce(new.revision_history->-1->>'note', '')), '') is null then
      raise exception 'Revision history can only be extended by one logged revision with a change note.' using errcode = '23514';
    end if;
  end if;

  for e in select x from jsonb_array_elements(coalesce(new.contributors, '[]'::jsonb)) x loop
    if nullif(e->>'endDate', '') is not null and nullif(e->>'startDate', '') is not null
       and (e->>'endDate')::date < (e->>'startDate')::date then
      raise exception 'A contributor assignment cannot end before it starts.' using errcode = '23514';
    end if;
  end loop;

  if old.status <> 'active' then
    return new;
  end if;

  used := exists (
    select 1 from public.training_sessions s
    where s.program_id = old.id
      and s.status in ('scheduled', 'completed')
      and s.program_link_origin in ('program_selection', 'catalog_mapping'));
  if not used then
    return new;
  end if;

  -- v5.05 Setup Mode: anyone allowed to edit programs (RLS) skips the version / minor-revision checks.
  paused := public.lp_versioning_paused();

  if not paused then
    select coalesce(sum((x->>'duration')::numeric), 0) into old_total from jsonb_array_elements(coalesce(old.agenda, '[]'::jsonb)) x;
    select coalesce(sum((x->>'duration')::numeric), 0) into new_total from jsonb_array_elements(coalesce(new.agenda, '[]'::jsonb)) x;
    if row(new.delivery_type, new.delivery_parts, new.assessments, new.evaluation_config, new.l3_required, new.allowed_modalities)
         is distinct from
       row(old.delivery_type, old.delivery_parts, old.assessments, old.evaluation_config, old.l3_required, old.allowed_modalities)
       or jsonb_array_length(coalesce(new.agenda, '[]'::jsonb)) <> jsonb_array_length(coalesce(old.agenda, '[]'::jsonb))
       or new_total <> old_total
       or new.duration_minutes is distinct from old.duration_minutes then
      raise exception 'This change needs a new program version (delivery type, parts, topic count, total duration, assessments or evaluations changed).' using errcode = '23514';
    end if;

    if (new.title is distinct from old.title or new.agenda is distinct from old.agenda)
       and new.revision = old.revision then
      raise exception 'Title or agenda changes on a program with implementations must be saved as a logged minor revision.' using errcode = '23514';
    end if;
  end if;

  for e in select x from jsonb_array_elements(coalesce(old.contributors, '[]'::jsonb)) x loop
    continue when not (e ? 'id');
    m := null;
    select x into m from jsonb_array_elements(coalesce(new.contributors, '[]'::jsonb)) x where x->>'id' = e->>'id' limit 1;
    if m is null then
      if nullif(e->>'addedAt', '') is null
         or ((e->>'addedAt')::timestamptz at time zone 'Asia/Manila')::date <> today then
        raise exception 'Contributor assignments cannot be deleted once the program has implementations. End the assignment instead.' using errcode = '23514';
      end if;
    else
      if m->>'profileId' is distinct from e->>'profileId' or m->>'role' is distinct from e->>'role' then
        raise exception 'A contributor assignment''s person and role cannot be changed. End it and add a new assignment.' using errcode = '23514';
      end if;
      if (m->>'startDate' is distinct from e->>'startDate'
          or (nullif(e->>'endDate', '') is not null and m->>'endDate' is distinct from e->>'endDate'))
         and not public.is_admin() then
        raise exception 'Only administrators can correct contributor assignment dates.' using errcode = '23514';
      end if;
    end if;
  end loop;

  return new;
end $$;

commit;
