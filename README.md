# Ándale

Plataforma de gestión end-to-end para pequeñas y medianas empresas de LatAm (CRM, RH, Finanzas y Pagos a proveedores), con agentes de IA que automatizan tareas administrativas. Proyecto construido para el hackathon **TWM**.

## Documentación

- 📄 **[PRD + TDR completo](docs/ANDALE-PRD-TDR.md)** — problema, requisitos funcionales, arquitectura, modelo de negocio, roadmap de 48h y backlog de tickets por épicas.

## Estructura del repo

```
hackathon-TWM/
├── docs/     # PRD, TDR, modelo de negocio, pitch deck
├── app/      # Referencia/export del proyecto Lovable (frontend + Supabase)
├── n8n/      # Workflows de automatización (JSON)
├── agents/   # Prompts y configuración de agentes de IA (ElevenLabs, LLM)
└── README.md
```

## Stack

**Lovable** (frontend + backend/Supabase) · **n8n** (automatización) · **ElevenLabs** (agente de voz) · **Linear** (roadmap post-hackathon)

## Empezar a trabajar

El backlog de tickets (organizado en 8 épicas: Setup, CRM, RH, Finanzas, Pagos a proveedores, Agentes+n8n, Integración/QA, Pitch) está en la [sección 10 del PRD/TDR](docs/ANDALE-PRD-TDR.md#10-backlog-de-tickets-para-importar-a-linear). Úsalo para crear los issues/tickets en Linear o GitHub Issues antes de arrancar el sprint.
