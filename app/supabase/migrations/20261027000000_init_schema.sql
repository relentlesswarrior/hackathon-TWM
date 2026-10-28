-- Ándale — Esquema inicial (multi-tenant) para Supabase
-- Corresponde a docs/ANDALE-PRD-TDR.md, sección 6.2 (Modelo de datos) y 6.4 (Seguridad)
--
-- Cómo aplicar:
--   1) Supabase Dashboard -> SQL Editor -> pegar y correr este archivo completo, o
--   2) `supabase db push` si usas el CLI con este repo como fuente de migraciones.
--
-- Este archivo asume el schema `public` y que `auth.users` (Supabase Auth) ya existe.

-- =========================================================
-- 0. Extensiones
-- =========================================================
create extension if not exists "pgcrypto";

-- =========================================================
-- 1. Tipos (enums)
-- =========================================================
create type public.user_role as enum ('admin', 'colaborador');
create type public.client_status as enum ('activo', 'en_riesgo', 'moroso');
create type public.deal_stage as enum ('prospecto', 'negociacion', 'ganado', 'perdido');
create type public.invoice_status as enum ('pendiente', 'pagada', 'vencida');
create type public.employee_status as enum ('activo', 'baja');
create type public.time_off_status as enum ('pendiente', 'aprobado', 'rechazado');
create type public.transaction_type as enum ('income', 'expense');

-- =========================================================
-- 2. Núcleo multi-tenant
-- =========================================================
create table public.companies (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  rfc text,
  plan text not null default 'starter',
  created_at timestamptz not null default now()
);

create table public.users (
  id uuid primary key references auth.users (id) on delete cascade,
  company_id uuid not null references public.companies (id) on delete cascade,
  email text not null,
  role public.user_role not null default 'admin',
  created_at timestamptz not null default now()
);

create index users_company_id_idx on public.users (company_id);

-- =========================================================
-- 3. CRM — Cartera de clientes
-- =========================================================
create table public.clients (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete cascade,
  name text not null,
  rfc text,
  contact_name text,
  contact_email text,
  contact_phone text,
  status public.client_status not null default 'activo',
  tags text[] not null default '{}',
  created_at timestamptz not null default now()
);

create table public.deals (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete cascade,
  client_id uuid not null references public.clients (id) on delete cascade,
  stage public.deal_stage not null default 'prospecto',
  amount numeric(14, 2) not null default 0,
  expected_close date,
  created_at timestamptz not null default now()
);

create table public.client_invoices (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete cascade,
  client_id uuid not null references public.clients (id) on delete cascade,
  amount numeric(14, 2) not null,
  due_date date not null,
  status public.invoice_status not null default 'pendiente',
  created_at timestamptz not null default now()
);

create table public.interactions (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete cascade,
  client_id uuid not null references public.clients (id) on delete cascade,
  note text not null,
  created_by uuid references public.users (id),
  created_at timestamptz not null default now()
);

create index clients_company_id_idx on public.clients (company_id);
create index deals_company_id_idx on public.deals (company_id);
create index deals_client_id_idx on public.deals (client_id);
create index client_invoices_company_id_idx on public.client_invoices (company_id);
create index client_invoices_client_id_idx on public.client_invoices (client_id);
create index client_invoices_due_date_idx on public.client_invoices (due_date);
create index interactions_client_id_idx on public.interactions (client_id);

-- =========================================================
-- 4. RH — Colaboradores
-- =========================================================
create table public.employees (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete cascade,
  user_id uuid references public.users (id), -- liga al portal de colaborador (puede ser null)
  name text not null,
  department text,
  position text,
  salary numeric(14, 2) not null default 0,
  hire_date date not null default current_date,
  status public.employee_status not null default 'activo',
  created_at timestamptz not null default now()
);

create table public.payroll_records (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete cascade,
  employee_id uuid not null references public.employees (id) on delete cascade,
  period text not null, -- ej. '2026-10'
  gross numeric(14, 2) not null,
  net numeric(14, 2) not null,
  created_at timestamptz not null default now()
);

create table public.time_off_requests (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete cascade,
  employee_id uuid not null references public.employees (id) on delete cascade,
  days integer not null,
  status public.time_off_status not null default 'pendiente',
  requested_at timestamptz not null default now()
);

create index employees_company_id_idx on public.employees (company_id);
create index employees_user_id_idx on public.employees (user_id);
create index payroll_records_employee_id_idx on public.payroll_records (employee_id);
create index time_off_requests_employee_id_idx on public.time_off_requests (employee_id);

-- =========================================================
-- 5. Finanzas — Ingresos y egresos
-- =========================================================
create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete cascade,
  type public.transaction_type not null,
  category text not null,
  amount numeric(14, 2) not null,
  date date not null default current_date,
  related_table text, -- ej. 'client_invoices', 'payroll_records', 'payments'
  related_id uuid,
  created_at timestamptz not null default now()
);

create index transactions_company_id_idx on public.transactions (company_id);
create index transactions_date_idx on public.transactions (date);
create index transactions_related_idx on public.transactions (related_table, related_id);

-- =========================================================
-- 6. Pagos a proveedores (simulado)
-- =========================================================
create table public.vendors (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete cascade,
  name text not null,
  rfc text,
  contact_name text,
  contact_email text,
  created_at timestamptz not null default now()
);

