# TASK-112 - Audit Android Trigger Map

Timestamp: 2026-05-20 20:34 -0400

## Scope

Audit statico read-only dei trigger Android prima di patch applicative.

## File controllati

- `MerchandiseControlApplication.kt`
- `data/CatalogAutoSyncCoordinator.kt`
- `data/HistorySessionPushCoordinator.kt`
- `viewmodel/CatalogSyncViewModel.kt`
- `ui/screens/OptionsScreen.kt`
- `data/InventoryRepository.kt`
- `data/AppDatabase.kt`
- `data/SyncEventModels.kt`
- `ui/components/CloudSyncIndicator.kt`

## Trigger T1-T9

| Trigger | Stato | Evidenza audit | Gap |
|---|---|---|---|
| T1 app launch/restore auth | parziale | `CatalogAutoSyncCoordinator` osserva `authFlow`; signed-in pianifica bootstrap e push. | Non include History nello stesso orchestratore unico; no WorkManager sync. |
| T2 login/cambio account | parziale | Signed-in schedula bootstrap/push; signed-out pulisce dirty hints e resetta bootstrap user. | Account switch con pending owner-scoped non provato live. |
| T3 foreground/resume | coperto | `MerchandiseControlApplication` chiama `onAppForeground`; coordinator schedula bootstrap/push/sync_events drain. | Staleness guard catalogo, ma History usa coordinatore separato. |
| T4 network reconnect | coperto | `ConnectivityManager.NetworkCallback` richiede `NET_CAPABILITY_VALIDATED` e chiama catalog/history reconnect hooks. | Backend reachability e schema/RLS non distinti prima del job. |
| T5 commit locale create/update/delete | parziale | Application wire-up `onProductCatalogChanged`/`onCatalogChanged`; `HistorySessionPushCoordinator.onLocalHistorySessionChanged`. | ProductPrice e delete/tombstone coperti tramite path repo ma non come outbox generale. |
| T6 import/generate | parziale | Repository notifica catalog/history e usa Room source of truth. | Dirty-set post-import grande non provato con fake scheduler. |
| T7 realtime/sync_events | coperto | `SupabaseSyncEventRealtimeSubscriber` chiama coordinator; `runSyncEventDrainCycle` drena watermark/eventi. | `sync_events` copre catalog/prices, non History. |
| T8 maintenance periodica | parziale | WorkManager presente nell'app, ma non per questo orchestratore catalog sync. | Nessuna periodic maintenance TASK-112 owner-scoped. |
| T9 pre-background pending | mancante | `onAppBackground` imposta policy background e i job vengono saltati. | Nessun best-effort pre-background drain. |

## Architettura osservata

- Android ha gia un `CatalogAutoSyncCoordinator` con `Dispatchers.IO`, debounce e single-flight via `CatalogSyncStateTracker`.
- History usa un orchestratore separato `HistorySessionPushCoordinator`.
- Options espone ancora la CTA pubblica `catalog_cloud_sync_now` che chiama `CatalogSyncViewModel.refreshCatalog()`.
- Room e' source of truth locale; esistono remote refs, tombstone queue e sync_event outbox, ma manca un outbox business generale.

## Verdict audit Android

**GO_WITH_IMPLEMENTATION_GAPS**: base automatica piu' avanzata di iOS per catalog/prices, ma non ancora "un solo orchestratore per piattaforma" su tutti i domini e la CTA Release resta pubblica.
