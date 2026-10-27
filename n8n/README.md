# /n8n

Workflows de automatización exportados desde **n8n** (formato JSON).

Workflows planeados (ver `docs/ANDALE-PRD-TDR.md`, sección 5.6 y Épica 5):

| Archivo | Trigger | Acción |
|---|---|---|
| `cobranza-factura-vencida.json` | Factura de cliente vencida X días | Dispara agente de cobranza por voz (ElevenLabs) |
| `alerta-proveedor-por-vencer.json` | Factura de proveedor próxima a vencer | Notificación al dueño (email/Slack/WhatsApp mock) |
| `onboarding-colaborador.json` *(stretch)* | Alta de nuevo colaborador | Checklist de onboarding automático |
| `insight-financiero-semanal.json` *(stretch)* | Cron semanal | Agente financiero genera resumen de flujo de caja |

Cómo exportar un workflow desde n8n: `Workflow → ⋮ → Download`, guardar el JSON en esta carpeta con el nombre correspondiente.

**Instancia de n8n:** _pendiente (cloud o self-hosted + URL)_
