-- v5.14d (2026-11-10, per Sandra) — "Training Report required?" tag on training sessions.
-- What: sessions run by an SME can be tagged "Report not required". The trainer then submits
--       only the short Survey Results (L1: responses, ratings, CSAT, NPS); the full report,
--       recording link and Trainer Checklist are skipped, and the session is excluded from
--       Report SLA. Attendance stays required.
-- Why:  SME-led sessions don't need a full training report (Sandra, 2026-11-10).
-- Additive only. Every existing session defaults to report_required = true (no change to
-- past numbers). Released straight to live per Sandra ("build all these in live now").
-- RELEASED 2026-11-10

alter table public.training_sessions
  add column if not exists report_required boolean not null default true,
  add column if not exists report_waiver_reason text,
  add column if not exists report_waiver_note text;

alter table public.training_sessions drop constraint if exists training_sessions_report_waiver_reason_check;
alter table public.training_sessions add constraint training_sessions_report_waiver_reason_check
  check (report_waiver_reason is null or report_waiver_reason in ('sme_led','other'));

comment on column public.training_sessions.report_required is
  'v5.14d: false = full Training Report not required (e.g. SME-led); survey results only.';
