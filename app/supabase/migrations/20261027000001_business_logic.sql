-- Ándale — Lógica de negocio (triggers, funciones, jobs) sobre el esquema base
-- Corresponde a docs/ANDALE-PRD-TDR.md secciones 5.3, 5.4, 5.6 y Épicas 3, 4, 5
--
-- Depende de: 20261027000000_init_schema.sql (debe correr primero)
--
-- Resuelve 3 cosas que el CRUD autogenerado de Lovable no cubre por sí solo:
--   1) Marcar facturas vencidas automáticamente (cron diario).
--   2) Conciliación automática: pago a proveedor -> egreso en Finanzas (T4.6).
--      Factura de cliente pagada -> ingreso en Finanzas.
--   3) Funciones RPC para los dashboards (flujo de caja, cartera) y para que
--      n8n consulte "a quién cobrarle/avisar" sin tener que reimplementar la
--      lógica de negocio en los workflows.

-- =========================================================
-- 1. Vencimiento automático de facturas (cron diario)
-- =========================================================
create or replace function public.mark_overdue_invoices()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.client_invoices
     set status = 'vencida'
   where status = 'pendiente'
     and due_date < current_date;

  update public.vendor_invoices
     set status = 'vencida'
   where status = 'pendiente'
     and due_date < current_date;
end;
$$;

-- Requiere habilitar la extensión "pg_cron" en Supabase (Dashboard -> Database -> Extensions).
-- Una vez habilitada, programa el job con (ejecutar una sola vez, no es parte del CREATE):
--
--   select cron.schedule(
--     'mark-overdue-invoices-daily',
--     '0 6 * * *',  -- todos los días 06:00 UTC
--     $$ select public.mark_overdue_invoices(); $$
--   );
--
-- Si no quieres depender de pg_cron, n8n también puede llamar a esta función vía
-- RPC (POST /rest/v1/rpc/mark_overdue_invoices) en un workflow con trigger "Schedule".

-- =========================================================
-- 2. Conciliación automática — Pagos a proveedores -> Finanzas (T4.6)
-- =========================================================
create or replace function public.handle_new_payment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice public.vendor_invoices;
begin
  select * into v_invoice from public.vendor_invoices where id = new.vendor_invoice_id;

  insert into public.transactions (company_id, type, category, amount, date, related_table, related_id)
  values (new.company_id, 'expense', 'proveedores', v_invoice.amount, (new.paid_at)::date, 'payments', new.id);

  update public.vendor_invoices
     set status = 'pagada'
   where id = new.vendor_invoice_id;

  return new;
end;
$$;

drop trigger if exists trg_payment_insert on public.payments;
create trigger trg_payment_insert
  after insert on public.payments
  for each row execute function public.handle_new_payment();

-- =========================================================
-- 3. Conciliación automática — Factura de cliente pagada -> Finanzas
-- =========================================================
create or replace function public.handle_client_invoice_paid()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'pagada' and (old.status is distinct from 'pagada') then
    insert into public.transactions (company_id, type, category, amount, date, related_table, related_id)
    values (new.company_id, 'income', 'ventas', new.amount, current_date, 'client_invoices', new.id);
  end if;

  return new;
end;
$$;

drop trigger if exists trg_client_invoice_update on public.client_invoices;
create trigger trg_client_invoice_update
  after update on public.client_invoices
  for each row execute function public.handle_client_invoice_paid();

-- =========================================================
-- 4. RPC — Dashboard de flujo de caja (Finanzas, sección 5.3)
-- =========================================================
create or replace function public.get_cash_flow_summary(
  p_company_id uuid,
  p_from date default (current_date - interval '30 days')::date,
  p_to date default current_date
)
returns table (total_income numeric, total_expense numeric, balance numeric)
language sql
stable
security invoker
set search_path = public
as $$
  select
    coalesce(sum(amount) filter (where type = 'income'), 0)  as total_income,
    coalesce(sum(amount) filter (where type = 'expense'), 0) as total_expense,
    coalesce(sum(amount) filter (where type = 'income'), 0)
      - coalesce(sum(amount) filter (where type = 'expense'), 0) as balance
  from public.transactions
  where company_id = p_company_id
    and date between p_from and p_to
$$;

-- =========================================================
-- 5. RPC — Dashboard de cartera (CRM, sección 5.1)
-- =========================================================
create or replace function public.get_cartera_dashboard(p_company_id uuid)
returns table (status public.client_status, client_count bigint)
language sql
stable
security invoker
set search_path = public
as $$
  select status, count(*) as client_count
  from public.clients
  where company_id = p_company_id
  group by status
$$;

-- =========================================================
-- 6. RPC — Candidatos a cobranza por voz (input del workflow n8n, T5.1)
-- =========================================================
create or replace function public.get_overdue_clients_for_collection(
  p_company_id uuid,
  p_min_days_overdue int default 3
)
returns table (
  client_id uuid,
  client_name text,
  contact_phone text,
  invoice_id uuid,
  amount numeric,
  days_overdue int
)
language sql
stable
security invoker
set search_path = public
as $$
  select
    c.id as client_id,
    c.name as client_name,
    c.contact_phone,
    ci.id as invoice_id,
    ci.amount,
    (current_date - ci.due_date) as days_overdue
  from public.client_invoices ci
  join public.clients c on c.id = ci.client_id
  where ci.company_id = p_company_id
    and ci.status = 'vencida'
    and (current_date - ci.due_date) >= p_min_days_overdue
  order by days_overdue desc
$$;

-- =========================================================
-- 7. RPC — Facturas de proveedor por vencer (input del workflow n8n, T5.3)
-- =========================================================
create or replace function public.get_upcoming_vendor_invoices(
  p_company_id uuid,
  p_days_ahead int default 3
)
returns table (
  vendor_id uuid,
  vendor_name text,
  invoice_id uuid,
  amount numeric,
  due_date date
)
language sql
stable
security invoker
set search_path = public
as $$
  select
    v.id as vendor_id,
    v.name as vendor_name,
    vi.id as invoice_id,
    vi.amount,
    vi.due_date
  from public.vendor_invoices vi
  join public.vendors v on v.id = vi.vendor_id
  where vi.company_id = p_company_id
    and vi.status = 'pendiente'
    and vi.due_date between current_date and (current_date + p_days_ahead)
  order by vi.due_date asc
$$;

-- Nota: las funciones 4-7 son SECURITY INVOKER a propósito, para que respeten
-- las políticas RLS de quien las llama. Si n8n las llama con la service_role
-- key (recomendado para los workflows automatizados), RLS se omite y verá
-- todas las empresas — por eso todas requieren `p_company_id` explícito.
