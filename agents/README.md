# /agents

Prompts, configuración y scripts de los agentes de IA de Ándale (ver `docs/ANDALE-PRD-TDR.md`, sección 5.5).

| Carpeta/archivo | Agente | Estado |
|---|---|---|
| `cobranza-voz/` | Agente de cobranza por voz (ElevenLabs) | Must-have |
| `financiero/` | Agente financiero (insights de flujo de caja) | Stretch goal |
| `atencion-interna/` | Agente de atención interna (onboarding) | Post-hackathon |

Cada subcarpeta debe incluir:
- `prompt.md` — system prompt / guion del agente.
- `config.json` — parámetros (voz, modelo, temperatura, etc.).

**Cuenta ElevenLabs:** _pendiente (API key en variables de entorno, nunca en el repo)_
