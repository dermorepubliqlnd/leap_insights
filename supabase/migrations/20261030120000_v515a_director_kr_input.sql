-- v5.15a — Director scorecard: allow the quarterly KR Achievement % in scorecard_inputs
-- What:  scorecard_inputs.kpi_code may now also be 'KR' (Key Result achievement, entered as a % 0–200);
--        EEI / LEI stay 1–5 ratings. Only the two CHECK constraints change; no data is rewritten.
-- Why:   Director scorecard (Sandra, 2026-10-30): KR Achievement 60% (target 80%, rating scale R-0007),
--        Team roll-up 20%, LEI 10%, EEI 5%, PDP 5% — all quarterly. Sandra enters her own KR/EEI/LEI as admin.
-- Date:  2026-10-30 · Asked by: Sandra Barlao · Status: PREVIEW (table is only used by the preview build)

alter table public.scorecard_inputs drop constraint if exists scorecard_inputs_kpi_code_check;
alter table public.scorecard_inputs add constraint scorecard_inputs_kpi_code_check check (kpi_code in ('EEI','LEI','KR'));
alter table public.scorecard_inputs drop constraint if exists scorecard_inputs_value_check;
alter table public.scorecard_inputs add constraint scorecard_inputs_value_check
  check ((kpi_code = 'KR' and value >= 0 and value <= 200) or (kpi_code <> 'KR' and value >= 1 and value <= 5));
