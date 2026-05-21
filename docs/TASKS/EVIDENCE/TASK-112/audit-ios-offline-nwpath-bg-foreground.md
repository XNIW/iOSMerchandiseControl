# TASK-112 - Audit iOS Offline NWPath BG Foreground

Timestamp: 2026-05-20 20:34 -0400

## Foreground

- `SupabaseManualSyncForegroundRootHost` avvia foreground semi-automatic check dopo render interattivo e su `scenePhase.active`.
- Ha guard su activity center e task corrente.

Stato: **parziale**.

## NWPath/reconnect

- Nessuna abstraction `NWPathMonitor` trovata nel path auditato.
- Nessuna pipeline esplicita: network intent -> debounce -> auth preflight -> drain -> pull.

Stato: **mancante**.

## Background

- Su background il workflow viene interrotto/cancellato.
- Nessun BGTask automatico auditato per pending drain.

Stato: **parziale/mancante**.

## Verdict

**NO_GO iOS reconnect/offline-first completo**: serve almeno una abstraction di network/reconnect o documentare il limite e mantenere foreground best-effort.
