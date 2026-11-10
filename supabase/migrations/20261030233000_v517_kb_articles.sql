-- v5.17 — Knowledge Base articles (drafts; published at release)
-- What:  24 articles written to the shared KB framework (task-first, bold outcome, What you do), converting and
--        replacing the 17 browser-stored articles. Inserted as DRAFTS (is_active = false): visible to admins on the
--        preview site only; switched on at release.
-- Date:  2026-10-30 · Asked by: Sandra Barlao · Status: APPLIED LIVE 2026-10-30 (drafts only) — loaded through the admin session in LEAP preview (same rows, KB-0001..KB-0024);
--        this file is the record and is safe to re-run (on conflict (slug) do nothing)

insert into public.kb_entries (category_id, slug, title, content, audience, keywords, sort_order, is_active, is_pinned, created_by, updated_by)
select c.id, 'welcome', $kb$Welcome to LEAP Insights$kb$, $kb$**LEAP Insights is where L&D plans, delivers, checks and measures its work, and where you see how you're doing.**

## What you'll use it for
| If you are… | You'll mostly use |
|---|---|
| Anyone on the L&D team | **My Performance** (your scorecard and PDP), **Training Calendar**, the QA forms you're assigned |
| A people leader | **Team Performance** for everyone in your reporting line |
| Department Head / authorized management | **Department Performance** for the department's KPIs and commitments |
| Admin | **User Management** and **Settings** |

*What you do:* Sign in, open **My Performance** to see your scorecard, then add your **PDP** for the quarter.

## Getting help
Every main page has a **?** next to its title that opens the right article. You can also search here.
*What you do:* Use the search bar above, or browse by topic.

## Want the detail?
- [[How to sign in and reset your password]]
- [[Finding your way around LEAP]]
- [[Reading your scorecard (My Performance)]]
$kb$, 'everyone', $kb$start, overview, what is leap$kb$, 1, false, true, '025a9ffb-2de4-4242-b157-24d29a811374', '025a9ffb-2de4-4242-b157-24d29a811374' from public.kb_categories c where c.slug = 'getting-started'
on conflict (slug) do nothing;

insert into public.kb_entries (category_id, slug, title, content, audience, keywords, sort_order, is_active, is_pinned, created_by, updated_by)
select c.id, 'sign-in', $kb$How to sign in and reset your password$kb$, $kb$**Sign in with your work email and password, or with your Microsoft account.**

## Sign in
1. Open LEAP Insights from the link shared by L&D.
2. Enter your work email and password, or click **Sign in with Microsoft**.
3. First time? Use the temporary password from L&D. You'll be asked to set your own password before you continue.

*What you do:* Choose a password of at least 8 characters that you don't use elsewhere.

## Forgot your password
Click **Forgot password** on the sign-in page and follow the email link to set a new one.
*What you do:* If the email doesn't arrive in a few minutes, check junk mail, then raise a RICA ticket.

## Change your password
Click **Password** at the bottom of the sidebar, enter your current password and the new one twice, then save.

## Want the detail?
- [[Getting help: raise a RICA ticket]]
$kb$, 'everyone', $kb$login, log in, password, forgot, microsoft, reset$kb$, 2, false, false, '025a9ffb-2de4-4242-b157-24d29a811374', '025a9ffb-2de4-4242-b157-24d29a811374' from public.kb_categories c where c.slug = 'getting-started'
on conflict (slug) do nothing;

insert into public.kb_entries (category_id, slug, title, content, audience, keywords, sort_order, is_active, is_pinned, created_by, updated_by)
select c.id, 'navigating', $kb$Finding your way around LEAP$kb$, $kb$**The sidebar groups LEAP by what you're doing; you only see the pages your access allows.**

| Group | Pages | Who sees them |
|---|---|---|
| Performance | **My Performance**, **Team Performance**, **Department Performance** | Everyone · people leaders · Department Head and authorized management |
| Quality Assurance | **Instructional Design**, **Content Development**, **Trainer Evaluation**, **QA Reports** | By form access |
| Training Operations | **Training Dashboard**, **Learning Programs**, **Training Calendar**, **Trainer Checklist** | Everyone |
| Manage | **User Management**, **Settings** | Admins |
| Cost & Finance | **Cost Analysis**, **Cost Settings** | Restricted |
| Resources | **Knowledge Base** | Everyone |

*What you do:* Press **Ctrl K** (or click the search bar at the top) to jump to any session, program or person.

## Help on every page
Click the **?** next to a page title to open its article here.

