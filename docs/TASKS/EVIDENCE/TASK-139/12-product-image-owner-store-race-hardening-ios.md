# TASK-139 — Final review Product Images, owner/store e race iOS

> **Checkpoint storico, verdict superseduto.** Dopo questo documento l'utente ha
> eseguito realmente `Sostituisci con dati cloud`; il runtime non ha dimostrato
> convergenza e sono stati applicati ulteriori fix P1. Stato e gate autorevoli:
> [`13-post-choice-runtime-checkpoint-ios.md`](13-post-choice-runtime-checkpoint-ios.md).
> I risultati sotto restano validi soltanto per il run originario. L'audit
> conclusivo ha poi chiuso la mancata eredità `TaskLocal` di `Task.detached`
> mediante lease esplicite e due test. Gate autorevole: core `162/162`, UX
> `82/82`, Product Images `70 + 3 skip / 73`, automatic `23/23`, totale
> `337 + 3 skip / 340`, zero failure; supplementare sovrapposto `58/58`.
> Build PASS con otto warning legacy; analyze PASS con 18 issue solo
> `Vendor 2/libxls` (`xls.c` / `ole.c`).

Data: 2026-07-19
Fase consegnata: `REVIEW` (mai `DONE`)
Worktree: `codex/task-139-product-image-hardening`
Operazioni Git remote: nessuna; staging, commit, push, merge e deploy non eseguiti.

## Esito

La lane iOS locale/Simulator è verde dopo i fix P0/P1 di autorizzazione
owner/shop, lifecycle, cancellazione, commit boundary e invalidazione delle race
load/mutation. L'ultimo build app completo, successivo anche al fix SwiftData
streaming, termina con `BUILD SUCCEEDED`.

- Matrice Product Images finale: `89` test, `3` skip opt-in, `0` failure,
  exit `0`.
- Matrice owner/conflict/lifecycle: `108` test, `0` skip, `0` failure,
  exit `0`.
- `AccountOwnerStoreSafetyTests`: `17/17`, exit `0`, inclusi dialog source,
  streaming delete source e fixture parent+cascade+prezzo orfano.
- Stress teardown Product Images, tre iterazioni: `9` test, `0` failure,
  exit `0`.
- Nessun test è stato rimosso, disabilitato o escluso per ottenere il verde.

I tre skip della matrice Product Images restano correttamente `NOT_RUN`:

1. parity locale no-image/progressive senza config privacy-safe;
2. replace mutativo senza opt-in esplicito;
3. remove mutativo senza opt-in esplicito.

Non vengono promossi a `PASS`.

## Root cause e fix ProductImageStore

Due run combinati pre-fix avevano terminato il processo XCTest con un invalid
free. Il problema non era nel raster camera: entrambi i crash report convergono
sul teardown implicito MainActor di `ProductImageStore`:

```text
swift::TaskLocal::StopLookupScope::~StopLookupScope
swift_task_deinitOnExecutorImpl
ProductImageStore.__deallocating_deinit
```

Crash report conservati fuori repository:

- `~/Library/Logs/DiagnosticReports/iOSMerchandiseControl-2026-07-19-123342.ips`
- `~/Library/Logs/DiagnosticReports/iOSMerchandiseControl-2026-07-19-123521.ips`

Fix minimo: `nonisolated deinit {}` in `ProductImageStore`. Il deinit non aveva
cleanup applicativo da preservare; task, cache e observer continuano a essere
gestiti dai percorsi espliciti esistenti. Il pattern evita il thunk implicito
`swift_task_deinitOnExecutor` ed è coerente con il workaround già presente nel
repository. Una review indipendente dei due IPS e del diff ha confermato la
causa. Dopo il fix, sia la matrice combinata sia lo stress teardown 3× sono
verdi, senza riduzione di copertura.

## Hardening Product Images applicato

- Gate owner/store esatto su account hash, shop selezionato, `storeId`,
  `localStoreId`, `storeEpoch` e assenza raw di replacement journal, anche se il
  journal non è decodificabile.
- Authorizer production collegato alla sessione Supabase corrente, al binding e
  allo shop; cache, letture, upload e remove falliscono chiusi prima della rete e
  vengono rivalidati dopo ogni await rilevante.
- Scope activation generazionale e cleanup A→B→A: una cleanup vecchia non può
  eliminare uno scope riattivato; uno ShopContext refresh A non può pubblicare
  dopo B né sovrascrivere una selezione manuale più nuova.
- Read batch realmente cancellabili, waiter rimossi prontamente e identità del
  task di load usata per impedire che un task vecchio ripulisca lo stato nuovo.
- Fence mutazione per prodotto e invalidazione epoch chiudono la resurrezione
  di versioni vecchie prima, durante e dopo finalize/remove.
- Commit boundary upload/remove non cancellabile solo dopo l'ultimo controllo
  pre-commit; l'outcome remoto viene preservato anche se scope/UI cambiano.
- Upload finalizzato su scope ormai inattivo non risemina la cache; il fallimento
  pre-commit ricarica la versione precedente se lo scope resta attivo.
