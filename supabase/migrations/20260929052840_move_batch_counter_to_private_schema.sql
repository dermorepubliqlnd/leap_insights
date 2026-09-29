-- Migration 20260929052840_move_batch_counter_to_private_schema
-- Exported verbatim from supabase_migrations.schema_migrations (live project catvpurbyvsnijxpzwoh) on 2026-09-29.
-- Already applied to production. Do not re-run manually.


create schema if not exists private;

alter table public.training_batch_counters set schema private;

revoke all on table private.training_batch_counters from public, anon, authenticated;

create or replace function public.assign_training_session_batch(
  p_session_id text,
  p_program_id text,
  p_delivery_year integer
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_family text;
  v_existing text;
  v_created_by uuid;
  v_is_admin boolean := false;
  v_count integer := 0;
  v_max_seq integer := 0;
  v_last integer := 0;
  v_next integer;
  v_batch text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

  select coalesce(p.is_admin,false)
    into v_is_admin
  from public.profiles p
  where p.id = auth.uid();

  if p_delivery_year < 2000 or p_delivery_year > 2100 then
    raise exception 'Invalid delivery year.';
  end if;

  select lp.program_family_id
    into v_family
  from public.learning_programs lp
  where lp.id = p_program_id;

  if v_family is null then
    raise exception 'Learning Program not found or missing program family.';
  end if;

  select ts.batch_no, ts.created_by
    into v_existing, v_created_by
  from public.training_sessions ts
  where ts.id = p_session_id
    and ts.program_id = p_program_id
  for update;

  if not found then
    raise exception 'Training session not found or is not linked to the selected Learning Program.';
  end if;

  if v_created_by is distinct from auth.uid() and not v_is_admin then
    raise exception 'Only the session creator or an administrator can assign its initial batch code.';
  end if;

  if coalesce(trim(v_existing),'') <> '' then
    return v_existing;
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_family || ':' || p_delivery_year::text, 0)
  );

  select count(*)::integer,
         coalesce(max(
           case
             when ts.batch_no ~ ('^' || p_delivery_year::text || '-[0-9]+$')
             then split_part(ts.batch_no,'-',2)::integer
             else null
           end
         ),0)::integer
    into v_count, v_max_seq
  from public.training_sessions ts
  join public.learning_programs lp on lp.id = ts.program_id
  where lp.program_family_id = v_family
    and ts.id <> p_session_id
    and extract(year from coalesce(
      ts.training_date,
      ts.session_dates[1],
      (
        select min((j.value->>'date')::date)
        from jsonb_array_elements(coalesce(ts.delivery_part_dates,'[]'::jsonb)) j(value)
        where (j.value->>'date') ~ '^\d{4}-\d{2}-\d{2}$'
      )
    ))::integer = p_delivery_year;

  insert into private.training_batch_counters(program_family_id,delivery_year,last_sequence,updated_at)
  values (v_family,p_delivery_year,greatest(v_count,v_max_seq),now())
  on conflict (program_family_id,delivery_year)
  do update set
    last_sequence = greatest(private.training_batch_counters.last_sequence, excluded.last_sequence),
    updated_at = now()
  returning last_sequence into v_last;

  v_next := greatest(v_last,v_count,v_max_seq) + 1;
  v_batch := p_delivery_year::text || '-' || lpad(v_next::text,3,'0');

  update private.training_batch_counters
  set last_sequence=v_next, updated_at=now()
  where program_family_id=v_family and delivery_year=p_delivery_year;

  update public.training_sessions
  set batch_no=v_batch, updated_at=now()
  where id=p_session_id;

  return v_batch;
end;
$$;

revoke execute on function public.assign_training_session_batch(text,text,integer) from public, anon;
grant execute on function public.assign_training_session_batch(text,text,integer) to authenticated;