## Want the detail?
- [[Users, roles and access]]
$kb$, 'everyone', $kb$menu, sidebar, navigation, search, where is$kb$, 3, false, false, '025a9ffb-2de4-4242-b157-24d29a811374', '025a9ffb-2de4-4242-b157-24d29a811374' from public.kb_categories c where c.slug = 'getting-started'
on conflict (slug) do nothing;

insert into public.kb_entries (category_id, slug, title, content, audience, keywords, sort_order, is_active, is_pinned, created_by, updated_by)
select c.id, 'my-performance', $kb$Reading your scorecard (My Performance)$kb$, $kb$**My Performance shows your own scorecard: each KPI for your role, its rating out of 5, and your overall score.**

## How your score is worked out
Each KPI's result becomes a rating from 1 to 5, where **3 = target met**. Your overall score is the weighted average of the KPIs that have data.

| Overall score | Band |
|---|---|
| 4.50 and above | {success:Outstanding} |
| 3.50–4.49 | {success:Exceeds Expectations} |
| 2.50–3.49 | {accent:Meets Expectations} |
| 1.50–2.49 | {warning:Needs Improvement} |
| Below 1.50 | {danger:Unsatisfactory} |

*What you do:* Hover the **ⓘ** next to a KPI to see exactly how it's calculated.

## Month and Quarter
**Month** is a progress check. **Quarter** is the formal review and pools the whole quarter's data. PDP, EEI and LEI are rated in the Quarter view only.

## What the statuses mean
| Status | Meaning |
|---|---|
| {success:Met} / {danger:Below target} | Rated |
| {warning:Awaiting acknowledgement} | Evaluations or reviews you haven't acknowledged yet. They don't count until you do |
| {neutral:Pending data} / {neutral:No activity} | Nothing to rate yet in this period |
| {neutral:Rated quarterly} | Shown in the Quarter view |

KPIs without a rating are left out, and the score shows {warning:Provisional} until the period ends with all KPIs rated.
*What you do:* Acknowledge your evaluations and QA reviews promptly so they count.

## Want the detail?
- [[KPI definitions and rating scales]]
- [[Your Personal Development Plan (PDP)]]
$kb$, 'everyone', $kb$scorecard, rating, kpi, my performance, overall score, band$kb$, 1, false, true, '025a9ffb-2de4-4242-b157-24d29a811374', '025a9ffb-2de4-4242-b157-24d29a811374' from public.kb_categories c where c.slug = 'my-performance'
on conflict (slug) do nothing;

insert into public.kb_entries (category_id, slug, title, content, audience, keywords, sort_order, is_active, is_pinned, created_by, updated_by)
select c.id, 'kpi-definitions', $kb$KPI definitions and rating scales$kb$, $kb$**Every role has its own scorecard, effective 1 October 2026. Weights add up to 100%.**

### Instructional Designer
| KPI | Weight | What it measures |
|---|---|---|
| ID QA score | 35% | Average score of your acknowledged ID QA reviews |
| Learning Content Rating | 30% | Learners' content rating on sessions of programs where you're tagged for ID work |
| Timeliness | 30% | Deliverables completed by their target date |
| PDP | 5% | Verified PDP this quarter |

### Content Developer
| KPI | Weight | What it measures |
|---|---|---|
| CD QA score | 35% | Average score of your acknowledged CD QA reviews |
| Learning Material Rating | 30% | Learners' material rating on programs where you're tagged for Development |
| Timeliness | 30% | Deliverables completed by their target date |
| PDP | 5% | Verified PDP this quarter |

### Trainer
| KPI | Weight | What it measures |
|---|---|---|
| Facilitator Effectiveness | 25% | Learners' facilitator rating, weighted by responses |
| Average Assessment Score | 25% | Average of learners' final (post-test) scores on graded assessments |
| Trainer Observation | 25% | Your acknowledged Trainer Evaluation scores |
| Report SLA | 20% | Training reports submitted within 2 business days of the session |
| PDP | 5% | Verified PDP this quarter |

### Supervisor
Team roll-up 50% (average overall score of everyone in your reporting line), Trainer Evaluation completion 10%, ID QA completion 10%, CD QA completion 10%, LEI 10%, EEI 5%, PDP 5%.

### Director
KR Achievement 60% (target 80%), Team roll-up 20%, LEI 10%, EEI 5%, PDP 5%. All rated quarterly.

*What you do:* Open **View rating scale** on your scorecard to see the exact thresholds for each rating.

## Want the detail?
- [[Reading your scorecard (My Performance)]]
$kb$, 'everyone', $kb$kpi, weight, target, definition, scale, trainer, instructional designer, content developer, supervisor, director$kb$, 2, false, false, '025a9ffb-2de4-4242-b157-24d29a811374', '025a9ffb-2de4-4242-b157-24d29a811374' from public.kb_categories c where c.slug = 'my-performance'
on conflict (slug) do nothing;

