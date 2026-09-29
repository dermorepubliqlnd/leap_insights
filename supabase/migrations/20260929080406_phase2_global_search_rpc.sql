-- Migration 20260929080406_phase2_global_search_rpc
-- Exported verbatim from supabase_migrations.schema_migrations (live project catvpurbyvsnijxpzwoh) on 2026-09-29.
-- Already applied to production. Do not re-run manually.


create extension if not exists pg_trgm with schema extensions;

create or replace function public.global_search(
  p_query text,
  p_scope text default 'all',
  p_field text default 'any',
  p_status text default null,
  p_year integer default null,
  p_limit integer default 60
)
returns table(
  result_type text,
  record_id text,
  extra_id text,
  code text,
  title text,
  subtitle text,
  status text,
  result_date date,
  rank_score numeric
)
language sql
stable
security invoker
set search_path = 'pg_catalog','public','extensions'
as $$
with params as (
  select
    lower(trim(coalesce(p_query,''))) as q,
    greatest(1,least(coalesce(p_limit,60),100)) as lim
),
raw as (
  /* Training Sessions */
  select
    'sessions'::text result_type,
    ts.id::text record_id,
    null::text extra_id,
    coalesce(ts.code,ts.id)::text code,
    coalesce(ts.training_program,'Untitled Training')::text title,
    concat_ws(' · ',
      ts.batch_no,
      ts.delivery_type,
      coalesce(nullif(trim(concat_ws(' ',trainer.first_name,trainer.last_name)),''),ts.guest_trainer_name,ts.facilitator_name),
      ts.training_date::text
    )::text subtitle,
    ts.status::text status,
    ts.training_date::date result_date,
    concat_ws(' ',
      ts.id,ts.code,ts.batch_no,ts.training_program,ts.category,ts.delivery_type,
      ts.description,ts.session_notes,ts.recording_link,ts.venue_other_name,
      array_to_string(ts.audience,' '),
      coalesce(nullif(trim(concat_ws(' ',trainer.first_name,trainer.last_name)),''),''),
      coalesce(nullif(trim(concat_ws(' ',cofac.first_name,cofac.last_name)),''),''),
      lp.code,lp.title,lp.version
    ) search_any,
    concat_ws(' ',ts.id,ts.code,ts.batch_no,lp.code,lp.version) search_id,
    concat_ws(' ',ts.training_program,lp.title,
      coalesce(nullif(trim(concat_ws(' ',trainer.first_name,trainer.last_name)),''),''),
      coalesce(nullif(trim(concat_ws(' ',cofac.first_name,cofac.last_name)),''),'')
    ) search_name
  from public.training_sessions ts
  left join public.learning_programs lp on lp.id=ts.program_id
  left join public.profiles trainer on trainer.id=ts.trainer_id
  left join public.profiles cofac on cofac.id=ts.co_facilitator_id
  where p_scope in ('all','sessions')
    and (p_status is null or p_status='' or ts.status=p_status)
    and (p_year is null or extract(year from coalesce(ts.training_date,ts.end_date))::integer=p_year)

  union all

  /* Learning Programs */
  select
    'programs', lp.id, null, coalesce(lp.code,lp.id), coalesce(lp.title,'Untitled Program'),
    concat_ws(' · ',lp.version,lp.delivery_type,lp.status),
    lp.status, lp.effective_from,
    concat_ws(' ',lp.id,lp.code,lp.version,lp.title,lp.description,lp.delivery_type,lp.status,lp.resource_url,lp.contributors::text),
    concat_ws(' ',lp.id,lp.code,lp.version,lp.program_family_id),
    concat_ws(' ',lp.title)
  from public.learning_programs lp
  where p_scope in ('all','programs')
    and (p_status is null or p_status='' or lp.status=p_status)
    and (p_year is null or extract(year from lp.effective_from)::integer=p_year)

  union all

  /* Trainer Evaluations */
  select
    'evaluations', e.id, e.session_id, coalesce(e.code,e.id),
    coalesce(e.training_program,ts.training_program,'Trainer Evaluation'),
    concat_ws(' · ',ts.code,e.evaluation_mode,e.status,
      nullif(trim(concat_ws(' ',ev.first_name,ev.last_name)),'')
    ),
    e.status, coalesce(e.evaluation_date,e.training_date),
    concat_ws(' ',e.id,e.code,e.session_id,ts.code,e.batch_no,e.training_program,ts.training_program,
      e.status,e.evaluation_mode,e.observations,
      nullif(trim(concat_ws(' ',tr.first_name,tr.last_name)),''),
      nullif(trim(concat_ws(' ',ev.first_name,ev.last_name)),'')
    ),
    concat_ws(' ',e.id,e.code,e.session_id,ts.code,e.batch_no),
    concat_ws(' ',e.training_program,ts.training_program,
      nullif(trim(concat_ws(' ',tr.first_name,tr.last_name)),''),
      nullif(trim(concat_ws(' ',ev.first_name,ev.last_name)),'')
    )
  from public.evaluations e
  left join public.training_sessions ts on ts.id=e.session_id
  left join public.profiles tr on tr.id=e.trainer_id
  left join public.profiles ev on ev.id=e.evaluator_id
  where p_scope in ('all','evaluations')
    and (p_status is null or p_status='' or e.status=p_status)
    and (p_year is null or extract(year from coalesce(e.evaluation_date,e.training_date))::integer=p_year)

  union all

  /* ID QA */
  select
    'idqa', r.id, null, coalesce(r.code,r.id), coalesce(r.project_title,'ID QA Review'),
    concat_ws(' · ',r.deliv_type,r.status,nullif(trim(concat_ws(' ',d.first_name,d.last_name)),'')),
    r.status, coalesce(r.actual_date,r.review_date,r.target_date),
    concat_ws(' ',r.id,r.code,r.project_title,r.deliv_type,r.status,r.observations,r.designer_notes,
      nullif(trim(concat_ws(' ',d.first_name,d.last_name)),''),
      nullif(trim(concat_ws(' ',rv.first_name,rv.last_name)),'')
    ),
    concat_ws(' ',r.id,r.code),
    concat_ws(' ',r.project_title,
      nullif(trim(concat_ws(' ',d.first_name,d.last_name)),''),
      nullif(trim(concat_ws(' ',rv.first_name,rv.last_name)),'')
    )
  from public.idqa_reviews r
  left join public.profiles d on d.id=r.designer_id
  left join public.profiles rv on rv.id=r.reviewer_id
  where p_scope in ('all','idqa')
    and (p_status is null or p_status='' or r.status=p_status)
    and (p_year is null or extract(year from coalesce(r.actual_date,r.review_date,r.target_date))::integer=p_year)

  union all

  /* Content QA */
  select
    'cqa', r.id, null, coalesce(r.code,r.id), coalesce(r.project_title,'Content QA Review'),
    concat_ws(' · ',r.content_type,r.status,nullif(trim(concat_ws(' ',a.first_name,a.last_name)),'')),
    r.status, coalesce(r.actual_date,r.review_date,r.target_date),
    concat_ws(' ',r.id,r.code,r.project_title,r.content_type,r.status,r.observations,r.cd_notes,
      nullif(trim(concat_ws(' ',a.first_name,a.last_name)),''),
      nullif(trim(concat_ws(' ',rv.first_name,rv.last_name)),'')
    ),
    concat_ws(' ',r.id,r.code),
    concat_ws(' ',r.project_title,
      nullif(trim(concat_ws(' ',a.first_name,a.last_name)),''),
      nullif(trim(concat_ws(' ',rv.first_name,rv.last_name)),'')
    )
  from public.cdqa_reviews r
  left join public.profiles a on a.id=r.author_id
  left join public.profiles rv on rv.id=r.reviewer_id
  where p_scope in ('all','cqa')
    and (p_status is null or p_status='' or r.status=p_status)
    and (p_year is null or extract(year from coalesce(r.actual_date,r.review_date,r.target_date))::integer=p_year)

  union all

  /* Training Reports */
  select
    'reports', tr.id, tr.session_id, coalesce(ts.code,tr.id), coalesce(ts.training_program,'Training Report'),
    concat_ws(' · ',tr.status,tr.submitted_at::date::text,nullif(trim(concat_ws(' ',p.first_name,p.last_name)),'')),
    tr.status, coalesce(tr.submitted_at::date,tr.created_at::date),
    concat_ws(' ',tr.id,tr.session_id,ts.code,ts.training_program,tr.status,tr.return_reason,tr.reopen_reason,tr.content::text,
      nullif(trim(concat_ws(' ',p.first_name,p.last_name)),'')
    ),
    concat_ws(' ',tr.id,tr.session_id,ts.code),
    concat_ws(' ',ts.training_program,nullif(trim(concat_ws(' ',p.first_name,p.last_name)),''))
  from public.training_reports tr
  left join public.training_sessions ts on ts.id=tr.session_id
  left join public.profiles p on p.id=tr.created_by
  where p_scope in ('all','reports')
    and (p_status is null or p_status='' or tr.status=p_status)
    and (p_year is null or extract(year from coalesce(tr.submitted_at,tr.created_at))::integer=p_year)

  union all

  /* Users */
  select
    'users', p.id::text, null, coalesce(p.employee_id,p.id::text),
    coalesce(nullif(trim(concat_ws(' ',p.first_name,p.last_name)),''),p.email,p.id::text),
    concat_ws(' · ',p.employee_id,p.email,pos.name,case when p.is_active then 'Active' else 'Inactive' end),
    case when p.is_active then 'active' else 'inactive' end,
    p.hire_date,
    concat_ws(' ',p.id::text,p.employee_id,p.email,p.first_name,p.last_name,pos.name),
    concat_ws(' ',p.id::text,p.employee_id,p.email),
    concat_ws(' ',p.first_name,p.last_name,pos.name)
  from public.profiles p
  left join public.positions pos on pos.id=p.position_id
  where p_scope in ('all','users')
    and (p_status is null or p_status='' or (case when p.is_active then 'active' else 'inactive' end)=p_status)
    and (p_year is null or extract(year from p.hire_date)::integer=p_year)
),
scored as (
  select r.*,
    lower(case p_field when 'id' then r.search_id when 'name' then r.search_name else r.search_any end) haystack,
    lower(coalesce(r.code,'')) lc_code,
    p.q,
    case
      when p.q='' then 1.0
      when lower(coalesce(r.code,''))=p.q then 1000.0
      when lower(r.record_id)=p.q then 950.0
      when lower(coalesce(r.code,'')) like p.q||'%' then 800.0
      when lower(coalesce(r.title,''))=p.q then 760.0
      when lower(coalesce(r.title,'')) like p.q||'%' then 700.0
      when lower(case p_field when 'id' then r.search_id when 'name' then r.search_name else r.search_any end) like '%'||p.q||'%' then 500.0
      else 100.0 * extensions.similarity(
        lower(case p_field when 'id' then r.search_id when 'name' then r.search_name else r.search_any end),
        p.q
      )
    end::numeric rank_score
  from raw r cross join params p
),
filtered as (
  select *
  from scored
  where q=''
     or haystack like '%'||q||'%'
     or extensions.similarity(haystack,q)>=0.18
)
select result_type,record_id,extra_id,code,title,subtitle,status,result_date,rank_score
from filtered
order by rank_score desc, result_date desc nulls last, title
limit (select lim from params);
$$;

grant execute on function public.global_search(text,text,text,text,integer,integer) to authenticated;
