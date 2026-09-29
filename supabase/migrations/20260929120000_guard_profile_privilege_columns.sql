-- Migration 20260929120000_guard_profile_privilege_columns
-- Exported verbatim from supabase_migrations.schema_migrations (live project catvpurbyvsnijxpzwoh) on 2026-09-29.
-- Already applied to production. Do not re-run manually.

create or replace function public.guard_profile_privileged_columns()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
begin
  if auth.uid() is null or public.is_admin() then
    return new;
  end if;
  if new.is_admin is distinct from old.is_admin
     or new.is_reports_viewer is distinct from old.is_reports_viewer
     or new.can_manage_facilitation_rates is distinct from old.can_manage_facilitation_rates
     or new.can_view_training_costs is distinct from old.can_view_training_costs
     or new.dash_scope is distinct from old.dash_scope
     or new.form_trainer is distinct from old.form_trainer
     or new.form_idqa is distinct from old.form_idqa
     or new.form_cqa is distinct from old.form_cqa
     or new.position_id is distinct from old.position_id
     or new.supervisor_id is distinct from old.supervisor_id
     or new.is_active is distinct from old.is_active
     or new.email is distinct from old.email
     or new.employee_id is distinct from old.employee_id
     or new.workload_allocation_pct is distinct from old.workload_allocation_pct
     or new.role_effective_date is distinct from old.role_effective_date
     or new.id is distinct from old.id
  then
    raise exception 'Only an administrator can change access, role, or reporting-line fields on a profile.'
      using errcode = '42501';
  end if;
  return new;
end;
$function$;

drop trigger if exists trg_guard_profile_privileged_columns on public.profiles;
create trigger trg_guard_profile_privileged_columns
  before update on public.profiles
  for each row execute function public.guard_profile_privileged_columns();
