-- v5.17 — Knowledge Base in the database (shared L&D apps KB framework)
-- What:  kb_categories, kb_entries (permanent article numbers KB-0001.. from a sequence, never reused; draft/published;
--        pinned; audience everyone/leaders/admins; archive instead of delete), kb_entry_versions (snapshot before every
--        edit, written by trigger). RLS: signed-in users read published, non-archived articles; admins read everything
--        (drafts are shown only on the preview site by the app) and are the only writers. Seeds the 9 LEAP categories.
-- Why:   Sandra (2026-10-30): rebuild the LEAP KB to the shared framework; today articles live in each browser and the
--        admin check uses the pre-Supabase login.
-- Date:  2026-10-30 · Asked by: Sandra Barlao ("you can start doing it in preview") · Status: APPLIED LIVE 2026-10-30 (additive; live app still uses LEAP_KB.html)
-- Additive/idempotent.

create sequence if not exists public.kb_article_seq start 1;

create table if not exists public.kb_categories (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null unique,
  description text,
  icon text,
  color text,
  sort_order int not null default 0,
  is_active boolean not null default true,
  archived_at timestamptz,
  archived_by uuid,
  created_at timestamptz not null default now()
);

create table if not exists public.kb_entries (
  id uuid primary key default gen_random_uuid(),
  article_number int not null unique default nextval('public.kb_article_seq'),
  slug text unique,
  category_id uuid not null references public.kb_categories(id),
  title text not null,
  content text not null default '',
  audience text not null default 'everyone' check (audience in ('everyone','leaders','admins')),
  keywords text,
  sort_order int not null default 0,
  is_active boolean not null default false,
  is_pinned boolean not null default false,
  created_at timestamptz not null default now(),
  created_by uuid,
  updated_at timestamptz not null default now(),
  updated_by uuid,
  archived_at timestamptz,
  archived_by uuid,
  constraint kb_entries_title_per_category unique (category_id, title)
);
create index if not exists kb_entries_category_idx on public.kb_entries(category_id, sort_order);

create table if not exists public.kb_entry_versions (
  id uuid primary key default gen_random_uuid(),
  entry_id uuid not null references public.kb_entries(id) on delete cascade,
  title text,
  content text,
  edited_at timestamptz not null default now(),
  edited_by uuid
);
create index if not exists kb_entry_versions_entry_idx on public.kb_entry_versions(entry_id, edited_at desc);

-- snapshot the previous version before every title/content edit; stamp updated_at/by
create or replace function public.kb_entries_before_update()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.title is distinct from old.title or new.content is distinct from old.content then
    insert into public.kb_entry_versions (entry_id, title, content, edited_by) values (old.id, old.title, old.content, auth.uid());
  end if;
  new.updated_at := now();
  new.updated_by := coalesce(auth.uid(), new.updated_by);
  new.article_number := old.article_number;   -- numbers are permanent
  return new;
end $$;
drop trigger if exists kb_entries_before_update on public.kb_entries;
create trigger kb_entries_before_update before update on public.kb_entries for each row execute function public.kb_entries_before_update();

alter table public.kb_categories enable row level security;
alter table public.kb_entries enable row level security;
alter table public.kb_entry_versions enable row level security;

drop policy if exists kbc_read on public.kb_categories;
create policy kbc_read on public.kb_categories for select to authenticated using (archived_at is null or public.is_admin());
drop policy if exists kbc_write on public.kb_categories;
create policy kbc_write on public.kb_categories for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists kbe_read on public.kb_entries;
create policy kbe_read on public.kb_entries for select to authenticated using (public.is_admin() or (is_active and archived_at is null));
drop policy if exists kbe_write on public.kb_entries;
create policy kbe_write on public.kb_entries for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists kbv_read on public.kb_entry_versions;
create policy kbv_read on public.kb_entry_versions for select to authenticated using (public.is_admin());
-- versions are written only by the trigger (security definer); no insert policy for users

insert into public.kb_categories (slug, name, description, icon, color, sort_order) values
  ('getting-started','Getting Started','Signing in, finding your way around and what LEAP is for','🚀','#dbeafe',1),
  ('my-performance','My Performance & PDP','Your scorecard, ratings, KPI definitions and development plan','🎯','#ede9fe',2),
  ('leading-a-team','Leading a Team','Team Performance, verifying PDPs and quarter-end ratings for people leaders','👥','#cffafe',3),
  ('department-performance','Department Performance','Department KPIs, committed projects and learning outcomes','🏢','#dcfce7',4),
  ('learning-programs','Learning Programs','Building, versioning and evaluating programs in the library','📚','#fef3c7',5),
  ('training-operations','Training Operations','Scheduling sessions, attendance, assessments, reports and checklists','📅','#ffedd5',6),
  ('quality-assurance','Quality Assurance','Trainer evaluations, ID QA, CD QA and acknowledging results','✅','#e0f2fe',7),
  ('admin-settings','Admin & Settings','Users, access, targets and settings (admins)','⚙️','#f1f5f9',8),
  ('faq-support','FAQ & Support','Common questions, troubleshooting and getting help','❓','#fce7f3',9),
  ('whats-new','What''s New','One article per release: what changed and what you do','🆕','#fef9c3',10)
on conflict (slug) do nothing;
