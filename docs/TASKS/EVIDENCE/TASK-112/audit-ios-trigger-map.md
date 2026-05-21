# TASK-112 - Audit iOS Trigger Map

Timestamp: 2026-05-20 20:34 -0400

## Scope

Audit statico read-only dei trigger iOS prima di patch applicative.

## File controllati

- `iOSMerchandiseControl/OptionsView.swift`
- `iOSMerchandiseControl/ContentView.swift`
- `iOSMerchandiseControl/SupabaseManualSyncViewModel.swift`
- `iOSMerchandiseControl/SupabaseManualSyncLifecycleRunGate.swift`
- `iOSMerchandiseControl/SupabaseManualSyncReleaseFactory.swift`
- `iOSMerchandiseControl/LocalPendingChange.swift`
- `iOSMerchandiseControl/SyncEventOutboxEntry.swift`
- `iOSMerchandiseControl/HistorySessionSyncService.swift`
- `iOSMerchandiseControl/SupabaseProductPriceApplyService.swift`

## Trigger T1-T9

| Trigger | Stato | Evidenza audit | Gap |
|---|---|---|---|
| T1 app launch/restore auth | parziale | `SupabaseManualSyncForegroundRootHost.task` avvia `startForegroundSemiAutomaticCheckIfAllowed` dopo render interattivo. | Esegue soprattutto check/preview e non un orchestratore unico offline-first completo. |
| T2 login/cambio account | parziale | `onChange` su `sessionInfo.userID`/`isSignedIn` resetta stato e riparte foreground check. | Account boundary non dimostrato per outbox/pending/baseline owner-scoped in recovery. |
| T3 foreground/resume | parziale | `scenePhase == .active` chiama foreground check con gate/busy guard. | Freshness incrementale completa e reason code target TASK-112 non centralizzati. |
| T4 network reconnect | mancante | Non trovato `NWPathMonitor` o abstraction equivalente nel path sync pubblico. | Reconnect push/pull automatico iOS non dimostrato. |
| T5 commit locale create/update/delete | parziale | `LocalPendingChange` e accumulator esistono; callback UI non auditata come orchestratore automatico unico. | Drain automatico generalizzato post-commit non provato. |
| T6 import/generate | parziale | Esistono pending/import batch e history/session service. | Dirty-set affidabile post import/generate non verificato end-to-end. |
| T7 realtime/sync_events | parziale | `SyncEventOutboxEntry`, enqueue/drain/recorder e RPC mapper esistono. | Nessun realtime subscriber iOS osservato; pull delta da eventi remoti non coperto. |
| T8 maintenance periodica | mancante | Nessun scheduler/BGTask automatico auditato come parte sync. | Solo best-effort foreground; niente maintenance testabile. |
| T9 pre-background pending | parziale | Su background viene chiamato cancel/interrupt del workflow foreground. | Nessun best-effort push prima del background; pending preservati ma non drenati. |

## Architettura osservata

- Unico entry point automatico visibile: `SupabaseManualSyncForegroundRootHost`.
- Nome e superfici restano "manual sync"; l'adapter Release usa `SupabaseManualSyncReleaseFactory`.
- `SupabaseManualSyncLifecycleRunGate` fornisce single-flight/cancel/ready-to-retry parziale.
- `SupabaseManualSyncViewModel` e molte chiamate UI sono `@MainActor`; i servizi ProductPrice hanno gia ricevuto hardening storico con background context, ma l'orchestrazione resta main-actor-bound.

## Verdict audit iOS

**GO_WITH_IMPLEMENTATION_GAPS**: iOS ha una base di foreground semi-automatic check, pending locali e sync_events outbox, ma mancano reconnect/network abstraction, orchestratore automatico esplicito offline-first e rimozione della CTA pubblica in Release.
