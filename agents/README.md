# /agents

Prompts, configuración y scripts de los agentes de IA de Ándale (ver `docs/ANDALE-PRD-TDR.md`, sección 5.5).

| Carpeta/archivo | Agente | Estado |
|---|---|---|
| [`cobranza-voz/`](cobranza-voz) | Agente de cobranza por voz (ElevenLabs) | ✅ Prompt y config listos |
| `financiero/` | Agente financiero (insights de flujo de caja) | Stretch goal |
| `atencion-interna/` | Agente de atención interna (onboarding) | Post-hackathon |

Cada subcarpeta incluye:
- `prompt.md` — system prompt / guion del agente.
- `config.json` — parámetros (voz, modelo, temperatura, etc.).

## cobranza-voz — listo para crear en ElevenLabs

- [`cobranza-voz/prompt.md`](cobranza-voz/prompt.md) — system prompt completo, primer mensaje, y reglas de tono (amable, nunca agresivo, protección de datos antes de dar el saldo).
- [`cobranza-voz/config.json`](cobranza-voz/config.json) — config de referencia para crear el agente en ElevenLabs Dashboard (Conversational AI → Create Agent) o vía su API. **Reemplaza** `voice_id` antes de usarlo.
- Lo dispara el workflow [`n8n/cobranza-factura-vencida.json`](../n8n/cobranza-factura-vencida.json), que le pasa `client_name`, `balance` y `days_since_last_movement` como variables dinámicas desde la función `get_clients_for_collection` (ya probada en vivo — ver `app/README.md`).
- Sin número de teléfono conectado (Twilio u otro), se puede probar directo en el simulador de conversación de ElevenLabs con las mismas variables.

**Cuenta ElevenLabs:** _pendiente (API key en variables de entorno, nunca en el repo)_
