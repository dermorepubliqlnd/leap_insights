-- 20261119090000_lp_review_publish_workflow
-- What (PREVIEW-GATED rules): Learning Program "Submit for Review → Approve & Publish" workflow (Assessment 06, Revision 1).
--   (a) profiles.lp_approver: "Program approver" switch. Only an admin can change it (always enforced: it is a new
--       column, so nobody relies on changing it). Turned on for Sandra (admin) and Joseph.
--   (b) lp_can_approve(): active admin or active program approver.
--   (c) learning_programs review fields: review_status (pending | returned | approved), review_submitted_at/_by,
--       review_note, review_decided_at/_by, review_self_approved.
--   (d) lp_publish_issue(row): the database's own publish check (first problem or NULL): title, category, delivery
--       type, description, program folder, ownership (+ department), a Main contributor, agenda, and for new programs
--       created from 18 Nov the Target Audience and "Required?". The full check still runs in the app.
--   (e) RPCs: lp_review_submit(id) (any author; check must pass), lp_review_withdraw(id) (submitter or admin),
--       lp_review_return(id, note) (approver; note required).
--   (f) Guard on learning_programs (preview): only an approver can publish (draft → active), and a new row cannot
--       start as active; a draft In Review cannot be edited; review fields change only through the RPCs or publishing.
--       Publishing stamps review_status 'approved', who and when (self-approved if it was not submitted).
--   (g) The compliance rule of a program family is locked while a draft of that family is In Review.
--   Live is not affected (gated by is_preview_request()), except (a)'s admin-only switch.
-- Why:  Sandra 18 Nov: "everyone submits for review, publish only shows to approvers"; approver switch for her and
--       Joseph (F1); approver cannot edit a pending draft (F8); Return with note, no Reject (F7); own drafts publish
--       directly = self-approved (F3); minor revisions and existing programs not affected (F6, F10); no notifications (F12).
-- Date: 2026-11-19 · Approved by: Sandra Barlao ("create a publish workflow", "Approver switch", "Both together")
-- Rollback: supabase/rollback/20261119090000_lp_review_publish_workflow_ROLLBACK.sql
-- Release: remove the is_preview_request() checks in lp_review_guard and lp_req_review_lock.

-- (a) ───────────────────────────────────────────────────────────────────────
alter table public.profiles add column if not exists lp_approver boolean not null default false;

create or replace function public.profiles_lp_approver_guard()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.lp_approver is distinct from old.lp_approver and auth.uid() is not null and not public.is_admin() then
    raise exception 'Only an admin can change who approves Learning Programs.' using errcode = '42501';
  end if;
  return new;
end;
$$;
revoke all on function public.profiles_lp_approver_guard() from public, anon, authenticated;
drop trigger if exists trg_profiles_lp_approver_guard on public.profiles;
create trigger trg_profiles_lp_approver_guard before update of lp_approver on public.profiles
  for each row execute function public.profiles_lp_approver_guard();

update public.profiles set lp_approver = true
 where not lp_approver and is_active and (is_admin or first_name ilike 'joseph%');

-- (b) ───────────────────────────────────────────────────────────────────────
create or replace function public.lp_can_approve()
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce((select p.is_active and (p.is_admin or p.lp_approver) from public.profiles p where p.id = auth.uid()), false);
$$;
revoke all on function public.lp_can_approve() from public, anon;
grant execute on function public.lp_can_approve() to authenticated;

-- (c) ───────────────────────────────────────────────────────────────────────
alter table public.learning_programs
  add column if not exists review_status        text,
  add column if not exists review_submitted_at  timestamptz,
  add column if not exists review_submitted_by  uuid,
  add column if not exists review_note          text,
  add column if not exists review_decided_at    timestamptz,
  add column if not exists review_decided_by    uuid,
  add column if not exists review_self_approved boolean not null default false;
alter table public.learning_programs drop constraint if exists learning_programs_review_status_chk;
alter table public.learning_programs add constraint learning_programs_review_status_chk
  check (review_status is null or review_status in ('pending','returned','approved'));
alter table public.learning_programs drop constraint if exists learning_programs_review_note_len;
alter table public.learning_programs add constraint learning_programs_review_note_len
  check (review_note is null or char_length(review_note) <= 1000);

