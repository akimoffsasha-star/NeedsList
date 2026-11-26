-- NeedsList: International Assistance Coordination & Reporting
-- Apply after migrations 001 and 002. Adds new tables only; existing business tables are not altered.

create table if not exists public.nl_assistance_records (
  id uuid primary key default gen_random_uuid(),
  assistance_code text,
  title text not null,
  donor text not null,
  donor_program text,
  agreement_ref text,
  project_id uuid references public.nl_projects(id) on delete set null,
  need_id uuid references public.nl_needs(id) on delete set null,
  enterprise_id uuid references public.nl_enterprises(id) on delete set null,
  assistance_type text not null default 'Грант' check (assistance_type in ('Грант','Технічна допомога','Обладнання / in-kind','Позика','Інше')),
  status text not null default 'Планується' check (status in ('Планується','Заявлено','Зобов’язання підтверджено','У процесі надходження','Частково отримано','Отримано','Реалізується','Завершено','Скасовано')),
  currency text not null default 'USD',
  allocated_usd numeric(18,2) not null default 0 check (allocated_usd >= 0),
  committed_usd numeric(18,2) not null default 0 check (committed_usd >= 0),
  start_date date,
  end_date date,
  responsible text,
  evidence_url text,
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint nl_assistance_dates_check check (start_date is null or end_date is null or end_date >= start_date)
);

create table if not exists public.nl_assistance_transactions (
  id uuid primary key default gen_random_uuid(),
  assistance_id uuid not null references public.nl_assistance_records(id) on delete cascade,
  transaction_type text not null check (transaction_type in ('Зобов’язання','Надходження коштів','Витрати','Передача обладнання / послуги','Повернення коштів','Коригування')),
  transaction_date date not null,
  amount numeric(18,2) not null check (amount >= 0),
  currency text not null default 'USD',
  amount_usd numeric(18,2) not null check (amount_usd >= 0),
  exchange_rate numeric(18,8),
  reference_no text,
  evidence_url text,
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists nl_assistance_donor_idx on public.nl_assistance_records(donor);
create index if not exists nl_assistance_project_idx on public.nl_assistance_records(project_id);
create index if not exists nl_assistance_need_idx on public.nl_assistance_records(need_id);
create index if not exists nl_assistance_enterprise_idx on public.nl_assistance_records(enterprise_id);
create index if not exists nl_assistance_status_idx on public.nl_assistance_records(status);
create index if not exists nl_assistance_tx_record_idx on public.nl_assistance_transactions(assistance_id);
create index if not exists nl_assistance_tx_date_idx on public.nl_assistance_transactions(transaction_date);

create or replace function public.nl_assistance_set_updated_at()
returns trigger language plpgsql as $$ begin new.updated_at = now(); return new; end; $$;
drop trigger if exists trg_nl_assistance_updated_at on public.nl_assistance_records;
create trigger trg_nl_assistance_updated_at before update on public.nl_assistance_records
for each row execute function public.nl_assistance_set_updated_at();

alter table public.nl_assistance_records enable row level security;
alter table public.nl_assistance_transactions enable row level security;

drop policy if exists nl_assistance_records_admin_select on public.nl_assistance_records;
drop policy if exists nl_assistance_records_admin_insert on public.nl_assistance_records;
drop policy if exists nl_assistance_records_admin_update on public.nl_assistance_records;
drop policy if exists nl_assistance_records_admin_delete on public.nl_assistance_records;
create policy nl_assistance_records_admin_select on public.nl_assistance_records for select to authenticated
using (exists (select 1 from public.nl_profiles p where p.user_id = auth.uid() and p.role = 'admin'));
create policy nl_assistance_records_admin_insert on public.nl_assistance_records for insert to authenticated
with check (exists (select 1 from public.nl_profiles p where p.user_id = auth.uid() and p.role = 'admin'));
create policy nl_assistance_records_admin_update on public.nl_assistance_records for update to authenticated
using (exists (select 1 from public.nl_profiles p where p.user_id = auth.uid() and p.role = 'admin'))
with check (exists (select 1 from public.nl_profiles p where p.user_id = auth.uid() and p.role = 'admin'));
create policy nl_assistance_records_admin_delete on public.nl_assistance_records for delete to authenticated
using (exists (select 1 from public.nl_profiles p where p.user_id = auth.uid() and p.role = 'admin'));

drop policy if exists nl_assistance_transactions_admin_select on public.nl_assistance_transactions;
drop policy if exists nl_assistance_transactions_admin_insert on public.nl_assistance_transactions;
drop policy if exists nl_assistance_transactions_admin_update on public.nl_assistance_transactions;
drop policy if exists nl_assistance_transactions_admin_delete on public.nl_assistance_transactions;
create policy nl_assistance_transactions_admin_select on public.nl_assistance_transactions for select to authenticated
using (exists (select 1 from public.nl_profiles p where p.user_id = auth.uid() and p.role = 'admin'));
create policy nl_assistance_transactions_admin_insert on public.nl_assistance_transactions for insert to authenticated
with check (exists (select 1 from public.nl_profiles p where p.user_id = auth.uid() and p.role = 'admin'));
create policy nl_assistance_transactions_admin_update on public.nl_assistance_transactions for update to authenticated
using (exists (select 1 from public.nl_profiles p where p.user_id = auth.uid() and p.role = 'admin'))
with check (exists (select 1 from public.nl_profiles p where p.user_id = auth.uid() and p.role = 'admin'));
create policy nl_assistance_transactions_admin_delete on public.nl_assistance_transactions for delete to authenticated
using (exists (select 1 from public.nl_profiles p where p.user_id = auth.uid() and p.role = 'admin'));

grant select, insert, update, delete on public.nl_assistance_records to authenticated;
grant select, insert, update, delete on public.nl_assistance_transactions to authenticated;
