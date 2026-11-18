-- 20261118120000_compliance_p2c_delete_planned_fix
-- What: Fix — deleting a PLANNED cycle that has groups failed, because the lines guard ran during the cascade
--       after the cycle row was already gone and treated "no cycle" as "not planned". Now a line may be removed
--       when its cycle no longer exists (cascade) or is still planned. Nothing else changes.
-- Why:  Found while testing v5.19y on Preview (18 Nov). Deleting planned cycles is admin-only (policy cc_delete).
-- Date: 2026-11-18 · Approved by: Sandra Barlao (part of the v5.19y Preview build)
-- Rollback: re-apply compliance_lines_guard() from supabase/migrations/20261118100000_compliance_p2_cycles.sql
create or replace function public.compliance_lines_guard()
returns trigger language plpgsql security definer set search_path = '' as $$
declare st text; found_cycle boolean;
begin
  select status, true into st, found_cycle from public.compliance_cycles where id = coalesce(new.cycle_id, old.cycle_id);
  if tg_op = 'DELETE' and found_cycle is null then return old; end if;          -- cycle is being deleted (cascade)
  if st is distinct from 'planned' then
    raise exception 'Groups and starting headcounts are locked once the cycle is open. Use Adjust headcount.' using errcode = '23514';
  end if;
  if tg_op = 'UPDATE' then new.id := old.id; new.cycle_id := old.cycle_id; end if;
  return coalesce(new, old);
end;
$$;
insert into supabase_migrations.schema_migrations (version, name) values ('20261118120000', 'compliance_p2c_delete_planned_fix') on conflict do nothing;
