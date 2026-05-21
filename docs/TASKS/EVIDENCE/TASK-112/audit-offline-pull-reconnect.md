# TASK-112 - Audit Offline Pull Reconnect

Timestamp: 2026-05-20 20:34 -0400

| Platform | Stato | Evidenza |
|---|---|---|
| Android catalog/prices | parziale | NetworkCallback -> bootstrap/push/sync_events drain; realtime subscriber. |
| Android History | parziale | `HistorySessionPushCoordinator.onNetworkAvailable`; login fresh tick bootstrap+push. |
| iOS catalog/prices/history | parziale | Foreground check/apply services; no NWPath reconnect. |
| Supabase events | parziale | `sync_events` after watermark for catalog/prices only. |

## Gap

- Remote change while device offline -> reconnect pull not verified live.
- Long event gap -> one full reconciliation reason not proven.
- iOS reconnect depends on foreground/session changes, not network callback.

## Verdict

**PARTIAL**: Android has usable reconnect hooks; iOS needs implementation or documented blocker.
