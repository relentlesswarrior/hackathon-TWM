# /app

Referencia y export del proyecto de **Lovable** (frontend + backend/Supabase generado).

- El proyecto vivo se construye y edita en Lovable (lovable.dev).
- Esta carpeta se usa para versionar el export del código generado, configuración de Supabase (migraciones/schema) y notas de sincronización entre Lovable y este repo.

**Link al proyecto Lovable:** https://lovable.dev/projects/b84ea81c-5f97-4b6f-bbb9-5652815eb180 ("Ándale Gestión Empresarial", workspace de Yail, conectado con GitHub)

**Estado:** Lovable generó la base completa a partir de un solo prompt (ver sección "Schema real" abajo): autenticación multi-tenant (signup con correo o Google), empresas con código de invitación para colaboradores, dashboard general y los 4 módulos (CRM, RH, Finanzas, Proveedores) con CRUD funcional. Pendiente: crear la primera cuenta/empresa real y probar el recorrido completo.

## ⚠️ Esquema real vs. esquema propuesto

Lovable **generó su propio esquema de Supabase automáticamente** a partir del prompt (no usamos el SQL de abajo para crearlo). Los nombres de tabla reales en producción son:

`absences`, `agent_logs`, `client_movements`, `clients`, `companies`, `departments`, `employees`, `interactions`, `opportunities`, `payslips`, `profiles`, `supplier_invoices`, `suppliers`, `transactions`, `user_roles`

Esto difiere del diseño que escribimos a mano más abajo (`deals` vs `opportunities`, `vendors`/`vendor_invoices` vs `suppliers`/`supplier_invoices`, `payroll_records` vs `payslips`, `users` vs `profiles`/`user_roles`, etc.). El SQL de `supabase/migrations/` queda como **referencia de diseño** (RLS, lógica de negocio, modelo de datos razonado) pero **no se ha aplicado tal cual** — para activar los triggers/RPC de la sección "Lógica de negocio" hay que adaptarlos a los nombres reales de las tablas, o pedírselo directamente a Lovable por chat describiendo el comportamiento deseado.

## Esquema de base de datos (Supabase)

El esquema completo del MVP (companies, users, clients, deals, client_invoices, interactions, employees, payroll_records, time_off_requests, transactions, vendors, vendor_invoices, payments, agent_logs) con RLS multi-tenant vive en:

- [`supabase/migrations/20261027000000_init_schema.sql`](supabase/migrations/20261027000000_init_schema.sql)

**Cómo aplicarlo:**
1. Crea el proyecto en Lovable (T0.1) — Lovable aprovisiona un proyecto de Supabase automáticamente.
2. Abre ese proyecto de Supabase → **SQL Editor** → pega y corre el contenido completo del archivo de migración.
3. Verifica en **Authentication → Policies** que las políticas RLS quedaron activas en todas las tablas.
4. Al dar de alta la primera empresa, inserta manualmente la fila en `companies` y el primer `users` (`role = 'admin'`) ligado al `auth.users.id` del usuario que se registró en Lovable.

**Notas de seguridad:**
- Todas las tablas están aisladas por `company_id` vía RLS (ver sección 6.4 del PRD/TDR).
- Los roles son `admin` (acceso total a su empresa) y `colaborador` (solo puede ver su propio registro de empleado, nómina y vacaciones — portal de RH).
- `payments.mock_receipt_url` es simulado — no hay movimiento real de dinero (ver sección 5.4 del PRD/TDR).

## Lógica de negocio (triggers, cron, RPC)

Corre después del esquema inicial:

- [`supabase/migrations/20261027000001_business_logic.sql`](supabase/migrations/20261027000001_business_logic.sql)

| Qué hace | Tipo | Dónde se usa |
|---|---|---|
| `mark_overdue_invoices()` | Función + cron diario (pg_cron) | Marca `client_invoices`/`vendor_invoices` como `vencida` automáticamente |
| Trigger en `payments` (insert) | Trigger | Conciliación automática: pago a proveedor → egreso en `transactions` + factura pasa a `pagada` (T4.6) |
| Trigger en `client_invoices` (update → `pagada`) | Trigger | Factura de cliente pagada → ingreso automático en `transactions` |
| `get_cash_flow_summary(company_id, from, to)` | RPC | Dashboard de flujo de caja (Finanzas) |
| `get_cartera_dashboard(company_id)` | RPC | Dashboard de cartera por estatus (CRM) |
| `get_overdue_clients_for_collection(company_id, min_days_overdue)` | RPC | **n8n** consulta esto para decidir a quién llamar el agente de cobranza (T5.1) |
| `get_upcoming_vendor_invoices(company_id, days_ahead)` | RPC | **n8n** consulta esto para la alerta de vencimiento a proveedor (T5.3) |

**`pg_cron` — ✅ habilitado** (2026-10-28) directo en el Supabase del proyecto Lovable, vía Database → Manage → SQL editor:
```sql
create extension if not exists pg_cron with schema extensions;
```
Verificado con `select extname, extversion from pg_extension where extname = 'pg_cron';` → `pg_cron 1.6.4`.

Pendiente: programar el job real (`cron.schedule(...)`) una vez que la lógica de negocio (sección anterior) esté adaptada a los nombres reales de tabla:
```sql
select cron.schedule('mark-overdue-invoices-daily', '0 6 * * *', $$ select public.mark_overdue_invoices(); $$);
```

**Cómo las llama n8n:** vía REST, `POST {SUPABASE_URL}/rest/v1/rpc/<nombre_funcion>` con el header `apikey`/`Authorization` usando la **service_role key** (no la anon key) y el body `{"p_company_id": "...", ...}`. Guarda esa key como credencial en n8n, nunca en el repo.
