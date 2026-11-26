-- NeedsList: project portfolio table
-- Apply once in Supabase SQL Editor as a database administrator.
-- Existing NeedsList tables and records are not altered.

create table if not exists public.nl_projects (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  donor text not null,
  program text,
  reference_no text,
  profile text not null default 'generic',
  beneficiary text,
  owner text,
  contact_email text,
  status text not null default 'Ідея',
  submitted_at date,
  deadline date,
  next_date date,
  next_event text,
  requested_usd numeric(18,2) not null default 0 check (requested_usd >= 0),
  approved_usd numeric(18,2) not null default 0 check (approved_usd >= 0),
  contracted_usd numeric(18,2) not null default 0 check (contracted_usd >= 0),
  disbursed_usd numeric(18,2) not null default 0 check (disbursed_usd >= 0),
  spent_usd numeric(18,2) not null default 0 check (spent_usd >= 0),
  start_date date,
  end_date date,
  outcome text,
  milestones text,
  risks text,
  documents_url text,
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint nl_projects_dates_check check (start_date is null or end_date is null or end_date >= start_date)
);

create index if not exists nl_projects_status_idx on public.nl_projects(status);
create index if not exists nl_projects_donor_idx on public.nl_projects(donor);
create index if not exists nl_projects_deadline_idx on public.nl_projects(deadline);
create index if not exists nl_projects_updated_idx on public.nl_projects(updated_at desc);

create or replace function public.nl_projects_set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_nl_projects_updated_at on public.nl_projects;
create trigger trg_nl_projects_updated_at
before update on public.nl_projects
for each row execute function public.nl_projects_set_updated_at();

alter table public.nl_projects enable row level security;

drop policy if exists "nl_projects_admin_select" on public.nl_projects;
drop policy if exists "nl_projects_admin_insert" on public.nl_projects;
drop policy if exists "nl_projects_admin_update" on public.nl_projects;
drop policy if exists "nl_projects_admin_delete" on public.nl_projects;

create policy "nl_projects_admin_select" on public.nl_projects
for select to authenticated
using (exists (select 1 from public.nl_profiles p where p.user_id = auth.uid() and p.role = 'admin'));

create policy "nl_projects_admin_insert" on public.nl_projects
for insert to authenticated
with check (exists (select 1 from public.nl_profiles p where p.user_id = auth.uid() and p.role = 'admin'));

create policy "nl_projects_admin_update" on public.nl_projects
for update to authenticated
using (exists (select 1 from public.nl_profiles p where p.user_id = auth.uid() and p.role = 'admin'))
with check (exists (select 1 from public.nl_profiles p where p.user_id = auth.uid() and p.role = 'admin'));

create policy "nl_projects_admin_delete" on public.nl_projects
for delete to authenticated
using (exists (select 1 from public.nl_profiles p where p.user_id = auth.uid() and p.role = 'admin'));

grant select, insert, update, delete on public.nl_projects to authenticated;
