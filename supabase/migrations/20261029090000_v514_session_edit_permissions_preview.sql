-- v5.14 — Session + attendance edit permissions (PREVIEW-GATED)
-- What:  Only the session's trainer, co-facilitator, creator, anyone above them in the reporting
--        line (profiles.supervisor_id, any depth), or an admin can insert/update/delete a training
--        session or its participant (attendance) rows. Reading stays open to all signed-in users.
-- Why:   Today any signed-in user can change or delete any session through the database
--        (2026-10-29 platform test). Audit Log check (last 90 days): 210 of 211 session edits were by
--        the trainer/co-facilitator, creator or an admin.
-- Gate:  The new rule applies ONLY to requests from the preview site (header x-app-channel: preview).
--        Live behaves exactly as before. At release, remove `not public.is_preview_request() or`.
-- Date:  2026-10-29 · Asked by: Sandra Barlao · Status: RELEASED 2026-10-29 (gate removed by 20261029120000_v514_session_edit_permissions_release)
-- Additive/idempotent: new helper functions; the two *_write policies are recreated with the gate.

create or replace function public.is_preview_request()
returns boolean language sql stable set search_path = public as $$
  select coalesce((nullif(current_setting('request.headers', true), '')::json ->> 'x-app-channel') = 'preview', false);
$$;

-- true when `target` reports (directly or indirectly) to the signed-in user
create or replace function public.is_in_my_downline(target uuid)
returns boolean language sql stable security definer set search_path = public as $$
  with recursive chain as (
    select p.id, p.supervisor_id, 1 as depth from public.profiles p where p.id = target
    union all
    select p.id, p.supervisor_id, c.depth + 1
    from public.profiles p join chain c on p.id = c.supervisor_id
    where c.depth < 20
  )
  select auth.uid() is not null and target is not null
     and exists (select 1 from chain where supervisor_id = auth.uid());
$$;

create or replace function public.can_edit_training_session(p_trainer uuid, p_co uuid, p_creator uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select auth.uid() is not null and (
       coalesce(public.is_admin(), false)
    or coalesce(auth.uid() = p_trainer, false)
    or coalesce(auth.uid() = p_co, false)
    or coalesce(auth.uid() = p_creator, false)
    or public.is_in_my_downline(p_trainer)
    or public.is_in_my_downline(p_co)
    or public.is_in_my_downline(p_creator)
  );
$$;

grant execute on function public.is_preview_request() to authenticated;
grant execute on function public.is_in_my_downline(uuid) to authenticated;
grant execute on function public.can_edit_training_session(uuid, uuid, uuid) to authenticated;

drop policy if exists sessions_write on public.training_sessions;
create policy sessions_write on public.training_sessions as permissive for all to public
  using ((auth.role() = 'authenticated') and (not public.is_preview_request()
         or public.can_edit_training_session(trainer_id, co_facilitator_id, created_by)))
  with check ((auth.role() = 'authenticated') and (not public.is_preview_request()
         or public.can_edit_training_session(trainer_id, co_facilitator_id, created_by)));

drop policy if exists session_participants_write on public.session_participants;
create policy session_participants_write on public.session_participants as permissive for all to public
  using ((auth.role() = 'authenticated') and (not public.is_preview_request() or exists (
          select 1 from public.training_sessions s where s.id = session_participants.session_id
          and public.can_edit_training_session(s.trainer_id, s.co_facilitator_id, s.created_by))))
  with check ((auth.role() = 'authenticated') and (not public.is_preview_request() or exists (
          select 1 from public.training_sessions s where s.id = session_participants.session_id
          and public.can_edit_training_session(s.trainer_id, s.co_facilitator_id, s.created_by))));
