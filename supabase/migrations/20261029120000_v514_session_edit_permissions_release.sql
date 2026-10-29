-- v5.14 RELEASE — Session + attendance edit permissions for everyone (removes the preview-only gate)
-- What:  Same rule as 20261029090000_v514_session_edit_permissions_preview, now applied to live too:
--        only the session's trainer, co-facilitator, creator, anyone above them in the reporting line,
--        or an admin can insert/update/delete a training session or its participant (attendance) rows.
--        Reading is unchanged (all signed-in users). Helper functions from 20261029090000 are reused.
-- Why:   Approved by Sandra after preview testing ("push those changes to live", 2026-10-29).
-- Date:  2026-10-29 · Asked by: Sandra Barlao · Status: RELEASED 2026-10-29

drop policy if exists sessions_write on public.training_sessions;
create policy sessions_write on public.training_sessions as permissive for all to public
  using ((auth.role() = 'authenticated') and public.can_edit_training_session(trainer_id, co_facilitator_id, created_by))
  with check ((auth.role() = 'authenticated') and public.can_edit_training_session(trainer_id, co_facilitator_id, created_by));

drop policy if exists session_participants_write on public.session_participants;
create policy session_participants_write on public.session_participants as permissive for all to public
  using ((auth.role() = 'authenticated') and exists (
          select 1 from public.training_sessions s where s.id = session_participants.session_id
          and public.can_edit_training_session(s.trainer_id, s.co_facilitator_id, s.created_by)))
  with check ((auth.role() = 'authenticated') and exists (
          select 1 from public.training_sessions s where s.id = session_participants.session_id
          and public.can_edit_training_session(s.trainer_id, s.co_facilitator_id, s.created_by)));
