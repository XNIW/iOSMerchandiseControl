# TASK-112 - Audit Offline-First Contract

Timestamp: 2026-05-20 20:34 -0400

| Requisito | Stato | Evidenza/gap |
|---|---|---|
| Commit locale prima del successo UI | parziale | Room/SwiftData locali sono source of truth, ma outbox atomica non provata. |
| Outbox owner-scoped | parziale | Android/iOS sync_events outbox owner-scoped; business outbox generale mancante. |
| Idempotency key stabile | parziale | `client_event_id` sync_events; ProductPrice unique. Non tutti i domini. |
| Coalescing update | parziale | Android dirty hints e debounce; iOS pending accumulator. |
| create+update compaction | parziale | Pending accumulator iOS parziale; Android remote refs/revisions. |
| create+delete no-op/tombstone | parziale | Tombstone catalogo Android/Supabase; iOS/offline not proven. |
| Partial ack | mancante | Nessuna lane generale per batch partial ack auditata. |
| Retry lanes | parziale | sync_events outbox retry attempts; no domain-wide lanes. |
| Dependency ordering | parziale | Sync paths ordinano catalog/prices/history, ma non queue esplicita unica. |
| Reconnect drain+pull | parziale | Android network callback; iOS NWPath missing. |

## Verdict

**NO_GO offline-first completo** al momento dell'audit. Implementare patch UI/status e test mirati e lasciare blocker dove la struttura richiede lavoro architetturale piu' ampio.
