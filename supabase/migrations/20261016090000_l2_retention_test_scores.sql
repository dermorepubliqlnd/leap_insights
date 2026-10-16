-- Migration 20261016090000_l2_retention_test_scores
-- v5.10 (2026-10-16, per Sandra): L2 retention tests (post-test re-taken N days after training).
-- Program/session config lives in the existing assessments jsonb ({..., retention:true, retentionDays:30, retentionDueDate}).
-- Participant scores get their own jsonb bag, keyed by assessment name (same shape as pre/post_test_scores).
-- Additive and idempotent.

alter table public.session_participants
  add column if not exists retention_test_scores jsonb not null default '{}'::jsonb;

comment on column public.session_participants.retention_test_scores is
  'v5.10: L2 retention-test scores keyed by assessment name, e.g. {"GMP Knowledge": 82}. Entered after the session is complete.';
