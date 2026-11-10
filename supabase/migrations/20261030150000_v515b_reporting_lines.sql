-- v5.15b — Dated reporting lines (who reported to whom, from when)
-- What:  New table public.reporting_lines (profile, supervisor, effective_from, effective_to).
--        Seeded from today's profiles.supervisor_id (start = hire date). A trigger on profiles records
--        every future supervisor change automatically (effective today, Manila time). Admins can backdate
--        the latest change with public.set_reporting_line_effective(profile, date).
--        Data change approved by Sandra (2026-10-30, "go"): trainers Fritzie Dipon and Rhenmart Neil Dela Cruz
--        now report to Sandra Barlao, effective 2026-10-01 (Joseph San Jose until 2026-09-30).
-- Why:   Team Performance and supervisor roll-ups must use the reporting line that applied in each
--        period, so a transfer never rewrites a past quarter.
-- Date:  2026-10-30 · Asked by: Sandra Barlao · Status: APPLIED LIVE 2026-10-30 (additive; live v5.14a ignores the table;
--        the supervisor change itself affects live: trainers' reopen requests / exemptions now route to Sandra — approved)
-- Additive/idempotent.

create table if not exists public.reporting_lines (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  supervisor_id uuid references public.profiles(id) on delete set null,
  effective_from date not null,
  effective_to date,
  notes text,
  created_by uuid,
  created_at timestamptz not null default now(),
  constraint reporting_lines_dates_check check (effective_to is null or effective_to >= effective_from),
  constraint reporting_lines_unique_start unique (profile_id, effective_from)
);
create index if not exists reporting_lines_profile_idx on public.reporting_lines(profile_id, effective_from);

alter table public.reporting_lines enable row level security;
drop policy if exists reporting_lines_read on public.reporting_lines;
create policy reporting_lines_read on public.reporting_lines for select to authenticated using (true);
-- no write policies: rows are written only by the trigger / admin function below (security definer)

-- 1) Trainers → Sandra, effective 2026-10-01 (history rows first, then the profile)
do $$
declare
  v_sandra uuid := '025a9ffb-2de4-4242-b157-24d29a811374';
  v_joseph uuid := '138ed6dc-976b-483b-b113-1115fb3f4a2b';
  v_id uuid;
begin
  foreach v_id in array array['29a61d59-100b-4268-bf73-e622e3f78937'::uuid, '7d47f3c9-ebef-4321-b4ca-af481bbbf632'::uuid] loop
    if not exists (select 1 from public.reporting_lines where profile_id = v_id) then
      insert into public.reporting_lines (profile_id, supervisor_id, effective_from, effective_to, notes)
        select v_id, v_joseph, coalesce(hire_date, date '2024-01-01'), date '2026-09-30', 'Seeded (v5.15b): reported to Joseph San Jose'
        from public.profiles where id = v_id;
      insert into public.reporting_lines (profile_id, supervisor_id, effective_from, notes)
        values (v_id, v_sandra, date '2026-10-01', 'Transfer to Sandra Barlao, effective 2026-10-01 (per Sandra, 2026-10-30)');
    end if;
    if exists (select 1 from public.profiles where id = v_id and supervisor_id is distinct from v_sandra) then
      drop trigger if exists profiles_reporting_line_sync on public.profiles;
      update public.profiles set supervisor_id = v_sandra where id = v_id;
      insert into public.audit_log (ts, actor_id, action, module, entity_id, summary)
        select now(), v_sandra, 'update', 'User', v_id::text,
               first_name || ' ' || last_name || ': supervisor changed from Joseph Kier San Jose to Sandra Abegail Barlao, effective 2026-10-01 (v5.15b)'
        from public.profiles where id = v_id;
    end if;
  end loop;
end $$;

-- 2) Seed everyone else from today's reporting line
insert into public.reporting_lines (profile_id, supervisor_id, effective_from, notes)
select p.id, p.supervisor_id, coalesce(p.hire_date, date '2024-01-01'), 'Seeded from profiles (v5.15b)'
from public.profiles p
where not exists (select 1 from public.reporting_lines r where r.profile_id = p.id);

-- 3) Record future supervisor changes automatically
create or replace function public.profiles_reporting_line_sync()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  d date := (now() at time zone 'Asia/Manila')::date;
  cur public.reporting_lines%rowtype;
begin
  if tg_op = 'UPDATE' and new.supervisor_id is not distinct from old.supervisor_id then return new; end if;
  select * into cur from public.reporting_lines where profile_id = new.id and effective_to is null
    order by effective_from desc limit 1;
  if cur.id is not null and cur.effective_from >= d then
    update public.reporting_lines set supervisor_id = new.supervisor_id where id = cur.id;
  else
    if cur.id is not null then update public.reporting_lines set effective_to = d - 1 where id = cur.id; end if;
    insert into public.reporting_lines (profile_id, supervisor_id, effective_from, created_by)
      values (new.id, new.supervisor_id, case when tg_op = 'INSERT' then coalesce(new.hire_date, d) else d end, auth.uid());
  end if;
  return new;
end $$;
drop trigger if exists profiles_reporting_line_sync on public.profiles;
create trigger profiles_reporting_line_sync after insert or update of supervisor_id on public.profiles
  for each row execute function public.profiles_reporting_line_sync();

-- 4) Admin: backdate (or correct) the start date of someone's current reporting line
create or replace function public.set_reporting_line_effective(p_profile uuid, p_from date)
returns void language plpgsql security definer set search_path = public as $$
declare
  cur public.reporting_lines%rowtype;
  prev public.reporting_lines%rowtype;
begin
  if not public.is_admin() then raise exception 'Only admins can change reporting-line dates'; end if;
  if p_from is null or p_from > (now() at time zone 'Asia/Manila')::date then raise exception 'Effective date cannot be in the future'; end if;
  select * into cur from public.reporting_lines where profile_id = p_profile and effective_to is null order by effective_from desc limit 1;
  if cur.id is null then raise exception 'No current reporting line for this person'; end if;
  select * into prev from public.reporting_lines where profile_id = p_profile and id <> cur.id order by effective_from desc limit 1;
  if prev.id is not null and p_from <= prev.effective_from then
    raise exception 'Effective date must be after %', prev.effective_from;
  end if;
  update public.reporting_lines set effective_from = p_from where id = cur.id;
  if prev.id is not null then update public.reporting_lines set effective_to = p_from - 1 where id = prev.id; end if;
end $$;
revoke all on function public.set_reporting_line_effective(uuid, date) from public;
grant execute on function public.set_reporting_line_effective(uuid, date) to authenticated;
