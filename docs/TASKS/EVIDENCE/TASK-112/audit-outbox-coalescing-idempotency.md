# TASK-112 - Audit Outbox Coalescing Idempotency

Timestamp: 2026-05-20 20:34 -0400

| Area | Stato | Evidenza |
|---|---|---|
| iOS `LocalPendingChange` | parziale | Pending SwiftData con owner/entity/op/status; accumulator presente. |
| iOS `SyncEventOutboxEntry` | parziale | Owner/clientEventID/status/attempt/retry per sync_events. |
| Android `sync_event_outbox` | parziale | Room table owner/clientEventId unique, attempts/error. |
| Android tombstone queue | parziale | `pending_catalog_tombstones` per catalog delete. |
| ProductPrice idempotency | parziale | Remote unique key + local refs; offline replay non provato. |
| History idempotency | parziale | Remote ids/fingerprints, but sync_events no History. |
| Business outbox generale | mancante | Nessuna coda unificata supplier/category/product/ProductPrice/History. |

## Gap

- Atomic local mutation + outbox append non dimostrata.
- Partial ack per item non generalizzato.
- Stable idempotency key non copre tutti i domini nello stesso schema.

## Verdict

**NO_GO per CA-43/56/59** fino a test/fix mirati o blocker documentato.
