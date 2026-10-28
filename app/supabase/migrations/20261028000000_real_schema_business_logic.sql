-- Ándale — Lógica de negocio adaptada al esquema REAL generado por Lovable
-- Corresponde a docs/ANDALE-PRD-TDR.md secciones 5.3, 5.4, 5.6 y Épicas 3, 4, 5
--
-- ✅ Ya aplicado en producción (Supabase del proyecto Lovable) el 2026-10-28,
-- vía Database → Manage → SQL editor. Este archivo es la copia versionada
-- de lo que corre en vivo.
--
-- A diferencia de los archivos 20261027000000/20261027000001 (diseño de
-- esquema propio, nunca aplicado), este usa los nombres de tabla reales que
-- Lovable generó a partir del prompt inicial:
--   companies, profiles, user_roles(app_role: admin|colaborador),
--   clients(status: activo|en_riesgo|moroso), opportunities(stage: ...),
--   interactions, client_movements(kind: cargo|abono — sin due_date/status,
--   es un libro mayor simple, no facturas con vencimiento),
--   departments, employees, absences, payslips,
--   transactions(kind: ingreso|egreso), suppliers,
--   supplier_invoices(status: pendiente|pagada — SIN 'vencida', el check
--   constraint no lo permite; "vencida" se calcula siempre al vuelo como
--   due_date < current_date and status = 'pendiente'), agent_logs.
--
-- Funciones ya existentes en el proyecto (creadas por Lovable, reutilizadas
-- aquí en vez de duplicarlas): current_company_id(), is_company_admin(uuid),
-- is_company_member(uuid), has_role(uuid, app_role), create_company(text,text),
-- join_company(text).

-- =========================================================
-- 1. Conciliación automática — Proveedor pagado -> egreso en Finanzas (T4.6)
-- =========================================================
create or replace function public.handle_supplier_invoice_paid()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'pagada' and (old.status is distinct from 'pagada') then
    insert into public.transactions (company_id, kind, category, amount, description, tx_date)
    values (
      new.company_id, 'egreso', 'proveedores', new.amount,
      concat('Pago factura ', coalesce(new.folio, new.id::text)),
      coalesce(new.paid_at::date, current_date)
    );
  end if;
  return new;
end;
$$;

drop trigger if exists trg_supplier_invoice_paid on public.supplier_invoices;
create trigger trg_supplier_invoice_paid
  after update on public.supplier_invoices
  for each row execute function public.handle_supplier_invoice_paid();

-- =========================================================
-- 2. Conciliación automática — Abono de cliente -> ingreso en Finanzas
-- =========================================================
create or replace function public.handle_client_payment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.kind = 'abono' then
    insert into public.transactions (company_id, kind, category, amount, description, tx_date)
    values (new.company_id, 'ingreso', 'ventas', new.amount, coalesce(new.concept, 'Pago de cliente'), new.movement_date);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_client_payment on public.client_movements;
create trigger trg_client_payment
  after insert on public.client_movements
  for each row execute function public.handle_client_payment();

-- =========================================================
-- 3. RPC — Dashboard de flujo de caja (Finanzas)
-- =========================================================
create or replace function public.get_cash_flow_summary(
  p_company_id uuid,
  p_from date default (current_date - interval '30 days')::date,
  p_to date default current_date
)
returns table (total_income numeric, total_expense numeric, balance numeric)
language sql stable security invoker set search_path = public
as $$
  select
    coalesce(sum(amount) filter (where kind = 'ingreso'), 0) as total_income,
    coalesce(sum(amount) filter (where kind = 'egreso'), 0) as total_expense,
    coalesce(sum(amount) filter (where kind = 'ingreso'), 0) - coalesce(sum(amount) filter (where kind = 'egreso'), 0) as balance
  from public.transactions
  where company_id = p_company_id and tx_date between p_from and p_to
$$;

-- =========================================================
-- 4. RPC — Dashboard de cartera (CRM)
-- =========================================================
create or replace function public.get_cartera_dashboard(p_company_id uuid)
returns table (status text, client_count bigint)
language sql stable security invoker set search_path = public
as $$
  select status, count(*) from public.clients where company_id = p_company_id group by status
