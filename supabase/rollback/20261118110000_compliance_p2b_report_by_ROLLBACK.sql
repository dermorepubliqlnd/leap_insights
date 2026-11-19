-- ROLLBACK for 20261118110000_compliance_p2b_report_by
-- Restores the cycle guard from 20261118100000 (re-run that file's compliance_cycles_guard block) and removes the new columns.
drop trigger if exists trg_compliance_followup_log on public.compliance_cycles;
drop function if exists public.compliance_followup_log();
drop index if exists public.compliance_lines_one_group;
delete from public.compliance_lines where department_id is null;   -- cluster/supervisor lines cannot exist without the new column
alter table public.compliance_lines drop constraint if exists compliance_lines_has_group;
alter table public.compliance_lines drop constraint if exists compliance_lines_group_label_len;
alter table public.compliance_lines drop column if exists group_label;
alter table public.compliance_lines alter column department_id set not null;
alter table public.compliance_lines add constraint compliance_lines_cycle_id_department_id_key unique (cycle_id, department_id);
alter table public.compliance_cycles drop column if exists followup_done_by, drop column if exists followup_done_at, drop column if exists followup_note, drop column if exists report_by;
delete from supabase_migrations.schema_migrations where version = '20261118110000';
-- then: re-apply the compliance_cycles_guard() function from supabase/migrations/20261118100000_compliance_p2_cycles.sql
