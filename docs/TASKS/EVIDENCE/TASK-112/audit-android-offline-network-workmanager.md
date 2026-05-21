# TASK-112 - Audit Android Offline Network WorkManager

Timestamp: 2026-05-20 20:34 -0400

## Connectivity

- `MerchandiseControlApplication.registerNetworkAutoSyncTrigger()` usa `ConnectivityManager.NetworkCallback`.
- Il trigger richiede `NET_CAPABILITY_INTERNET` + `NET_CAPABILITY_VALIDATED`.
- Al reconnect pianifica `catalogAutoSyncCoordinator.onNetworkAvailable()` e `historySessionPushCoordinator.onNetworkAvailable()`.

Stato: **coperto/parziale**. Buona base reconnect, ma non distingue backend unreachable/RLS/schema prima del job.

## WorkManager

- WorkManager e' presente nel progetto e in `MainActivity`, ma non auditato come scheduler del catalog/history sync automatico TASK-112.

Stato: **parziale**. Non e' un blocker per foreground/reconnect, ma manca maintenance periodico/offline-first testabile.

## Threading

- `CatalogAutoSyncCoordinator` e `HistorySessionPushCoordinator` usano `Dispatchers.IO + SupervisorJob`.
- Repository usa `withContext(Dispatchers.IO)` estesamente.

Stato: **coperto** staticamente.

## Gap

- No single orchestrator unico per catalog/prices/history.
- No fake clock/scheduler test per debounce/backoff TASK-112.
- No WorkManager owner-scoped sync constraints verificati.
