-- v5.20c RELEASE (2026-11-23, per Sandra: "please apply to live") — PDP Start Date + backdating rules for everyone
-- What:  pdp_items_guard: the v5.20c gate `strict_ := coalesce(public.is_preview_request(), false)` becomes `strict_ := true`
--        (start date required on new PDPs, floor Oct 1 2026, target/completion on or after start,
--         backdated start -> approval goes straight to Ongoing). Function body otherwise unchanged.
-- Why:   live app (root index.html commit 549f6c7) now has the Start Date field.
-- Safety: re-creates one function from its own installed definition; no data change.
-- Rollback: re-run 20261123090000_v520c_pdp_start_date_backdate.sql (gated version).
-- RELEASED 2026-11-23

do $r$
declare d text;
begin
  d := pg_get_functiondef('public.pdp_items_guard()'::regprocedure);
  if position('strict_ boolean := coalesce(public.is_preview_request(), false);' in d) = 0 then
    raise exception 'v5.20c gate not found in pdp_items_guard';
  end if;
  d := replace(d, 'strict_ boolean := coalesce(public.is_preview_request(), false);', 'strict_ boolean := true;');
  execute d;
end $r$;
