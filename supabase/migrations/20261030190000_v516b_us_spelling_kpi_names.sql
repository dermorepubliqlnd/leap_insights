-- v5.16b — US spelling for department KPI names
-- What:  Renames three department KPI display names (kpi_targets.kpi_name, role 'department') to US spelling:
--        Trainer Utilisation → Trainer Utilization; Knowledge Gain (normalised) → Knowledge Gain (normalized);
--        Behavioural Effectiveness (L3) → Behavioral Effectiveness (L3). Names only; keys, targets and weights unchanged.
-- Why:   Sandra (2026-10-30): "use US dictionary".
-- Date:  2026-10-30 · Asked by: Sandra Barlao · Status: APPLIED LIVE 2026-10-30 (display text only)
update public.kpi_targets set kpi_name = 'Trainer Utilization', updated_at = now() where role = 'department' and kpi_key = 'dp_util' and kpi_name = 'Trainer Utilisation';
update public.kpi_targets set kpi_name = 'Knowledge Gain (normalized)', updated_at = now() where role = 'department' and kpi_key = 'dp_gain' and kpi_name = 'Knowledge Gain (normalised)';
update public.kpi_targets set kpi_name = 'Behavioral Effectiveness (L3)', updated_at = now() where role = 'department' and kpi_key = 'dp_l3' and kpi_name = 'Behavioural Effectiveness (L3)';
