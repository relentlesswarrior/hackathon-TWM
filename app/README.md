# /app

Referencia y export del proyecto de **Lovable** (frontend + backend/Supabase generado).

- El proyecto vivo se construye y edita en Lovable (lovable.dev).
- Esta carpeta se usa para versionar el export del código generado, configuración de Supabase (migraciones/schema) y notas de sincronización entre Lovable y este repo.
- Agrega aquí el link al proyecto de Lovable una vez creado.

**Link al proyecto Lovable:** _pendiente_

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