insert into public.kb_entries (category_id, slug, title, content, audience, keywords, sort_order, is_active, is_pinned, created_by, updated_by)
select c.id, 'pdp', $kb$Your Personal Development Plan (PDP)$kb$, $kb$**Complete and have verified at least one PDP item each quarter; it counts 5% of your scorecard.**

## The flow
{neutral:Planned} → {warning:Ongoing} → {accent:Submitted} → {success:Verified}

1. On **My Performance**, click **+ Add PDP**: title, provider (DermoU, External, On-the-job, Other) and target date.
2. Click **Start** when you begin.
3. When done, click **Mark complete** and add a proof link (certificate, output, LMS record).
4. Your supervisor (or anyone above them) verifies it. If something's missing it comes back as {danger:Returned} with a note.

*What you do:* Submit with proof before the quarter ends. With no verified PDP at quarter end, the PDP KPI rates 1.

## Good to know
- You can't verify your own PDP; peers can't see each other's.
- Until the quarter ends, a missing PDP shows **In progress**, not a low score.

## Want the detail?
- [[Verifying PDPs and entering quarter-end ratings]]
$kb$, 'everyone', $kb$pdp, development plan, learning, verify, proof$kb$, 3, false, false, '025a9ffb-2de4-4242-b157-24d29a811374', '025a9ffb-2de4-4242-b157-24d29a811374' from public.kb_categories c where c.slug = 'my-performance'
on conflict (slug) do nothing;

insert into public.kb_entries (category_id, slug, title, content, audience, keywords, sort_order, is_active, is_pinned, created_by, updated_by)
select c.id, 'team-performance', $kb$Team Performance: your team at a glance$kb$, $kb$**Team Performance shows the scorecards of everyone in your reporting line, so you can spot who needs support.**

## Choose who you see
| Option | Shows |
|---|---|
| **All Reports (Direct + Indirect)** | Everyone below you |
| **Direct Reports Only** | People who report straight to you |
| **[Name]'s Team** | One supervisor's team |

Reporting lines are dated: each month or quarter uses the line that applied then, so a transfer doesn't rewrite past periods.
*What you do:* Pick **Month** or **Quarter** and the period at the top right.

## Read the page
- Cards: team average, KPI completion, band distribution, people needing attention.
- Table: each person's score, KPI completion, alerts and 6-month trend.
- Click **View** to open that person's full scorecard; **← Back to Team Performance** returns you.

*What you do:* Start with **Needs attention**: KPIs below target, items awaiting acknowledgement, missing PDPs.

## Want the detail?
- [[Verifying PDPs and entering quarter-end ratings]]
- [[Reading your scorecard (My Performance)]]
$kb$, 'leaders', $kb$team, downline, direct reports, supervisor, leader, drill down$kb$, 1, false, false, '025a9ffb-2de4-4242-b157-24d29a811374', '025a9ffb-2de4-4242-b157-24d29a811374' from public.kb_categories c where c.slug = 'leading-a-team'
on conflict (slug) do nothing;

insert into public.kb_entries (category_id, slug, title, content, audience, keywords, sort_order, is_active, is_pinned, created_by, updated_by)
select c.id, 'verify-pdp', $kb$Verifying PDPs and entering quarter-end ratings$kb$, $kb$**You verify PDPs for people below you, and at quarter end you enter EEI and LEI for supervisors.**

## Verify a PDP
1. **Team Performance** → **View** on the person.
2. Under **Development Plan**, a {accent:Submitted} item shows **Verify** and **Return**.
3. Check the proof link, then **Verify**, or **Return** with what's missing.

*What you do:* Verify within the quarter. PDP counts only once verified.

## Quarter-end ratings (EEI, LEI, KR)
1. Open the supervisor's scorecard from **Team Performance** and switch to **Quarter**.
2. In **Quarter-end ratings**, enter EEI and LEI (1–5, from the HR survey) and click **Save ratings**.
3. The Director enters their own KR Achievement % on **My Performance** (Quarter view).

## Want the detail?
- [[Your Personal Development Plan (PDP)]]
$kb$, 'leaders', $kb$verify, pdp, eei, lei, kr, quarter end, ratings$kb$, 2, false, false, '025a9ffb-2de4-4242-b157-24d29a811374', '025a9ffb-2de4-4242-b157-24d29a811374' from public.kb_categories c where c.slug = 'leading-a-team'
on conflict (slug) do nothing;

