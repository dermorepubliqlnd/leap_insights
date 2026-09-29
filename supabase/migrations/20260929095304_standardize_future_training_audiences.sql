-- Migration 20260929095304_standardize_future_training_audiences
-- Exported verbatim from supabase_migrations.schema_migrations (live project catvpurbyvsnijxpzwoh) on 2026-09-29.
-- Already applied to production. Do not re-run manually.


-- Keep historical training_sessions.audience arrays untouched.
-- Retire prior department/function-based audience options from future selection,
-- while preserving the rows for historical reference.
update public.audiences
set is_active = false
where name not in (
  'Individual Contributors',
  'Junior Leaders',
  'Supervisors / Team Leaders',
  'Managers',
  'Senior Leaders',
  'People Leaders',
  'All Employees'
);

-- Ensure the approved forward-looking audience taxonomy exists and is active.
insert into public.audiences (id,name,is_active)
values
  ('aud_individual_contributors','Individual Contributors',true),
  ('aud_junior_leaders','Junior Leaders',true),
  ('aud_supervisors_team_leaders','Supervisors / Team Leaders',true),
  ('aud_managers','Managers',true),
  ('aud_senior_leaders','Senior Leaders',true),
  ('aud_people_leaders','People Leaders',true),
  ('aud_all_employees','All Employees',true)
on conflict (id) do update
set name=excluded.name,
    is_active=true;

-- Existing rows with the same name but different legacy ids remain preserved;
-- make sure any such existing approved-name rows are active too.
update public.audiences
set is_active=true
where name in (
  'Individual Contributors',
  'Junior Leaders',
  'Supervisors / Team Leaders',
  'Managers',
  'Senior Leaders',
  'People Leaders',
  'All Employees'
);
