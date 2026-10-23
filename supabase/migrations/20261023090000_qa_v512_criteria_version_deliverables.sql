-- v5.12 (2026-10-23, per Sandra): ID QA / CD QA criteria applicability v2.
-- Additive + idempotent. Past reviews are NOT changed: every existing row gets criteria_version = 1
-- (pre-v5.12 rules); the app stamps criteria_version = 2 on reviews created from v5.12.

-- 1. Criteria version on review records -------------------------------------------------
alter table public.idqa_reviews add column if not exists criteria_version smallint not null default 1;
alter table public.cdqa_reviews add column if not exists criteria_version smallint not null default 1;

alter table public.idqa_reviews drop constraint if exists idqa_reviews_criteria_version_chk;
alter table public.idqa_reviews add constraint idqa_reviews_criteria_version_chk check (criteria_version in (1,2));
alter table public.cdqa_reviews drop constraint if exists cdqa_reviews_criteria_version_chk;
alter table public.cdqa_reviews add constraint cdqa_reviews_criteria_version_chk check (criteria_version in (1,2));

-- 2. Deliverable Types aligned to "LEAP Insights - Criteria and Content Applicability.xlsx" --
-- 2a. Renames (ID). Past reviews point to the row id, so they show the new label (approved by Sandra).
update public.deliverables set name = 'Training Design Document'
 where name = 'Course Design Document';
update public.deliverables set name = 'Facilitator Guide Outline'
 where name = 'Facilitator Guide' and is_id and not is_cd;   -- must run before the CD "Facilitator Guide" insert

-- 2b. New types (skipped if a type with the same name already exists)
insert into public.deliverables (id, name, is_id, is_cd, is_default, is_active)
select v.id, v.name, v.is_id, v.is_cd, false, true
  from (values
    ('dlv_v512_tps',  'Training Project Scope',      true,  false),
    ('dlv_v512_nad',  'Needs Analysis Document',     true,  false),
    ('dlv_v512_tco',  'Training Collateral Outline', true,  false),
    ('dlv_v512_pbo',  'Playbook Outline',            true,  false),
    ('dlv_v512_cdg',  'Content Development Guide',   true,  false),
    ('dlv_v512_gfx',  'Graphics',                    false, true),
    ('dlv_v512_fg',   'Facilitator Guide',           false, true),
    ('dlv_v512_pb',   'Playbook',                    false, true),
    ('dlv_v512_lms',  'LMS Setup',                   false, true)
  ) as v(id, name, is_id, is_cd)
 where not exists (select 1 from public.deliverables d where lower(trim(d.name)) = lower(v.name));

-- 2c. Retired for new reviews (deactivated only; existing reviews keep their type and stay readable)
update public.deliverables set is_active = false
 where name in ('Lesson Plan', 'Participant Workbook', 'Learning Journey Map',
                'Job Aid', 'Worksheet', 'Assessment', 'Survey');
