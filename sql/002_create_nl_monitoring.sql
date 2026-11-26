-- NeedsList: Monitoring & Evaluation (M&E)
-- Apply after sql/001_create_nl_projects.sql in Supabase SQL Editor.
-- Adds three project-linked tables; does not alter existing application tables.

create table if not exists public.nl_project_indicators (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.nl_projects(id) on delete cascade,
  name text not null,
  definition text,
  baseline numeric(18,4),
  target numeric(18,4),
  actual numeric(18,4),
  unit text,
  direction text not null default 'Збільшення' check (direction in ('Збільшення','Зменшення','Не змінюється')),
  reporting_date date,
  frequency text,
  source text,
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.nl_project_activities (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.nl_projects(id) on delete cascade,
  name text not null,
  description text,
  responsible text,
  planned_date date,
  actual_date date,
  status text not null default 'Не розпочато' check (status in ('Не розпочато','У процесі','Виконано','Затримка','Призупинено')),
  progress_percent numeric(5,2) not null default 0 check (progress_percent >= 0 and progress_percent <= 100),
  evidence_url text,
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.nl_project_risks (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.nl_projects(id) on delete cascade,
  name text not null,
  probability text not null default 'Середня' check (probability in ('Низька','Середня','Висока')),
  impact text not null default 'Середній' check (impact in ('Низький','Середній','Високий')),
  owner text,
  status text not null default 'Відкритий' check (status in ('Відкритий','На контролі','Реалізувався','Закритий')),
  mitigation text,
  due_date date,
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists nl_project_indicators_project_idx on public.nl_project_indicators(project_id);
create index if not exists nl_project_activities_project_idx on public.nl_project_activities(project_id);
create index if not exists nl_project_activities_due_idx on public.nl_project_activities(planned_date);
create index if not exists nl_project_risks_project_idx on public.nl_project_risks(project_id);
create index if not exists nl_project_risks_due_idx on public.nl_project_risks(due_date);

create or replace function public.nl_project_me_set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_nl_project_indicators_updated_at on public.nl_project_indicators;
create trigger trg_nl_project_indicators_updated_at before update on public.nl_project_indicators
for each row execute function public.nl_project_me_set_updated_at();
drop trigger if exists trg_nl_project_activities_updated_at on public.nl_project_activities;
create trigger trg_nl_project_activities_updated_at before update on public.nl_project_activities
for each row execute function public.nl_project_me_set_updated_at();
drop trigger if exists trg_nl_project_risks_updated_at on public.nl_project_risks;
create trigger trg_nl_project_risks_updated_at before update on public.nl_project_risks
for each row execute function public.nl_project_me_set_updated_at();

alter table public.nl_project_indicators enable row level security;
alter table public.nl_project_activities enable row level security;
alter table public.nl_project_risks enable row level security;

do $$
declare t text;
begin
  foreach t in array array['nl_project_indicators','nl_project_activities','nl_project_risks'] loop
    execute format('drop policy if exists %I on public.%I', t || '_admin_select', t);
    execute format('drop policy if exists %I on public.%I', t || '_admin_insert', t);
    execute format('drop policy if exists %I on public.%I', t || '_admin_update', t);
    execute format('drop policy if exists %I on public.%I', t || '_admin_delete', t);
    execute format('create policy %I on public.%I for select to authenticated using (exists (select 1 from public.nl_profiles p where p.user_id = auth.uid() and p.role = ''admin''))', t || '_admin_select', t);
    execute format('create policy %I on public.%I for insert to authenticated with check (exists (select 1 from public.nl_profiles p where p.user_id = auth.uid() and p.role = ''admin''))', t || '_admin_insert', t);
    execute format('create policy %I on public.%I for update to authenticated using (exists (select 1 from public.nl_profiles p where p.user_id = auth.uid() and p.role = ''admin'')) with check (exists (select 1 from public.nl_profiles p where p.user_id = auth.uid() and p.role = ''admin''))', t || '_admin_update', t);
    execute format('create policy %I on public.%I for delete to authenticated using (exists (select 1 from public.nl_profiles p where p.user_id = auth.uid() and p.role = ''admin''))', t || '_admin_delete', t);
  end loop;
end $$;

grant select, insert, update, delete on public.nl_project_indicators to authenticated;
grant select, insert, update, delete on public.nl_project_activities to authenticated;
grant select, insert, update, delete on public.nl_project_risks to authenticated;
