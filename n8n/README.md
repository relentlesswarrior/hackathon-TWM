# /n8n

Workflows de automatización para **n8n** (formato JSON, listos para importar).

## ✅ Construidos (listos para importar)

| Archivo | Trigger | Acción |
|---|---|---|
| [`cobranza-factura-vencida.json`](cobranza-factura-vencida.json) | Cron diario 9am | Busca clientes con saldo pendiente y sin movimientos recientes (`get_clients_for_collection`) → dispara llamada del agente de cobranza (ElevenLabs) → registra el resultado en `agent_logs` |
| [`alerta-proveedor-por-vencer.json`](alerta-proveedor-por-vencer.json) | Cron diario 8am | Busca facturas de proveedor por vencer en los próximos 3 días (`get_upcoming_supplier_invoices`) → notifica al dueño (webhook genérico, por defecto formato Slack) → registra en `agent_logs` |

### Cómo importar

1. En n8n: **Workflows → Import from File** → selecciona el `.json`.
2. Configura las variables de entorno/credenciales que usa el workflow (ver tabla abajo) — en n8n cloud: **Settings → Variables**, o pásalas como variables de entorno si es self-hosted.
3. Activa el workflow (toggle "Active") una vez probado manualmente con **Execute workflow**.

### Variables de entorno requeridas

| Variable | De dónde sale | Usada en |
|---|---|---|
| `SUPABASE_URL` | Supabase del proyecto Lovable → Settings → API | Ambos workflows |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase → Settings → API → `service_role` (secreta, nunca la `anon`) | Ambos workflows |
| `ANDALE_COMPANY_ID` | `select id from companies;` en el SQL editor de Lovable | Ambos workflows |
| `ELEVENLABS_API_KEY` | ElevenLabs → Profile → API Keys | Cobranza |
| `ELEVENLABS_AGENT_ID` | ElevenLabs → Conversational AI → tu agente | Cobranza |
| `ELEVENLABS_PHONE_NUMBER_ID` | ElevenLabs → Phone Numbers (requiere número conectado, ej. vía Twilio) | Cobranza |
| `NOTIFY_WEBHOOK_URL` | Slack incoming webhook (o el canal que elijas) | Alerta proveedor |

**Nota sobre el endpoint de ElevenLabs:** el workflow de cobranza usa `POST /v1/convai/twilio/outbound-call` como ejemplo — es el patrón de llamada saliente de ElevenLabs Conversational AI vía Twilio. Si tu cuenta usa otro método de llamada, ajusta ese nodo (`Llamar con ElevenLabs`) en consecuencia. Ver [`agents/cobranza-voz/`](../agents/cobranza-voz) para el prompt del agente.

**Probado:** las funciones RPC que consumen estos workflows (`get_clients_for_collection`, `get_upcoming_supplier_invoices`) y el trigger de conciliación automática ya se verificaron funcionando en vivo contra el Supabase del proyecto (ver `app/README.md`).

## Pendientes (stretch goals)

| Archivo | Trigger | Acción |
|---|---|---|
| `onboarding-colaborador.json` | Alta de nuevo colaborador | Checklist de onboarding automático |
| `insight-financiero-semanal.json` | Cron semanal | Agente financiero genera resumen de flujo de caja |

**Instancia de n8n:** _pendiente (cloud o self-hosted + URL)_
