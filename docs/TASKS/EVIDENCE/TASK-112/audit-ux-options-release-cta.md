# TASK-112 - Audit UX Options Release CTA

Timestamp: 2026-05-20 20:34 -0400

## Scope

Audit statico delle superfici Options iOS/Android prima della rimozione CTA.

## iOS

| File | Stato | Evidenza |
|---|---|---|
| `OptionsView.swift` | mancante | `cloudAccountAndSyncPublicCard` monta `SupabaseManualSyncReleaseCard` quando signed-in/transitioning. |
| `SupabaseManualSyncReleaseCard` | mancante | Espone `primaryAction` e `secondaryAction` da `SupabaseManualSyncPresentationState`. |
| Action handling | mancante | `startRun(for:)` tratta `.syncNow`, `.checkCloud`, `.downloadCloudDatabase` come direct sync/review. |
| Root banner | parziale | Banner foreground non e' Options CTA, ma puo' indirizzare l'utente a Options per azioni review/manuali. |

## Android

| File | Stato | Evidenza |
|---|---|---|
| `OptionsScreen.kt` | mancante | `CatalogCloudSection` contiene `CatalogCloudActionBlock` + `Button(onClick = onRefresh)`. |
| `NavGraph.kt` | mancante | `onCatalogRefresh = { catalogSyncViewModel.refreshCatalog() }`. |
| `CatalogSyncViewModel.kt` | parziale | `refreshCatalog()` e `syncCatalogQuick()` restano entry point manuali; possono restare interni/debug, non pubblici Release. |
| strings | mancante | `catalog_cloud_sync_now` ancora presente come copy pubblico. |

## Copy canonico richiesto

Stato: parziale. Alcune stringhe simili esistono; serve allineare Options status card con:

- "Sincronizzazione automatica attiva"
- "Aggiornamento automatico in corso"
- "Accedi per attivare la sincronizzazione automatica"
- "Modifiche salvate su questo dispositivo. Saranno inviate quando torni online."
- "Connessione ripristinata. Aggiornamento automatico in corso."
- "La connessione e' instabile. Riproveremo automaticamente."
- "Accedi di nuovo per continuare la sincronizzazione."
- "La sincronizzazione richiede un aggiornamento dell'app o del servizio."

## Verdict UX CTA

**NO_GO prima della patch**: entrambe le piattaforme espongono ancora CTA manuali pubbliche in Options Release. La rimozione deve essere una patch mirata di superficie pubblica, mantenendo login/logout e local database status.
