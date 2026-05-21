# TASK-112 - Audit Conflict Policy And Invariants

Timestamp: 2026-05-20 20:34 -0400

## Invarianti osservate

| Area | Stato | Evidenza |
|---|---|---|
| Owner boundary Supabase | coperto | Tabelle principali con `owner_user_id` e RLS `auth.uid() = owner_user_id`. |
| ProductPrice dedupe | coperto | Unique remote `(owner_user_id, product_id, type, effective_at)`; local unique index Room. |
| Catalog tombstone wins | parziale | Supabase blocca update post-tombstone catalogo; client conflict offline non provato. |
| History tombstone | parziale | `shared_sheet_sessions.deleted_at` + updated_at trigger TASK-110. |
| No orphan ProductPrice | parziale | FK remote product_id e local remote refs; offline dependency wait non provata. |
| No duplicate History/session | parziale | Remote ids/fingerprint storici presenti; replay/offline retry non provati. |

## Conflict policy

| Scenario | Stato | Nota |
|---|---|---|
| update vs update stesso prodotto | mancante | Nessuna policy deterministica auditata come codice comune. |
| tombstone vs update | parziale | Backend catalog tombstone protegge da resurrection; UI/client ordering da provare. |
| offline local vs remote while offline | mancante | Reconnect conflict policy non verificata. |
| account switch with pending | parziale | Owner-scoped RLS/pending parziale, recovery non provata. |

## Verdict

**NO_GO per conflict completeness**: gli invarianti DB sono buoni, ma la policy cross-platform/offline non e' ancora evidence-backed.
