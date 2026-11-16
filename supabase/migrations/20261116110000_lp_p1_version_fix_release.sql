-- 20261116110000_lp_p1_version_fix_release
-- What: RELEASE to Live of 20261116100000_lp_p1_version_fix (v5.19p). Re-creates the three pieces
--   without the is_preview_request() gates:
--   (a) lp_start_new_version — next version is a DRAFT; current version stays active/schedulable.
--   (b) lp_version_activation — on activating the new version, the old one ends the day before it starts
--       (archived at once if already past); blocked while the old one has sessions on/after the new start.
--   (c) guard_training_session_program_link — program-selected session dates must fall inside the version.
-- Why:  Setup Mode turned OFF 16 Nov; on Live, "new version" still archived v1 immediately.
-- Date: 2026-11-16 · Approved by: Sandra Barlao ("ok" to release the version fix to Live)
-- Rollback: supabase/rollback/20261116110000_lp_p1_version_fix_release_ROLLBACK.sql (re-applies the gated 20261116100000 bodies)
-- Note: replace_learning_program is left in place (no longer called by the app).

-- (a) ──────────────────────────────────────────────────────────────────────────────────────────
create or replace function public.lp_start_new_version(p_old_id text, p_new_start date, p_copy_content boolean default true)
returns jsonb
language plpgsql
set search_path to 'public'
as $function$
declare old_record public.learning_programs%rowtype; new_record public.learning_programs%rowtype; next_version text; copied_contributors jsonb;
begin
  perform pg_advisory_xact_lock(hashtext('learning_program_version_'||p_old_id));
  select * into old_record from public.learning_programs where id=p_old_id for update;
  if not found then raise exception 'Program not found'; end if;
  if old_record.status <> 'active' then raise exception 'Only an active version can have a new version.'; end if;
  if p_new_start is null or p_new_start <= old_record.effective_from then
    raise exception 'The new version must start after the current version started (%).', old_record.effective_from;
  end if;
  if exists(select 1 from public.learning_programs where supersedes_program_id=p_old_id) then
    raise exception 'A newer version already exists for this program. Open it from Version History.';
  end if;
  next_version := case when old_record.version ~* '^v[0-9]+$' then 'v'||((substring(old_record.version from 2)::integer)+1)::text else old_record.version||'.1' end;
  if coalesce(p_copy_content,true) then
    copied_contributors := coalesce((
      select jsonb_agg((c - 'endDate') || jsonb_build_object('id',gen_random_uuid()::text,'startDate',p_new_start::text,'endDate',null,'addedAt',now()::text) order by ord)
      from jsonb_array_elements(coalesce(old_record.contributors,'[]'::jsonb)) with ordinality t(c,ord)
      where nullif(c->>'endDate','') is null or (c->>'endDate')::date >= p_new_start),'[]'::jsonb);
    insert into public.learning_programs (code,title,category_id,delivery_type,version,status,effective_from,effective_to,description,contributors,components,l3_required,l3_notes,agenda,assessments,duration_hours,duration_minutes,evaluation_config,resource_url,checklist_template_id,delivery_parts,allowed_modalities,created_by,updated_by,program_family_id,supersedes_program_id,ownership,owner_department_id,audience_ids,prerequisite_program_ids,prerequisite_item_ids,learning_resources)
    values (old_record.code,old_record.title,old_record.category_id,old_record.delivery_type,next_version,'draft',p_new_start,null,old_record.description,copied_contributors,'[]'::jsonb,old_record.l3_required,old_record.l3_notes,old_record.agenda,old_record.assessments,old_record.duration_hours,old_record.duration_minutes,old_record.evaluation_config,old_record.resource_url,old_record.checklist_template_id,old_record.delivery_parts,old_record.allowed_modalities,auth.uid(),auth.uid(),coalesce(old_record.program_family_id,old_record.id),old_record.id,old_record.ownership,old_record.owner_department_id,old_record.audience_ids,old_record.prerequisite_program_ids,old_record.prerequisite_item_ids,old_record.learning_resources) returning * into new_record;
  else
    insert into public.learning_programs (code,title,category_id,delivery_type,version,status,effective_from,effective_to,description,contributors,components,l3_required,l3_notes,agenda,assessments,duration_hours,duration_minutes,evaluation_config,resource_url,checklist_template_id,created_by,updated_by,program_family_id,supersedes_program_id,ownership,owner_department_id,audience_ids,prerequisite_program_ids,prerequisite_item_ids,learning_resources)
    values (old_record.code,old_record.title,null,null,next_version,'draft',p_new_start,null,null,'[]'::jsonb,'[]'::jsonb,false,null,'[]'::jsonb,'[]'::jsonb,null,null,'{"l1":false,"l2":{"enabled":false},"l3":{"enabled":false,"items":[]},"l4":{"enabled":false,"items":[]}}'::jsonb,null,null,auth.uid(),auth.uid(),coalesce(old_record.program_family_id,old_record.id),old_record.id,old_record.ownership,old_record.owner_department_id,old_record.audience_ids,old_record.prerequisite_program_ids,old_record.prerequisite_item_ids,old_record.learning_resources) returning * into new_record;
  end if;
  return jsonb_build_object('old',to_jsonb(old_record),'new',to_jsonb(new_record));