create table public.vendor_invoices (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete cascade,
  vendor_id uuid not null references public.vendors (id) on delete cascade,
  amount numeric(14, 2) not null,
  due_date date not null,
  status public.invoice_status not null default 'pendiente',
  created_at timestamptz not null default now()
);

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete cascade,
  vendor_invoice_id uuid not null references public.vendor_invoices (id) on delete cascade,
  paid_at timestamptz not null default now(),
  mock_receipt_url text, -- comprobante simulado, no hay movimiento real de dinero
  created_at timestamptz not null default now()
);

create index vendors_company_id_idx on public.vendors (company_id);
create index vendor_invoices_company_id_idx on public.vendor_invoices (company_id);
create index vendor_invoices_vendor_id_idx on public.vendor_invoices (vendor_id);
create index vendor_invoices_due_date_idx on public.vendor_invoices (due_date);
create index payments_vendor_invoice_id_idx on public.payments (vendor_invoice_id);

-- =========================================================
-- 7. Agentes de IA — bitácora
-- =========================================================
create table public.agent_logs (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete cascade,
  agent_type text not null, -- 'cobranza_voz' | 'financiero' | 'atencion_interna'
  target_table text,
  target_id uuid,
  action text not null,
  result text,
  created_at timestamptz not null default now()
);

create index agent_logs_company_id_idx on public.agent_logs (company_id);
create index agent_logs_created_at_idx on public.agent_logs (created_at);

-- =========================================================
-- 8. Helpers de RLS (SECURITY DEFINER para evitar recursión)
-- =========================================================
create or replace function public.get_my_company_id()
returns uuid
language sql
security definer
stable
set search_path = public
as $$
  select company_id from public.users where id = auth.uid()
$$;

create or replace function public.get_my_role()
returns public.user_role
language sql
security definer
stable
set search_path = public
as $$
  select role from public.users where id = auth.uid()
$$;

-- =========================================================
-- 9. Row Level Security
-- =========================================================
alter table public.companies enable row level security;
alter table public.users enable row level security;
alter table public.clients enable row level security;
alter table public.deals enable row level security;
alter table public.client_invoices enable row level security;
alter table public.interactions enable row level security;
alter table public.employees enable row level security;
alter table public.payroll_records enable row level security;
alter table public.time_off_requests enable row level security;
alter table public.transactions enable row level security;
alter table public.vendors enable row level security;
alter table public.vendor_invoices enable row level security;
alter table public.payments enable row level security;
alter table public.agent_logs enable row level security;

-- companies: cualquier usuario autenticado ve solo su propia empresa
create policy "companies_select_own" on public.companies
  for select using (id = public.get_my_company_id());

-- users: ver a los compañeros de la misma empresa
create policy "users_select_same_company" on public.users
  for select using (company_id = public.get_my_company_id());

-- Tablas de administración plena (solo admin de la empresa): CRM, Finanzas, Pagos, Agent logs
do $$
declare
  t text;
begin
  for t in select unnest(array[
    'clients', 'deals', 'client_invoices', 'interactions',
    'transactions',
    'vendors', 'vendor_invoices', 'payments',
    'agent_logs'
  ])
  loop
    execute format(
      'create policy "%s_admin_all" on public.%I
         for all using (
           company_id = public.get_my_company_id()
           and public.get_my_role() = ''admin''
         )
         with check (
           company_id = public.get_my_company_id()
           and public.get_my_role() = ''admin''
         );',
      t || '_admin_all', t
    );
  end loop;
end $$;

-- employees: admin ve/edita todo; colaborador solo puede VER su propio registro
create policy "employees_admin_all" on public.employees
  for all using (
    company_id = public.get_my_company_id() and public.get_my_role() = 'admin'
  )
  with check (
    company_id = public.get_my_company_id() and public.get_my_role() = 'admin'
  );

create policy "employees_self_select" on public.employees
  for select using (
    company_id = public.get_my_company_id() and user_id = auth.uid()
  );

-- payroll_records: admin ve/edita todo; colaborador solo ve su propio histórico
create policy "payroll_records_admin_all" on public.payroll_records
  for all using (
    company_id = public.get_my_company_id() and public.get_my_role() = 'admin'
  )
  with check (
    company_id = public.get_my_company_id() and public.get_my_role() = 'admin'
  );

create policy "payroll_records_self_select" on public.payroll_records
  for select using (
    company_id = public.get_my_company_id()
    and exists (
      select 1 from public.employees e
      where e.id = payroll_records.employee_id and e.user_id = auth.uid()
    )
  );

-- time_off_requests: admin ve/edita/aprueba todo; colaborador ve y crea las suyas
create policy "time_off_requests_admin_all" on public.time_off_requests
  for all using (
    company_id = public.get_my_company_id() and public.get_my_role() = 'admin'
  )
  with check (
    company_id = public.get_my_company_id() and public.get_my_role() = 'admin'
  );

create policy "time_off_requests_self_select" on public.time_off_requests
  for select using (
    company_id = public.get_my_company_id()
    and exists (
      select 1 from public.employees e
      where e.id = time_off_requests.employee_id and e.user_id = auth.uid()
    )
  );

create policy "time_off_requests_self_insert" on public.time_off_requests
  for insert with check (
    company_id = public.get_my_company_id()
    and exists (
      select 1 from public.employees e
      where e.id = time_off_requests.employee_id and e.user_id = auth.uid()
    )
  );