$$;

-- =========================================================
-- 5. RPC — Saldo por cliente (estado de cuenta)
-- =========================================================
create or replace function public.get_client_balances(p_company_id uuid)
returns table (client_id uuid, client_name text, balance numeric, last_movement_date date)
language sql stable security invoker set search_path = public
as $$
  select
    c.id, c.name,
    coalesce(sum(cm.amount) filter (where cm.kind = 'cargo'), 0) - coalesce(sum(cm.amount) filter (where cm.kind = 'abono'), 0) as balance,
    max(cm.movement_date) as last_movement_date
  from public.clients c
  left join public.client_movements cm on cm.client_id = c.id
  where c.company_id = p_company_id
  group by c.id, c.name
$$;

-- =========================================================
-- 6. RPC — Clientes candidatos a cobranza (input de n8n, T5.1)
-- =========================================================
create or replace function public.get_clients_for_collection(
  p_company_id uuid,
  p_min_days_since_movement int default 15
)
returns table (client_id uuid, client_name text, phone text, email text, balance numeric, days_since_last_movement int)
language sql stable security invoker set search_path = public
as $$
  select
    c.id, c.name, c.phone, c.email,
    coalesce(sum(cm.amount) filter (where cm.kind = 'cargo'), 0) - coalesce(sum(cm.amount) filter (where cm.kind = 'abono'), 0) as balance,
    (current_date - max(cm.movement_date))::int as days_since_last_movement
  from public.clients c
  join public.client_movements cm on cm.client_id = c.id
  where c.company_id = p_company_id
  group by c.id, c.name, c.phone, c.email
  having coalesce(sum(cm.amount) filter (where cm.kind = 'cargo'), 0) - coalesce(sum(cm.amount) filter (where cm.kind = 'abono'), 0) > 0
     and (current_date - max(cm.movement_date)) >= p_min_days_since_movement
  order by days_since_last_movement desc
$$;

-- =========================================================
-- 7. RPC — Facturas de proveedor por vencer (input de n8n, T5.3)
-- =========================================================
create or replace function public.get_upcoming_supplier_invoices(
  p_company_id uuid,
  p_days_ahead int default 3
)
returns table (supplier_id uuid, supplier_name text, invoice_id uuid, folio text, amount numeric, due_date date)
language sql stable security invoker set search_path = public
as $$
  select s.id, s.name, si.id, si.folio, si.amount, si.due_date
  from public.supplier_invoices si
  join public.suppliers s on s.id = si.supplier_id
  where si.company_id = p_company_id
    and si.status = 'pendiente'
    and si.due_date between current_date and (current_date + p_days_ahead)
  order by si.due_date asc
$$;

-- =========================================================
-- 8. Job diario (pg_cron) — Recalcular riesgo de cartera
-- =========================================================
-- Heurística simplificada para el hackathon: como client_movements no tiene
-- fecha de vencimiento por cargo individual, el riesgo se infiere del saldo
-- pendiente y de cuántos días han pasado desde el último movimiento.
create or replace function public.refresh_client_risk_status()
returns void
language plpgsql security definer set search_path = public
as $$
begin
  update public.clients c
     set status = case
       when bal.balance > 0 and bal.days_since >= 30 then 'moroso'
       when bal.balance > 0 and bal.days_since >= 15 then 'en_riesgo'
       else 'activo'
     end
  from (
    select
      cl.id,
      coalesce(sum(cm.amount) filter (where cm.kind = 'cargo'), 0) - coalesce(sum(cm.amount) filter (where cm.kind = 'abono'), 0) as balance,
      coalesce((current_date - max(cm.movement_date)), 0) as days_since
    from public.clients cl
    left join public.client_movements cm on cm.client_id = cl.id
    group by cl.id
  ) bal
  where c.id = bal.id;
end;
$$;

-- ✅ Ya programado en producción (jobid 1):
select cron.schedule('refresh-client-risk-daily', '0 6 * * *', $$ select public.refresh_client_risk_status(); $$);
