# /app

Referencia y export del proyecto de **Lovable** (frontend + backend/Supabase generado).

- El proyecto vivo se construye y edita en Lovable (lovable.dev).
- Esta carpeta se usa para versionar el export del código generado, configuración de Supabase (migraciones/schema) y notas de sincronización entre Lovable y este repo.

**Link al proyecto Lovable:** https://lovable.dev/projects/b84ea81c-5f97-4b6f-bbb9-5652815eb180 ("Ándale Gestión Empresarial", workspace de Yail, conectado con GitHub)

**Estado:** Lovable generó la base completa a partir de un solo prompt (ver sección "Schema real" abajo): autenticación multi-tenant (signup con correo o Google), empresas con código de invitación para colaboradores, dashboard general y los 4 módulos (CRM, RH, Finanzas, Proveedores) con CRUD funcional. Pendiente: crear la primera cuenta/empresa real y probar el recorrido completo.

## ⚠️ Esquema real vs. esquema propuesto

Lovable **generó su propio esquema de Supabase automáticamente** a partir del prompt (no usamos el SQL de abajo para crearlo). Los nombres de tabla reales en producción son:

`absences`, `agent_logs`, `client_movements`, `clients`, `companies`, `departments`, `employees`, `interactions`, `opportunities`, `payslips`, `profiles`, `supplier_invoices`, `suppliers`, `transactions`, `user_roles`

Esto difiere del diseño original que escribimos a mano antes de conectar Lovable (`deals` vs `opportunities`, `vendors`/`vendor_invoices` vs `suppliers`/`supplier_invoices`, `payroll_records` vs `payslips`, `users` vs `profiles`/`user_roles`, etc. — ver sección "Diseño original" más abajo, nunca aplicado). **La lógica de negocio sí está adaptada y aplicada** sobre el esquema real — ver siguiente sección.

## ✅ Lógica de negocio — aplicada sobre el esquema real (2026-10-28)

- [`supabase/migrations/20261028000000_real_schema_business_logic.sql`](supabase/migrations/20261028000000_real_schema_business_logic.sql)

Ejecutado y verificado directo en el Supabase del proyecto Lovable, vía Database → Manage → SQL editor.

| Qué hace | Tipo | Dónde se usa |
|---|---|---|
| `handle_supplier_invoice_paid()` + trigger `trg_supplier_invoice_paid` en `supplier_invoices` | Trigger | Conciliación automática: factura de proveedor marcada `pagada` → egreso automático en `transactions` (T4.6) |
| `handle_client_payment()` + trigger `trg_client_payment` en `client_movements` | Trigger | Abono (`kind = 'abono'`) de un cliente → ingreso automático en `transactions` |
| `get_cash_flow_summary(company_id, from, to)` | RPC | Dashboard de flujo de caja (Finanzas) |
| `get_cartera_dashboard(company_id)` | RPC | Dashboard de cartera por estatus (CRM) |
| `get_client_balances(company_id)` | RPC | Saldo acumulado por cliente (estado de cuenta) |
| `get_clients_for_collection(company_id, min_days_since_movement)` | RPC | **n8n** consulta esto para decidir a quién llamar el agente de cobranza (T5.1) |
| `get_upcoming_supplier_invoices(company_id, days_ahead)` | RPC | **n8n** consulta esto para la alerta de vencimiento a proveedor (T5.3) |
| `refresh_client_risk_status()` | Función + **cron diario activo** (`jobid 1`, `0 6 * * *`) | Recalcula `clients.status` (activo/en_riesgo/moroso) según saldo pendiente y antigüedad del último movimiento |

**Notas importantes del esquema real:**
- `supplier_invoices.status` solo admite `pendiente` o `pagada` (el CHECK constraint no permite `vencida`) — "vencida" se calcula siempre al vuelo (`due_date < current_date and status = 'pendiente'`), nunca se persiste.
- `client_movements` es un libro mayor simple (`kind`: `cargo`/`abono`, sin `due_date` propio) — el riesgo de cartera (`en_riesgo`/`moroso`) se infiere por saldo pendiente + antigüedad del último movimiento, no por facturas vencidas individuales.
- Se reutilizan las funciones que Lovable ya había creado (`current_company_id()`, `is_company_admin()`, `is_company_member()`, `has_role()`) en vez de duplicarlas.

**`pg_cron` — ✅ habilitado y job activo** (2026-10-28) directo en el Supabase del proyecto Lovable, vía Database → Manage → SQL editor:
```sql
create extension if not exists pg_cron with schema extensions;
```
Verificado con `select extname, extversion from pg_extension where extname = 'pg_cron';` → `pg_cron 1.6.4`. Job `refresh-client-risk-daily` (`jobid 1`) confirmado activo en `cron.job`.

**Cómo las llama n8n:** vía REST, `POST {SUPABASE_URL}/rest/v1/rpc/<nombre_funcion>` con el header `apikey`/`Authorization` usando la **service_role key** (no la anon key) y el body `{"p_company_id": "...", ...}`. Guarda esa key como credencial en n8n, nunca en el repo.

## Diseño original (referencia, nunca aplicado)

Antes de conectar Lovable escribimos un diseño de esquema propio desde cero (`companies`, `users`, `clients`, `deals`, `client_invoices`, `vendors`, `vendor_invoices`, `payments`, `payroll_records`, etc., con RLS multi-tenant y su propia lógica de negocio). Quedó como referencia de modelo de datos razonado, pero **nunca se aplicó** — el esquema real que corre en producción es el que generó Lovable (secciones de arriba). Se conserva en:

- [`supabase/migrations/20261027000000_init_schema.sql`](supabase/migrations/20261027000000_init_schema.sql)
- [`supabase/migrations/20261027000001_business_logic.sql`](supabase/migrations/20261027000001_business_logic.sql)