end $function$;

revoke all on function public.lp_start_new_version(text, date, boolean) from public, anon;
grant execute on function public.lp_start_new_version(text, date, boolean) to authenticated;

-- (b) ──────────────────────────────────────────────────────────────────────────────────────────
create or replace function public.lp_version_activation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $function$
declare pred public.learning_programs%rowtype; n int; today date := (now() at time zone 'Asia/Manila')::date;
begin
  if not (old.status = 'draft' and new.status = 'active' and new.supersedes_program_id is not null) then return new; end if;
  select * into pred from public.learning_programs where id = new.supersedes_program_id for update;
  if not found or pred.status <> 'active' then return new; end if;   -- older version already closed (old flow)
  if new.effective_from is null or new.effective_from <= pred.effective_from then
    raise exception 'The new version must start after % % started (%).', pred.code, pred.version, pred.effective_from;
  end if;
  select count(*) into n from public.training_sessions s
   where s.program_id = pred.id and coalesce(s.status,'') <> 'cancelled' and s.training_date >= new.effective_from;
  if n > 0 then
    raise exception '% % still has % session(s) dated on or after %. Move them, or choose a later start date for %.',
      pred.code, pred.version, n, new.effective_from, new.version;
  end if;
  update public.learning_programs
     set effective_to = new.effective_from - 1,
         retirement_reason = 'replaced',
         status = case when new.effective_from <= today then 'inactive' else status end,
         updated_at = now(), updated_by = auth.uid()
   where id = pred.id;
  return new;
end;
$function$;

revoke all on function public.lp_version_activation() from public, anon, authenticated;

drop trigger if exists trg_lp_version_activation on public.learning_programs;
create trigger trg_lp_version_activation
  before update of status on public.learning_programs
  for each row execute function public.lp_version_activation();

-- (c) ──────────────────────────────────────────────────────────────────────────────────────────
create or replace function public.guard_training_session_program_link()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare fits boolean;
begin
  if tg_op = 'INSERT' and new.program_id is not null then
    if new.program_link_origin = 'program_selection'
       and exists (
         select 1 from public.learning_programs p
         where p.id = new.program_id and p.status = 'active'
           and (
             (new.delivery_type = 'ILT' and p.delivery_type in ('ILT','ILT/VILT','Blended'))
             or (new.delivery_type = 'VILT' and p.delivery_type = 'VILT')
             or (new.delivery_type = 'Self-led' and p.delivery_type in ('SLT','Self-led'))
           )
       ) then
      null;  -- allowed; date check below
    elsif not public.is_admin() then
      raise exception 'Only an administrator may add a catalogue mapping' using errcode = '42501';
    end if;
  elsif tg_op = 'UPDATE' and (
      old.program_id is distinct from new.program_id
      or old.program_link_origin is distinct from new.program_link_origin
      or old.program_linked_at is distinct from new.program_linked_at
    ) then
    if not public.is_admin() then
      raise exception 'Only an administrator may change an existing session program link' using errcode = '42501';
    end if;
  end if;

  -- v1 fix (2026-11-16, released live 2026-11-16): a program-selected session's date must sit inside its version's dates.
  if new.program_id is not null and new.program_link_origin = 'program_selection'
     and new.training_date is not null
     and (tg_op = 'INSERT' or new.training_date is distinct from old.training_date or new.program_id is distinct from old.program_id) then
    select (new.training_date >= p.effective_from and (p.effective_to is null or new.training_date <= p.effective_to))
      into fits from public.learning_programs p where p.id = new.program_id;
    if fits is false then
      raise exception 'This date is outside the dates of the program version linked to this session. Use the version that covers this date.'
        using errcode = '23514';
    end if;
  end if;
  return new;
end;
$$;

insert into supabase_migrations.schema_migrations (version, name)
  values ('20261116110000', 'lp_p1_version_fix_release') on conflict do nothing;
