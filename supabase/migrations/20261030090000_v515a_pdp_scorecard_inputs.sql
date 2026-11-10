-- v5.15a — Personal Development Plans (PDP) + quarterly scorecard inputs (EEI / LEI)
-- What:  Two NEW tables used only by the new My Performance page (live v5.14a never reads them):
--          pdp_items          one row per development activity a person plans/completes; counted on the
--                             scorecard once their supervisor (anyone above them) verifies it.
--          scorecard_inputs   quarter-end ratings entered by a manager (EEI, LEI for supervisors), 1–5.
--        Access follows the reporting line: you see/edit your own PDPs; anyone above you (or an admin)
--        can see them and is the only one who can verify. Scorecard inputs are read by the person and
--        their reporting line, written only by someone above the person (or an admin) — never by self.
-- Why:   v5.15 role scorecards (Sandra, 2026-10-30): PDP = 5% of every scorecard (1 verified/quarter);
--        EEI 5% + LEI 10% of the supervisor scorecard, entered at quarter end.
-- Date:  2026-10-30 · Asked by: Sandra Barlao · Status: PREVIEW (tables are new; nothing on live uses them)
-- Additive/idempotent. Reuses public.is_admin() and public.is_in_my_downline(uuid) (migration 20261029090000).

create table if not exists public.pdp_items (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  title text not null check (char_length(title) between 1 and 200),
  provider text check (provider in ('DermoU','External','On-the-job','Other')),
  quarter text not null check (quarter ~ '^[0-9]{4}-Q[1-4]$'),
  target_date date,
  status text not null default 'planned' check (status in ('planned','ongoing','submitted','verified','returned')),
  completed_on date,
  proof_url text,
  notes text,
  return_reason text,
  verified_by uuid references public.profiles(id),
  verified_at timestamptz,
  created_by uuid default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists pdp_items_profile_quarter_idx on public.pdp_items(profile_id, quarter);

create table if not exists public.scorecard_inputs (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  kpi_code text not null check (kpi_code in ('EEI','LEI')),
  quarter text not null check (quarter ~ '^[0-9]{4}-Q[1-4]$'),
  value numeric not null check (value >= 1 and value <= 5),
  notes text,
  entered_by uuid default auth.uid(),
  entered_at timestamptz not null default now(),
  unique (profile_id, kpi_code, quarter)
);

-- Verification guard: only someone above the person (or an admin) may verify / return a PDP, and the
-- owner can't edit an item after it is verified (admins can).
create or replace function public.pdp_items_guard()
returns trigger language plpgsql security definer set search_path = public as $$
declare can_verify boolean := coalesce(public.is_admin(), false) or public.is_in_my_downline(new.profile_id);
begin
  new.updated_at := now();
  if tg_op = 'UPDATE' and old.status = 'verified' and not coalesce(public.is_admin(), false) then
    raise exception 'This PDP is already verified. Ask an admin to change it.';
  end if;
  if new.status in ('verified','returned') and (tg_op = 'INSERT' or old.status is distinct from new.status) then
    if not can_verify then raise exception 'Only your supervisor can verify or return a PDP.'; end if;
    if new.status = 'verified' then new.verified_by := auth.uid(); new.verified_at := now(); end if;
  end if;
  if new.status <> 'verified' then new.verified_by := null; new.verified_at := null; end if;
  return new;
end $$;
drop trigger if exists pdp_items_guard on public.pdp_items;
create trigger pdp_items_guard before insert or update on public.pdp_items
  for each row execute function public.pdp_items_guard();

alter table public.pdp_items enable row level security;
alter table public.scorecard_inputs enable row level security;

drop policy if exists pdp_select on public.pdp_items;
create policy pdp_select on public.pdp_items for select to authenticated
  using (profile_id = auth.uid() or public.is_in_my_downline(profile_id) or coalesce(public.is_admin(), false));
drop policy if exists pdp_insert on public.pdp_items;
create policy pdp_insert on public.pdp_items for insert to authenticated
  with check (profile_id = auth.uid() or public.is_in_my_downline(profile_id) or coalesce(public.is_admin(), false));
drop policy if exists pdp_update on public.pdp_items;
create policy pdp_update on public.pdp_items for update to authenticated
  using (profile_id = auth.uid() or public.is_in_my_downline(profile_id) or coalesce(public.is_admin(), false))
  with check (profile_id = auth.uid() or public.is_in_my_downline(profile_id) or coalesce(public.is_admin(), false));
drop policy if exists pdp_delete on public.pdp_items;
create policy pdp_delete on public.pdp_items for delete to authenticated
  using ((profile_id = auth.uid() and status <> 'verified') or coalesce(public.is_admin(), false));

drop policy if exists sci_select on public.scorecard_inputs;
create policy sci_select on public.scorecard_inputs for select to authenticated
  using (profile_id = auth.uid() or public.is_in_my_downline(profile_id) or coalesce(public.is_admin(), false));
drop policy if exists sci_write on public.scorecard_inputs;
create policy sci_write on public.scorecard_inputs for all to authenticated
  using (public.is_in_my_downline(profile_id) or coalesce(public.is_admin(), false))
  with check (public.is_in_my_downline(profile_id) or coalesce(public.is_admin(), false));

grant select, insert, update, delete on public.pdp_items to authenticated;
grant select, insert, update, delete on public.scorecard_inputs to authenticated;