-- (d) ───────────────────────────────────────────────────────────────────────
create or replace function public.lp_publish_issue(p public.learning_programs)
returns text language plpgsql stable security definer set search_path = '' as $$
declare created date := (p.created_at at time zone 'Asia/Manila')::date;
begin
  if nullif(btrim(coalesce(p.title,'')),'') is null then return 'Program Title is required.'; end if;
  if nullif(btrim(coalesce(p.category_id,'')),'') is null then return 'Category is required.'; end if;
  if nullif(btrim(coalesce(p.delivery_type,'')),'') is null then return 'Delivery Type is required.'; end if;
  if nullif(btrim(coalesce(p.description,'')),'') is null then return 'Program Description is required.'; end if;
  if nullif(btrim(coalesce(p.resource_url,'')),'') is null then return 'Program Folder link is required.'; end if;
  if p.ownership is null and created >= date '2026-10-14' then return 'Program Ownership is required.'; end if;
  if p.ownership = 'non_ld' and p.owner_department_id is null then return 'The owning department is required for a Non-L&D program.'; end if;
  if not exists (select 1 from jsonb_array_elements(coalesce(p.contributors,'[]'::jsonb)) c where coalesce((c->>'primary')::boolean,false)) then
    return 'Mark a Main contributor.'; end if;
  if jsonb_typeof(p.agenda) is distinct from 'array' or jsonb_array_length(p.agenda) = 0 then return 'Add the curriculum / agenda.'; end if;
  if p.supersedes_program_id is null and created >= date '2026-11-18' then
    if p.audience_all_levels is null or p.audience_all_departments is null
       or (not p.audience_all_levels and cardinality(p.audience_level_ids) = 0)
       or (not p.audience_all_departments and cardinality(p.audience_department_ids) = 0) then
      return 'Set the Target Audience (levels and departments).'; end if;
    if not exists (select 1 from public.lp_requirements r where r.program_family_id = coalesce(p.program_family_id, p.id)) then
      return 'Answer "Required?" in the Compliance Requirement section.'; end if;
  end if;
  return null;
end;
$$;
revoke all on function public.lp_publish_issue(public.learning_programs) from public, anon;
grant execute on function public.lp_publish_issue(public.learning_programs) to authenticated;

-- (e) ───────────────────────────────────────────────────────────────────────
create or replace function public.lp_review_submit(p_id text)
returns public.learning_programs language plpgsql security definer set search_path = '' as $$
declare p public.learning_programs; issue text;
begin
  if auth.uid() is null then raise exception 'Sign in first.' using errcode = '42501'; end if;
  select * into p from public.learning_programs where id = p_id for update;
  if not found then raise exception 'Program not found.'; end if;
  if p.status <> 'draft' then raise exception 'Only a draft can be submitted for review.' using errcode = '23514'; end if;
  if p.review_status = 'pending' then raise exception 'This draft is already in review.' using errcode = '23514'; end if;
  issue := public.lp_publish_issue(p);
  if issue is not null then raise exception 'Not ready for review: %', issue using errcode = '23514'; end if;
  perform set_config('leap.lp_review', '1', true);
  update public.learning_programs
     set review_status = 'pending', review_submitted_at = now(), review_submitted_by = auth.uid(),
         review_note = null, review_decided_at = null, review_decided_by = null, review_self_approved = false
   where id = p_id returning * into p;
  perform set_config('leap.lp_review', '', true);
  return p;
end;
$$;
create or replace function public.lp_review_withdraw(p_id text)
returns public.learning_programs language plpgsql security definer set search_path = '' as $$
declare p public.learning_programs;
begin
  select * into p from public.learning_programs where id = p_id for update;
  if not found then raise exception 'Program not found.'; end if;
  if p.status <> 'draft' or p.review_status is distinct from 'pending' then raise exception 'This draft is not in review.' using errcode = '23514'; end if;
  if auth.uid() is distinct from p.review_submitted_by and not public.is_admin() then
    raise exception 'Only the person who submitted it, or an admin, can withdraw it.' using errcode = '42501'; end if;
  perform set_config('leap.lp_review', '1', true);
  update public.learning_programs set review_status = null, review_submitted_at = null, review_submitted_by = null
   where id = p_id returning * into p;
  perform set_config('leap.lp_review', '', true);
  return p;
end;
$$;
create or replace function public.lp_review_return(p_id text, p_note text)
returns public.learning_programs language plpgsql security definer set search_path = '' as $$
declare p public.learning_programs;
begin
  if not public.lp_can_approve() then raise exception 'Only a program approver can return a draft.' using errcode = '42501'; end if;
  if nullif(btrim(coalesce(p_note,'')),'') is null then raise exception 'Add a note saying what needs to change.' using errcode = '23514'; end if;
  select * into p from public.learning_programs where id = p_id for update;
  if not found then raise exception 'Program not found.'; end if;
  if p.status <> 'draft' or p.review_status is distinct from 'pending' then raise exception 'This draft is not in review.' using errcode = '23514'; end if;
  perform set_config('leap.lp_review', '1', true);
  update public.learning_programs
     set review_status = 'returned', review_note = left(btrim(p_note), 1000), review_decided_at = now(), review_decided_by = auth.uid()
   where id = p_id returning * into p;
  perform set_config('leap.lp_review', '', true);
  return p;
