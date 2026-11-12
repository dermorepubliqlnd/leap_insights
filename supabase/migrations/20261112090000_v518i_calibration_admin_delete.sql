-- v5.18i — QA Calibration: admins can delete a calibration in any status
-- What:  calib_ex_delete policy: creator may still delete only drafts; an admin may delete any calibration.
--        Child rows (subject, submissions, decisions, amendments) go with it through the existing ON DELETE CASCADE.
--        The app warns first when the calibration holds data (deletion is permanent) and records it in the Audit Log.
-- Why:   Sandra, 2026-11-12: "as admin can I be given rights to delete … with a note that if data is in it, it will
--        delete all permanently; if no data yet just confirm it's been deleted".
-- Safety: policy only; still gated by calib_channel_ok() (preview) like every other calibration write.
drop policy if exists calib_ex_delete on public.calibration_exercises;
create policy calib_ex_delete on public.calibration_exercises for delete to authenticated
  using (public.calib_channel_ok() and (coalesce(public.is_admin(), false) or (status = 'draft' and created_by = auth.uid())));