- UI Database/Edit espone Product Images solo con scope owner/store autorizzato
  e consente cancel soltanto negli stadi realmente pre-commit.

## Failure SwiftData non mascherato e fix account-lane

Il primo run finale di `AccountOwnerStoreSafetyTests` dopo la richiesta del
reviewer ha prodotto `16 PASS / 1 failure`, exit `65`:

```text
Constraint trigger violation: Batch delete failed due to mandatory OTO
nullify inverse on ProductPrice/product
```

Log e xcresult: artifact esterni del run, non versionati.

Root cause: `ModelContext.delete(model:)` usa una cancellazione SQL che non può
mantenere l'inversa obbligatoria `Product.priceHistory` ↔
`ProductPrice.product`. Il fix autorizzato sostituisce le batch SQL con
`ModelContext.enumerate` object-aware (`batchSize: 256`,
`allowEscapingMutations: true`), nell'ordine:

1. `Product` parent, applicando la cascade;
2. eventuali `ProductPrice` orfani;
3. History, pending, outbox, baseline, Supplier e ProductCategory.

Rimane un solo `context.save()`. In caso di errore l'ordine congelato dal source
test è `context.rollback()` → clear del replacement journal →
`localTransactionFailed`. La fixture verifica sia prezzo relazionato sia prezzo
orfano e tutti i conteggi finali a zero. Nessun container autenticato è stato
toccato.

## Comandi e risultati finali

| Gate | Risultato | Evidence |
| --- | --- | --- |
| `build-for-testing` post streaming | `PASS`, exit `0`, `TEST BUILD SUCCEEDED` | log esterno del run |
| Fixture replacement singola | `1/1`, exit `0` | log e xcresult esterni del run |
| Account owner/store completa | `17/17`, exit `0` | log e xcresult esterni del run |
| Owner/conflict/lifecycle | `108/108`, exit `0` | log e xcresult esterni del run |
| Product Images post streaming | `89` test, `3` skip, `0` failure, exit `0` | log e xcresult esterni del run |
| Stress teardown 3× | `9/9`, exit `0` | log e xcresult esterni del run |
| Build app completo finale | `PASS`, exit `0`, `BUILD SUCCEEDED` | log esterno del run |
| Quattro localizzazioni `plutil -lint` | `PASS`, tutte `OK` | EN/IT/ES/ZH-Hans |
| `git diff --check` | `PASS`, exit `0`, output vuoto | eseguito dopo i fix; rieseguito dopo questo evidence file |
| Staging | vuoto | `git diff --cached --name-only` senza output |
| Artifact scan | nessun artefatto TASK-139 nuovo/modificato nel worktree | build output e nuovi xcresult restano fuori repo |

Il bundle `.app` finale non è stato installato ed è rimasto nell'area build
esterna al repository.

## File della sublane toccati

- `iOSMerchandiseControl/ProductImages/ProductImageContract.swift`
- `iOSMerchandiseControl/ProductImages/ProductImageCache.swift`
- `iOSMerchandiseControl/ProductImages/ProductImageService.swift`
- `iOSMerchandiseControl/ProductImages/ProductImageStore.swift`
- `iOSMerchandiseControl/DatabaseView.swift`
- `iOSMerchandiseControl/EditProductView.swift`
- `iOSMerchandiseControl/iOSMerchandiseControlApp.swift`
- `iOSMerchandiseControl/Sync/Account/AccountBindingStore.swift`
- `iOSMerchandiseControl/Sync/Account/AccountStoreReplacementCoordinator.swift`
- `iOSMerchandiseControl/Sync/ShopContext/ShopContext.swift`
- `iOSMerchandiseControlTests/ProductImages/ProductImageAPIClientTests.swift`
- `iOSMerchandiseControlTests/ProductImages/ProductImageOwnerStoreRaceTests.swift`
- `iOSMerchandiseControlTests/ProductImages/Task139ProductImageAddendumTests.swift`
- `iOSMerchandiseControlTests/AccountOwnerStoreSafetyTests.swift`
- `iOSMerchandiseControlTests/ShopContextTests.swift`
- questo evidence e il relativo indice TASK-139.

Il worktree condiviso contiene anche modifiche precedenti/non appartenenti a
questa sublane: non sono state ripulite, riscritte o attribuite a questo pass.

## Rischi residui e handoff

- I tre opt-in locali sopra restano `NOT_RUN`.
- Camera fisica, staging autenticato ed E2E mutativo live restano
  `BLOCKED_ENV`/`NOT_RUN`; nessun PASS viene anticipato.
- La build finale non è stata installata sul simulatore autenticato
  `459C668B-7CE8-443B-BAB3-7D3D5FFC9143`; installazione e smoke appartengono al
  freeze coordinato del reviewer.
- Nessun commit, stage, push, merge, reset dati, logout o sostituzione dello
  store reale è stato eseguito.

Handoff a `Claude/ChatGPT / Reviewer`. TASK-139 resta `REVIEW`; `DONE` richiede
conferma esplicita dell'utente.
