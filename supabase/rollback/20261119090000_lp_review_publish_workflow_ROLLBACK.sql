-- ROLLBACK for 20261119090000_lp_review_publish_workflow
-- Removes the guards, RPCs and helpers. Columns are left in place (harmless; the live app ignores them).
-- To drop them too (only if nothing reads them):
--   alter table public.learning_programs drop constraint learning_programs_review_status_chk, drop constraint learning_programs_review_note_len,
--     drop column review_status, drop column review_submitted_at, drop column review_submitted_by, drop column review_note,
--     drop column review_decided_at, drop column review_decided_by, drop column review_self_approved;
--   alter table public.profiles drop column lp_approver;
drop trigger if exists trg_lp_req_review_lock on public.lp_requirements;
drop trigger if exists trg_lp_review_guard on public.learning_programs;
drop trigger if exists trg_profiles_lp_approver_guard on public.profiles;
drop function if exists public.lp_req_review_lock();
drop function if exists public.lp_review_guard();
drop function if exists public.lp_review_submit(text);
drop function if exists public.lp_review_withdraw(text);
drop function if exists public.lp_review_return(text, text);
drop function if exists public.lp_publish_issue(public.learning_programs);
drop function if exists public.lp_can_approve();
drop function if exists public.profiles_lp_approver_guard();
delete from supabase_migrations.schema_migrations where version = '20261119090000';