end;
$$;
revoke all on function public.lp_review_submit(text) from public, anon;
revoke all on function public.lp_review_withdraw(text) from public, anon;
revoke all on function public.lp_review_return(text, text) from public, anon;
grant execute on function public.lp_review_submit(text) to authenticated;
grant execute on function public.lp_review_withdraw(text) to authenticated;
grant execute on function public.lp_review_return(text, text) to authenticated;

-- (f) ───────────────────────────────────────────────────────────────────────
create or replace function public.lp_review_guard()
returns trigger language plpgsql security definer set search_path = '' as $$
declare issue text; strip text[] := array['updated_at','updated_by'];
begin
  if coalesce(current_setting('leap.lp_review', true), '') = '1' then return new; end if;   -- RPC path
  if auth.uid() is null or not public.is_preview_request() then return new; end if;        -- SQL editor / live
  if tg_op = 'INSERT' then
    if new.status <> 'draft' and not public.lp_can_approve() then
      raise exception 'A new program starts as a draft and is published by an approver.' using errcode = '42501';
    end if;
    new.review_status := null; new.review_submitted_at := null; new.review_submitted_by := null; new.review_note := null;
    new.review_decided_at := null; new.review_decided_by := null; new.review_self_approved := false;
    return new;
  end if;
  if old.status = 'draft' and new.status = 'active' then                                    -- publishing
    if not public.lp_can_approve() then
      raise exception 'Submit this program for review. A program approver publishes it.' using errcode = '42501';
    end if;
    issue := public.lp_publish_issue(new);
    if issue is not null then raise exception 'Not ready to publish: %', issue using errcode = '23514'; end if;
    new.review_self_approved := old.review_status is distinct from 'pending';
    new.review_status := 'approved'; new.review_decided_at := now(); new.review_decided_by := auth.uid();
    new.review_note := null;
    return new;
  end if;
  if row(new.review_status, new.review_submitted_at, new.review_submitted_by, new.review_note, new.review_decided_at, new.review_decided_by, new.review_self_approved)
     is distinct from
     row(old.review_status, old.review_submitted_at, old.review_submitted_by, old.review_note, old.review_decided_at, old.review_decided_by, old.review_self_approved) then
    raise exception 'Review status changes only through Submit, Withdraw, Return or Publish.' using errcode = '42501';
  end if;
  if old.status = 'draft' and old.review_status = 'pending' and (to_jsonb(new) - strip) <> (to_jsonb(old) - strip) then
    raise exception 'This program is in review and cannot be edited. Withdraw it first, or ask the approver to return it.' using errcode = '23514';
  end if;
  return new;
end;
$$;
revoke all on function public.lp_review_guard() from public, anon, authenticated;
drop trigger if exists trg_lp_review_guard on public.learning_programs;
create trigger trg_lp_review_guard before insert or update on public.learning_programs
  for each row execute function public.lp_review_guard();

-- (g) ───────────────────────────────────────────────────────────────────────
create or replace function public.lp_req_review_lock()
returns trigger language plpgsql security definer set search_path = '' as $$
declare fam text := coalesce(new.program_family_id, old.program_family_id);
begin
  if coalesce(current_setting('leap.lp_req_approve', true), '') = '1' then return coalesce(new, old); end if;
  if auth.uid() is null or not public.is_preview_request() then return coalesce(new, old); end if;
  if exists (select 1 from public.learning_programs lp
              where coalesce(lp.program_family_id, lp.id) = fam and lp.status = 'draft' and lp.review_status = 'pending') then
    raise exception 'This program is in review, so its compliance requirement is locked. Withdraw it first, or ask the approver to return it.' using errcode = '23514';
  end if;
  return coalesce(new, old);
end;
$$;
revoke all on function public.lp_req_review_lock() from public, anon, authenticated;
drop trigger if exists trg_lp_req_review_lock on public.lp_requirements;
create trigger trg_lp_req_review_lock before insert or update or delete on public.lp_requirements
  for each row execute function public.lp_req_review_lock();

insert into supabase_migrations.schema_migrations (version, name) values ('20261119090000', 'lp_review_publish_workflow') on conflict do nothing;