insert into public.kb_entries (category_id, slug, title, content, audience, keywords, sort_order, is_active, is_pinned, created_by, updated_by)
select c.id, 'department-performance', $kb$Department Performance: how the department is scored$kb$, $kb$**Department Performance scores L&D against its own KPIs from the strategic plan, not the average of its people.**

Visible to the Department Head, Reports Viewers and users with Full View dashboard access.

## Two tiers
| Tier | Weight | KPIs |
|---|---|---|
| Strategic | 70% | Planned Program Delivery 18% · Learner Satisfaction 12% · Knowledge Gain 17% · Behavioral Effectiveness 14% · Coaching Certification 9% |
| Operational Health | 30% | Session Delivery 6% · Trainer Utilization 4% · NPS 5% · QA Endorse Rate 5% · On-time Deliverables 5% · Report SLA 5% |

Each KPI is rated 1–5 (3 = target). Hover **ⓘ** for the formula and scale.

## When a rating shows
The department rating appears once KPIs worth **60% of the weight** have data; until then it reads {neutral:Insufficient data}. **Weighted KPI Coverage** shows how much is measured. Quarterly KPIs read {neutral:Rated quarterly} in Month view; Planned Program Delivery reads {warning:In progress} until the quarter ends.
*What you do:* Click any KPI's source link to see the records behind it.

## Close the quarter
After the quarter ends, an admin clicks **Finalize** in Quarter view to freeze the results ({success:Final}). Re-opening is logged with a reason.

## Want the detail?
- [[Committed Projects and Planned Program Delivery]]
- [[Learning Outcomes: L1 deep dive and Knowledge Gain]]
- [[Settings: scorecard and department KPI targets]]
$kb$, 'leaders', $kb$department, kpi, strategic, operational, coverage, scorecard, finalize$kb$, 1, false, true, '025a9ffb-2de4-4242-b157-24d29a811374', '025a9ffb-2de4-4242-b157-24d29a811374' from public.kb_categories c where c.slug = 'department-performance'
on conflict (slug) do nothing;

insert into public.kb_entries (category_id, slug, title, content, audience, keywords, sort_order, is_active, is_pinned, created_by, updated_by)
select c.id, 'committed-projects', $kb$Committed Projects and Planned Program Delivery$kb$, $kb$**Committed Projects tracks what L&D committed to deliver each quarter; Planned Program Delivery = delivered ÷ counted commitments.**

Find it in **Department Performance → Delivery & Commitments**.

## What counts
| Type | Counts toward the KPI? |
|---|---|
| Original (the agreed baseline) | Yes |
| Approved insertion | Yes |
| Approved deferral | No, kept on record with its original date |
| Unplanned / ad hoc, On hold, Pipeline, Proposed | No |

## Marking delivered
A commitment can only be {success:Delivered} with evidence: a link, the program's first completed session, or an endorsed QA review. When a linked program already has a completed session, LEAP shows **Evidence found — confirm delivered**.
*What you do:* Keep owners and statuses current; mark {danger:At risk} early.

## Who changes what
Admins change Type and Status from the table or **Edit**. A type change or deferral needs an approval note. Full View users can **Propose** a commitment for approval. Every change is in **History**.

## Want the detail?
- [[Department Performance: how the department is scored]]
$kb$, 'leaders', $kb$commitments, projects, planned delivery, deferral, insertion, baseline$kb$, 2, false, false, '025a9ffb-2de4-4242-b157-24d29a811374', '025a9ffb-2de4-4242-b157-24d29a811374' from public.kb_categories c where c.slug = 'department-performance'
on conflict (slug) do nothing;

insert into public.kb_entries (category_id, slug, title, content, audience, keywords, sort_order, is_active, is_pinned, created_by, updated_by)
select c.id, 'learning-outcomes', $kb$Learning Outcomes: L1 deep dive and Knowledge Gain$kb$, $kb$**Learning Outcomes shows what learners thought (L1), what they learned (L2) and, later, what they apply (L3).**

## L1 deep dive
Learner Satisfaction (CSAT), NPS, content, material and facilitator ratings, weighted by responses. Click a program to see its sessions; click a session code to open it.

## Knowledge Gain (L2)
For each learner with a pre- and post-test: **(post − pre) ÷ (100 − pre)**. The department figure is the average across all valid learner pairs.

| Program status | Meaning |
|---|---|
| {success:Evaluated} | Every result paired |
| {warning:Partial data} | Some results missing or unmatched |
| {danger:Not yet evaluated} | Pre-test set up, but no valid pairs |
| {neutral:Not applicable} | No pre-test on the session |

Learners who score 100% on the pre-test are left out (no room to gain) and counted as excluded.
*What you do:* Add a pre-test to programs where you want Knowledge Gain measured.

