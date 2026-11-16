-- ROLLBACK for 20261116090000_p1_2_p1_6_report_editors_admin_locks
-- Restores the exact policies that existed before (verified 16 Nov).
drop trigger if exists trg_training_reports_guard on public.training_reports;
drop function if exists public.training_reports_guard();

drop policy if exists training_reports_write on public.training_reports;
create policy training_reports_write on public.training_reports
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');
drop function if exists public.can_edit_training_report(text);

drop policy if exists checklist_templates_select on public.checklist_templates;
drop policy if exists checklist_templates_write on public.checklist_templates;
create policy checklist_templates_all on public.checklist_templates
  for all using (true) with check (true);

drop policy if exists l1_targets_write on public.l1_targets;
create policy l1_targets_write on public.l1_targets
  for all
  using ((auth.uid() is not null) and ((program_family_id is not null) or is_admin()))
  with check ((auth.uid() is not null) and ((program_family_id is not null) or is_admin()));

-- Column training_reports.updated_by is left in place (harmless, app ignores it). To remove:
-- alter table public.training_reports drop column if exists updated_by;
delete from supabase_migrations.schema_migrations where version = '20261116090000';
