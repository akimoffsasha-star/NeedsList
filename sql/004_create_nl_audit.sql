-- NeedsList Central Dashboard: append-only audit trail.
-- Apply after migrations 001, 002 and 003.
-- Captures INSERT/UPDATE/DELETE on core operational tables. Does not alter business tables.

create table if not exists public.nl_audit_log (
  id uuid primary key default gen_random_uuid(),
  table_name text not null,
  record_id text,
  action text not null check (action in ('INSERT','UPDATE','DELETE')),
  changed_by uuid,
  changed_at timestamptz not null default now(),
  old_data jsonb,
  new_data jsonb
);

create index if not exists nl_audit_log_changed_at_idx on public.nl_audit_log(changed_at desc);
create index if not exists nl_audit_log_table_record_idx on public.nl_audit_log(table_name, record_id);

create or replace function public.nl_write_audit_log()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_old jsonb;
  v_new jsonb;
  v_row jsonb;
  v_id text;
begin
  if tg_op = 'INSERT' then
    v_new := to_jsonb(new);
    v_row := v_new;
  elsif tg_op = 'UPDATE' then
    v_old := to_jsonb(old);
    v_new := to_jsonb(new);
    v_row := v_new;
  else
    v_old := to_jsonb(old);
    v_row := v_old;
  end if;

  v_id := coalesce(v_row->>'id', v_row->>'need_id', v_row->>'project_id');
  insert into public.nl_audit_log(table_name, record_id, action, changed_by, old_data, new_data)
  values (tg_table_name, v_id, tg_op, auth.uid(), v_old, v_new);

  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

alter table public.nl_audit_log enable row level security;
drop policy if exists nl_audit_log_admin_select on public.nl_audit_log;
create policy nl_audit_log_admin_select on public.nl_audit_log
for select to authenticated
using (exists (select 1 from public.nl_profiles p where p.user_id = auth.uid() and p.role = 'admin'));

-- No direct INSERT/UPDATE/DELETE policy: records are written only by the trigger function.
grant select on public.nl_audit_log to authenticated;
revoke insert, update, delete on public.nl_audit_log from anon, authenticated;

-- Install triggers only where the corresponding table exists.
do $$
declare
  t text;
  trigger_name text;
  target_tables text[] := array[
    'nl_needs',
    'nl_projects',
    'nl_project_indicators',
    'nl_project_activities',
    'nl_project_risks',
    'nl_assistance_records',
    'nl_assistance_transactions'
  ];
begin
  foreach t in array target_tables loop
    if to_regclass('public.' || t) is not null then
      trigger_name := 'trg_' || t || '_audit';
      execute format('drop trigger if exists %I on public.%I', trigger_name, t);
      execute format('create trigger %I after insert or update or delete on public.%I for each row execute function public.nl_write_audit_log()', trigger_name, t);
    end if;
  end loop;
end $$;