## Want the detail?
- [[Attendance, assessments and the training report]]
$kb$, 'leaders', $kb$csat, nps, l1, l2, knowledge gain, normalized gain, pre test, post test, l3$kb$, 3, false, false, '025a9ffb-2de4-4242-b157-24d29a811374', '025a9ffb-2de4-4242-b157-24d29a811374' from public.kb_categories c where c.slug = 'department-performance'
on conflict (slug) do nothing;

insert into public.kb_entries (category_id, slug, title, content, audience, keywords, sort_order, is_active, is_pinned, created_by, updated_by)
select c.id, 'learning-programs', $kb$Learning Program library: create, version and evaluate$kb$, $kb$**Every internal session is created from an active Learning Program, which holds its curriculum, evaluations and team.**

## Tabs
**Overview** (details, ownership, SMEs, facilitators, contributors) · **Curriculum & Agenda** · **Evaluations** (L1–L4) · **Implementations** · **Audit Log**.
*What you do:* Use the **Actions ▾** menu to edit; **Save** and **Discard** appear while you edit.

## Versioning rules (once a program is in use)
| Change | Result |
|---|---|
| Details, ownership, contributors, SMEs, resources, L1 targets | Saved in place |
| Title or agenda wording, minutes, order (same topics and total) | **Log Minor Revision** (v1.1) with a note |
| Delivery type, parts, topics, total time, assessments, evaluations | New version |

## Contributors
Tag each contributor **ID work** and/or **Development**, with dates. Learner content ratings credit ID work; material ratings credit Development.
*What you do:* Keep contributor tags and dates accurate; they feed ID and CD scorecards.

## Want the detail?
- [[Scheduling and running a session (Training Calendar)]]
$kb$, 'everyone', $kb$program, library, version, minor revision, setup mode, curriculum, agenda, contributors, evaluations$kb$, 1, false, false, '025a9ffb-2de4-4242-b157-24d29a811374', '025a9ffb-2de4-4242-b157-24d29a811374' from public.kb_categories c where c.slug = 'learning-programs'
on conflict (slug) do nothing;

insert into public.kb_entries (category_id, slug, title, content, audience, keywords, sort_order, is_active, is_pinned, created_by, updated_by)
select c.id, 'training-calendar', $kb$Scheduling and running a session (Training Calendar)$kb$, $kb$**The Training Calendar is where every session is scheduled, delivered, closed and reported.**

## Statuses
{neutral:Tentative} → {accent:Upcoming} → {warning:In Progress} → {success:Delivery Complete}, or {danger:Cancelled}.

## Create a session
1. Click **+ New** and pick an active Learning Program (it fills title, duration, evaluations and checklist).
2. Set the dates: a **date range**, or **Specific dates** for non-consecutive days. Weekends and holidays inside a range don't count toward hours.
3. Add trainer, venue and audience. The batch code is assigned automatically.

*What you do:* Use **Tentative** to pencil-book; only a title, date and duration are needed until you confirm.

## Cancelling
Choose a **cancellation reason**. Trainer unavailable, content not ready, logistics and other count as missed in Session Delivery Rate; rescheduled, business request and low enrollment don't.

## Want the detail?
- [[Attendance, assessments and the training report]]
- [[Training Dashboard and Trainer Checklist]]
$kb$, 'everyone', $kb$session, schedule, calendar, cancel, tentative, batch, recording, specific dates$kb$, 1, false, true, '025a9ffb-2de4-4242-b157-24d29a811374', '025a9ffb-2de4-4242-b157-24d29a811374' from public.kb_categories c where c.slug = 'training-operations'
on conflict (slug) do nothing;

insert into public.kb_entries (category_id, slug, title, content, audience, keywords, sort_order, is_active, is_pinned, created_by, updated_by)
select c.id, 'training-reports', $kb$Attendance, assessments and the training report$kb$, $kb$**After a session, record attendance and scores, then submit the training report within 2 business days.**

## Attendance and assessments
Mark each participant's attendance. Enter pre- and post-test scores per assessment (percentages). Retention tests, if set up, appear with a due date; save them with **Save Retention Scores**.
*What you do:* Enter pre-tests as well as post-tests; Knowledge Gain needs both.

## The training report
Fill in learner feedback (responses, CSAT, NPS, content, material and facilitator ratings) and add the recording link, or get a **Recording Exemption** approved by your supervisor.

| Submitted | Report SLA |
|---|---|
| Within 2 business days of the last session day | {success:On time} |
| Later, or still missing after 2 days | {danger:Late} |

