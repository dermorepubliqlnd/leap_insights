-- Migration 20260929052638_phase1_workflow_and_security_hardening
-- Exported verbatim from supabase_migrations.schema_migrations (live project catvpurbyvsnijxpzwoh) on 2026-09-29.
-- Already applied to production. Do not re-run manually.


-- 1) Persistent, atomic batch counter keyed by Learning Program family + delivery year.
create table if not exists public.training_batch_counters (
  program_family_id text not null,
  delivery_year integer not null check (delivery_year between 2000 and 2100),
  last_sequence integer not null default 0 check (last_sequence >= 0),
  updated_at timestamptz not null default now(),
  primary key (program_family_id, delivery_year)
);

alter table public.training_batch_counters enable row level security;

revoke all on table public.training_batch_counters from anon, authenticated;
grant select on table public.training_batch_counters to authenticated;

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
  v_count integer := 0;
  v_max_seq integer := 0;
  v_last integer := 0;
  v_next integer;
  v_batch text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required.';
  end if;

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

  select ts.batch_no
    into v_existing
  from public.training_sessions ts
  where ts.id = p_session_id
    and ts.program_id = p_program_id
  for update;

  if not found then
    raise exception 'Training session not found or is not linked to the selected Learning Program.';
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

  insert into public.training_batch_counters(program_family_id,delivery_year,last_sequence,updated_at)
  values (v_family,p_delivery_year,greatest(v_count,v_max_seq),now())
  on conflict (program_family_id,delivery_year)
  do update set
    last_sequence = greatest(
      public.training_batch_counters.last_sequence,
      excluded.last_sequence
    ),
    updated_at = now()
  returning last_sequence into v_last;

  v_next := greatest(v_last,v_count,v_max_seq) + 1;
  v_batch := p_delivery_year::text || '-' || lpad(v_next::text,3,'0');

  update public.training_batch_counters
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

comment on function public.assign_training_session_batch(text,text,integer) is
'Atomically assigns YYYY-### batch codes per Learning Program family and delivery year. Historical mapped implementation count establishes the initial baseline; the persistent counter prevents reuse after later deletion.';

-- 2) Training Reports cannot be submitted/approved before non-self-led delivery is complete.
create or replace function public.guard_training_report_submission()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status text;
  v_delivery_type text;
begin
  if new.status in ('submitted','approved') then
    select ts.status, ts.delivery_type
      into v_status, v_delivery_type
    from public.training_sessions ts
    where ts.id = new.session_id;

    if not found then
      raise exception 'Training session not found.';
    end if;

    if coalesce(v_delivery_type,'') <> 'Self-led'
       and v_status <> 'completed' then
      raise exception 'Training Report cannot be submitted before Delivery Complete.';
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_training_report_requires_delivery_complete on public.training_reports;
create trigger trg_training_report_requires_delivery_complete
before insert or update of status, session_id
on public.training_reports
for each row
execute function public.guard_training_report_submission();

revoke execute on function public.guard_training_report_submission() from public, anon, authenticated;

comment on function public.guard_training_report_submission() is
'Database guard: submitted/approved reports for non-self-led sessions require training_sessions.status=completed (Delivery Complete).';

-- 3) Fix mutable search_path warnings on authorization helpers.
create or replace function public.is_admin()
returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce((select p.is_admin from public.profiles p where p.id = auth.uid()), false);
$$;

create or replace function public.is_reports_viewer()
returns boolean
language sql
stable
set search_path = ''
as $$
  select coalesce((select p.is_reports_viewer from public.profiles p where p.id = auth.uid()), false);
$$;

-- 4) Event-trigger helper is internal infrastructure; it should not be API-callable.
revoke execute on function public.rls_auto_enable() from public, anon, authenticated;
