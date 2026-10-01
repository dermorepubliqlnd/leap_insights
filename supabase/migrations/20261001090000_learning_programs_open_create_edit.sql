-- v4.99: any authenticated user can create and edit Learning Programs.
-- Delete stays admin-only (learning_programs_delete unchanged).
-- Archived-version, used-content and version-identity triggers still apply.
drop policy if exists learning_programs_insert on public.learning_programs;
create policy learning_programs_insert on public.learning_programs
  as permissive for insert to authenticated
  with check (auth.uid() is not null);

drop policy if exists learning_programs_update on public.learning_programs;
create policy learning_programs_update on public.learning_programs
  as permissive for update to authenticated
  using (auth.uid() is not null)
  with check (auth.uid() is not null);