Reports sent by email before LEAP use **Log Report as Already Submitted**. To change a submitted report, request a reopen; it goes to your supervisor.

## L3 follow-ups
Programs with L3 show follow-up due dates. Complete them in the session's L3 section.

## Want the detail?
- [[Scheduling and running a session (Training Calendar)]]
$kb$, 'everyone', $kb$attendance, pre test, post test, assessment, report, sla, recording, exemption, l3, retention$kb$, 2, false, false, '025a9ffb-2de4-4242-b157-24d29a811374', '025a9ffb-2de4-4242-b157-24d29a811374' from public.kb_categories c where c.slug = 'training-operations'
on conflict (slug) do nothing;

insert into public.kb_entries (category_id, slug, title, content, audience, keywords, sort_order, is_active, is_pinned, created_by, updated_by)
select c.id, 'training-dashboard', $kb$Training Dashboard and Trainer Checklist$kb$, $kb$**The Training Dashboard shows delivery at a glance; the Trainer Checklist tracks pre- and post-training tasks.**

## Training Dashboard
Scheduled vs delivered hours, sessions by type and category, learner feedback, trainer workload against capacity (each trainer's allocation % from User Management) and items needing action.
*What you do:* Check **Attention** items weekly: reports due, sessions still in progress, L3 follow-ups due.

## Trainer Checklist
Each ILT session can carry a checklist template. Tasks are grouped before and after training, with overdue items flagged.
*What you do:* Tick tasks as you go; overdue post-training items show on the dashboards.

## Want the detail?
- [[Scheduling and running a session (Training Calendar)]]
$kb$, 'everyone', $kb$dashboard, hours, capacity, workload, checklist, pre training, post training$kb$, 3, false, false, '025a9ffb-2de4-4242-b157-24d29a811374', '025a9ffb-2de4-4242-b157-24d29a811374' from public.kb_categories c where c.slug = 'training-operations'
on conflict (slug) do nothing;

insert into public.kb_entries (category_id, slug, title, content, audience, keywords, sort_order, is_active, is_pinned, created_by, updated_by)
select c.id, 'trainer-evaluation', $kb$Trainer Evaluation: observe, finalize and acknowledge$kb$, $kb$**Trainer Evaluations rate delivery on 10 criteria (1–5), from a live sit-in or a recording.**

## Flow
{neutral:Draft} → **Finalize** → {warning:Pending Acknowledgement} → trainer responds and clicks **Acknowledge** → {success:Completed}

## Bands
| Score | Band |
|---|---|
| 4.50+ | Outstanding |
| 4.00–4.49 | Highly Effective |
| 3.50–3.99 | Effective (benchmark) |
| 3.00–3.49 | Developing |
| Below 3.00 | Needs Improvement |

Only acknowledged evaluations count toward scorecards.
*What you do (evaluator):* Add remarks for low ratings before you finalize. *(trainer):* Acknowledge with your response.

## Want the detail?
- [[Acknowledging results and the QA status guide]]
$kb$, 'everyone', $kb$trainer evaluation, observation, sit in, virtual, bands, acknowledge$kb$, 1, false, false, '025a9ffb-2de4-4242-b157-24d29a811374', '025a9ffb-2de4-4242-b157-24d29a811374' from public.kb_categories c where c.slug = 'quality-assurance'
on conflict (slug) do nothing;

insert into public.kb_entries (category_id, slug, title, content, audience, keywords, sort_order, is_active, is_pinned, created_by, updated_by)
select c.id, 'id-qa-review', $kb$ID QA review$kb$, $kb$**ID QA reviews rate instructional design deliverables on a 2 / 1 / 0 scale (Fully / Partially / Not achieved).**

## Disposition
| Result | Disposition |
|---|---|
| 85% or more and no 0s | {success:Endorse} |
| 70–84%, or any 0 | {warning:Revise & Resubmit} |
| Below 70% | {danger:Major Revision} |

Only the criteria that apply to the **Deliverable Type** are shown. Target and actual dates give the **Timeliness** result.
*What you do:* Pick the right Deliverable Type first; it sets the criteria.

## Good to know
Reviews created before 23 October 2026 keep their original criteria and scores.

## Want the detail?
- [[Acknowledging results and the QA status guide]]
$kb$, 'everyone', $kb$id qa, instructional design, deliverable, disposition, endorse, revise, criteria$kb$, 2, false, false, '025a9ffb-2de4-4242-b157-24d29a811374', '025a9ffb-2de4-4242-b157-24d29a811374' from public.kb_categories c where c.slug = 'quality-assurance'
on conflict (slug) do nothing;

insert into public.kb_entries (category_id, slug, title, content, audience, keywords, sort_order, is_active, is_pinned, created_by, updated_by)
select c.id, 'cd-qa-review', $kb$CD QA review$kb$, $kb$**CD QA reviews rate developed content on the same 2 / 1 / 0 scale and dispositions as ID QA.**

Criteria depend on the **Content Type** (StoryLine, Rise, Video, Slide Deck, Handout, Activity, Audio, Infographic, Graphics, Facilitator Guide, Playbook, LMS Setup).

| Result | Disposition |
|---|---|
| 85% or more and no 0s | {success:Endorse} |
| 70–84%, or any 0 | {warning:Revise & Resubmit} |
| Below 70% | {danger:Major Revision} |

*What you do:* Pick the Content Type first; only applicable criteria appear.

## Want the detail?
- [[ID QA review]]
- [[Acknowledging results and the QA status guide]]
$kb$, 'everyone', $kb$cd qa, content development, content type, storyline, rise, video, disposition$kb$, 3, false, false, '025a9ffb-2de4-4242-b157-24d29a811374', '025a9ffb-2de4-4242-b157-24d29a811374' from public.kb_categories c where c.slug = 'quality-assurance'
on conflict (slug) do nothing;

insert into public.kb_entries (category_id, slug, title, content, audience, keywords, sort_order, is_active, is_pinned, created_by, updated_by)
select c.id, 'qa-reports', $kb$Acknowledging results and the QA status guide$kb$, $kb$**Evaluations and QA reviews count toward scores only after the person evaluated acknowledges them.**

| Status | Meaning |
|---|---|
| {neutral:Draft} | Being written; only the evaluator and admins can see it |
| {warning:Pending Acknowledgement} | Finalized and waiting for the person evaluated |
| {success:Completed} | Acknowledged; read-only, PDF available |

## Acknowledge
Open the item, add your response or notes, then click **Acknowledge**. It can't be undone; if you disagree, acknowledge with a note and raise it with your supervisor.
*What you do:* Acknowledge within 2 business days; overdue acknowledgements appear in attention lists.

## QA Reports
**QA Reports** lists completed reviews and evaluations for reporting. Admins can reopen a record for correction.

## Want the detail?
- [[Trainer Evaluation: observe, finalize and acknowledge]]
$kb$, 'everyone', $kb$acknowledge, pending, status, completed, qa reports, reopen$kb$, 4, false, false, '025a9ffb-2de4-4242-b157-24d29a811374', '025a9ffb-2de4-4242-b157-24d29a811374' from public.kb_categories c where c.slug = 'quality-assurance'
on conflict (slug) do nothing;

insert into public.kb_entries (category_id, slug, title, content, audience, keywords, sort_order, is_active, is_pinned, created_by, updated_by)
select c.id, 'user-management', $kb$Users, roles and access$kb$, $kb$**Admins add users, set their supervisor and choose what each person can see and do.**

## Access options
| Setting | Gives |
|---|---|
| Admin | Everything, including User Management and Settings |
| Reports Viewer | QA Reports for everyone; Department Performance |
| Dashboard Access: Full View | Department Performance and organization-wide figures |
| Form access (Trainer Eval / ID QA / CD QA) | Can create those forms |
| Cost access (View / Manage rates) | Cost & Finance pages |

People leaders see **Team Performance** automatically when someone reports to them.

## Add or change a user
New users get a temporary password and must change it at first sign-in. Set **Supervisor** and, for a transfer that started earlier, its **Effective from** date. **Delivery Allocation %** (60% trainers, 5% others by default) drives capacity.
*What you do:* Deactivate leavers instead of deleting them.

## Want the detail?
- [[Settings: scorecard and department KPI targets]]
$kb$, 'admins', $kb$user, account, role, access, admin, reports viewer, dashboard access, supervisor, allocation$kb$, 1, false, false, '025a9ffb-2de4-4242-b157-24d29a811374', '025a9ffb-2de4-4242-b157-24d29a811374' from public.kb_categories c where c.slug = 'admin-settings'
on conflict (slug) do nothing;

insert into public.kb_entries (category_id, slug, title, content, audience, keywords, sort_order, is_active, is_pinned, created_by, updated_by)
select c.id, 'settings-targets', $kb$Settings: scorecard and department KPI targets$kb$, $kb$**Targets and weights live in Settings, with dates, so a change applies from its date without rewriting the past.**

## Dashboard KPI Targets
- **Role KPIs**: target, data source, weight and dates per role.
- **Department KPIs**: tier, dimension, scored or supporting, target, weight, frequency.

*What you do:* To change a target from today, click **New period**. It ends the current row yesterday and starts a new one. Use **Save** only to correct a row.

## Learning Programs settings
**Default L1 Targets** (content, material, facilitator, CSAT 3.5; NPS +85), **SME & External Contacts**, and **Setup Mode** (lets editors change in-use programs without a new version during build-out).

## Lists
Departments, categories, venues, deliverable types, prerequisites and learning methods used across forms.

## Want the detail?
- [[Department Performance: how the department is scored]]
$kb$, 'admins', $kb$settings, targets, weights, kpi targets, department kpis, l1 targets, new period, setup mode$kb$, 2, false, false, '025a9ffb-2de4-4242-b157-24d29a811374', '025a9ffb-2de4-4242-b157-24d29a811374' from public.kb_categories c where c.slug = 'admin-settings'
on conflict (slug) do nothing;

insert into public.kb_entries (category_id, slug, title, content, audience, keywords, sort_order, is_active, is_pinned, created_by, updated_by)
select c.id, 'faq', $kb$Frequently asked questions$kb$, $kb$**Quick answers to the questions L&D gets most.**

### Why isn't my evaluation counted in my score?
Only acknowledged evaluations and reviews count. Open it and click **Acknowledge**.

### Why does my score say Provisional?
The period is still open or some KPIs have no data yet. It becomes Final when the quarter ends with all KPIs rated.

### I can't see Team or Department Performance.
Team Performance appears when someone reports to you. Department Performance needs Full View or Reports Viewer access; ask an admin.

### I submitted something by mistake.
Ask an admin to reopen it, or raise a RICA ticket.

### Does LEAP work on mobile?
It's built for desktop; use Chrome or Edge on a laptop for the best experience.

### The page is blank or out of date.
Press **Ctrl Shift R** to reload. Still stuck? Raise a RICA ticket.

## Want the detail?
- [[Getting help: raise a RICA ticket]]
$kb$, 'everyone', $kb$faq, question, help, wrong score, missing, not counted, mobile$kb$, 1, false, true, '025a9ffb-2de4-4242-b157-24d29a811374', '025a9ffb-2de4-4242-b157-24d29a811374' from public.kb_categories c where c.slug = 'faq-support'
on conflict (slug) do nothing;

insert into public.kb_entries (category_id, slug, title, content, audience, keywords, sort_order, is_active, is_pinned, created_by, updated_by)
select c.id, 'support', $kb$Getting help: raise a RICA ticket$kb$, $kb$**For access requests, errors or wrong data, raise a ticket in RICA, Dermorepubliq's support system.**

[Open RICA](https://rica.dermorepubliq.com/)

## Include
- Your name and the page you were on (e.g. Training Calendar)
- What you expected and what happened
- A screenshot of any error

*What you do:* For access changes, ask your supervisor to endorse the request, then use the subject "LEAP Insights — Access Request".

## Want the detail?
- [[Frequently asked questions]]
$kb$, 'everyone', $kb$rica, ticket, support, help, issue, error, access request$kb$, 2, false, false, '025a9ffb-2de4-4242-b157-24d29a811374', '025a9ffb-2de4-4242-b157-24d29a811374' from public.kb_categories c where c.slug = 'faq-support'
on conflict (slug) do nothing;

insert into public.kb_entries (category_id, slug, title, content, audience, keywords, sort_order, is_active, is_pinned, created_by, updated_by)
select c.id, 'whats-new-performance-release', $kb$Performance release (November 2026)$kb$, $kb$**LEAP now shows your performance, your team's and the department's in one place, with a Knowledge Base built in.**

@@ My Performance || Your own role scorecard from 1 Oct 2026, with Month and Quarter views and your PDP. || Open **My Performance** and add this quarter's PDP.
@@ Team Performance || Leaders see everyone in their reporting line and open each person's scorecard. || Check **Needs attention** weekly.
@@ Department Performance || Department KPIs (70% strategic, 30% operational), Committed Projects and Learning Outcomes. || Keep commitments and evidence current.
@@ Cancellation reasons || Cancelling a session now asks why. || Pick the reason that applies.
@@ Knowledge Base || Search-first help inside LEAP, with a **?** on each page. || Click **?** whenever you're unsure.

## Want the detail?
- [[Reading your scorecard (My Performance)]]
- [[Team Performance: your team at a glance]]
- [[Department Performance: how the department is scored]]
$kb$, 'everyone', $kb$release, new, changes, update$kb$, 1, false, false, '025a9ffb-2de4-4242-b157-24d29a811374', '025a9ffb-2de4-4242-b157-24d29a811374' from public.kb_categories c where c.slug = 'whats-new'
on conflict (slug) do nothing;
