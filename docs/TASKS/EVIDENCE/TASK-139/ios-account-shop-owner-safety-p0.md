# TASK-139 — iOS owner/shop safety P0 e audit statico Android

Data: 2026-07-19
Fase proposta: `REVIEW` (mai `DONE`)
Baseline iOS: `66d90983f8e9ab08dd72184abb4ec70d2c4daefb`
Branch/worktree: `codex/task-139-product-image-hardening` / worktree iOS TASK-139
Drift verificato al checkpoint: `HEAD...origin/main = 0 0`

## Scope e protezione dati

- Correzione iOS del gate proprietario account + shop prima di bootstrap, push, drain o recovery automatici.
- Nessuna mutazione del worktree Android: l'analisi Android sotto è read-only.
- Nessun commit, stage, push, merge o deploy.
- Il simulatore autenticato dell'utente `iPhone 15 Pro Max` e stato aggiornato
  **in-place** con la build finale soltanto dopo i gate statici/unitari. Non e
  stato disinstallato, resettato, disconnesso o usato per fixture; nessuna
  azione distruttiva owner/shop e stata eseguita.
- Tutti i test distruttivi hanno usato esclusivamente SwiftData in-memory e UserDefaults con suite casuale sul simulatore isolato `TASK-139 iPhone 17`.
- Nessuna password, sessione, token o credenziale è stata letta o registrata.

## Root cause iOS

Il binding locale account/shop poteva essere scritto o riscritto da percorsi che non provavano contemporaneamente:

1. identità dell'account autenticato;
2. shop attivo realmente risolto;
3. store locale completamente vuoto;
4. assenza di outbox, pending change e baseline;
5. consenso esplicito prima di eliminare dati locali.

Inoltre il fallback `default` non distingueva un account realmente senza shop da una discovery shop non ancora completata. Il nuovo marker verificato di risoluzione shop chiude questa race fail-closed (`ShopContext.swift:228-294`, `ShopContext.swift:528-577`).

## Correzione iOS

- `AccountBindingStore` salva con readback, confronta account + shop + metadata, non auto-associa uno store non vuoto e mantiene un journal crash-safe per una sostituzione già confermata (`AccountBindingStore.swift:5-183`).
- `SyncDecisionInputProvider` conta prodotti, fornitori, categorie, prezzi, sessioni, pending change, event outbox e baseline; blocca se la discovery shop non è risolta e consente bootstrap solo a store completamente vuoto e già autorizzato (`SyncDecisionInputProvider.swift:89-298`).
- `ShopContextStore` rende la discovery non risolta prima della fetch, persiste/verifica la selezione per account e non modifica mai il binding proprietario (`ShopContext.swift:228-294`, `ShopContext.swift:504-577`).
- `AccountStoreReplacementCoordinator` è l'unico percorso distruttivo nuovo: journal prima della transazione, cancellazione SwiftData, save, binding verificato e recovery deterministica in caso di interruzione (`AccountStoreReplacementCoordinator.swift:25-118`).
- `AccountSyncDecisionView` espone “mantieni dati locali” oppure “elimina e associa” con seconda conferma distruttiva. Se DB o shop context non sono verificabili, l'azione distruttiva non è disponibile (`AccountSyncDecisionView.swift:15-229`).
- `OptionsView` rende il blocco proprietario visibile anche quando i conteggi locali/cloud sembrano allineati e mostra conteggi/outbox/ultimo sync reali (`OptionsView.swift:538-573`, `OptionsView.swift:1489-1540`).
- Il logout mobile usa esplicitamente Supabase `SignOutScope.local`, quindi non revoca le altre sessioni del medesimo account (`SupabaseAuthService.swift:67`, `SupabaseAuthService.swift:95`).
- Conflitti catalogo/prezzi sono isolati per riga: un sibling stale/bloccato non impedisce la push di una riga indipendente eleggibile (`SyncCatalogPushModels.swift:24-28`, `SyncProductPricePushModels.swift:24-27`).
- Una pagina eventi contenente soltanto righe di un altro shop avanza il watermark scoped dello shop selezionato, evitando il refetch infinito senza applicare righe cross-shop (`SyncEventIncrementalDomainApplyService.swift:35-75`).

## Matrice iOS

| Caso | Esito | Evidenza |
|---|---|---|
| Shop context non ancora risolto | PASS unit/static | Nessun binding, bootstrap o sync; `shopContextUnavailable`; test dedicato in `AccountOwnerStoreSafetyTests.swift:9`. |
| Account corrente + shop risolto + store completamente vuoto | PASS unit | Auto-binding verificato allo shop corretto, poi bootstrap. |
| Store unbound con prodotto locale | PASS unit | Review obbligatoria, zero bootstrap/push, binding assente. |
| Store unbound con sola event outbox | PASS unit | Outbox conta come dati locali; review obbligatoria e nessun auto-binding. |
| Binding di account diverso | PASS unit | Blocco `accountMismatch`, binding precedente invariato. |
| Stesso account, shop diverso | PASS unit | Blocco `shopMismatch`, nessun rebind/reset. |
| Outbound business nei tre mismatch | PASS unit | Unbound dirty, account mismatch e shop mismatch restituiscono `.blocked(.accountDecisionRequired)`; spy su catalogo, prezzi, history, pull e activity registra esattamente `0` chiamate. |
| Stesso owner/shop, baseline assente, dati locali presenti | PASS unit | Light reconcile, mai bootstrap distruttivo. |
| Scoperta shop fallita | PASS unit | Marker readiness rimosso, sync bloccata, binding invariato. |
| Elimina e associa | PASS fixture-only | Doppia conferma UI; transazione completa provata soltanto su fixture in-memory. |
| Interruzione dopo cancellazione e prima del binding | PASS unit | Journal completa soltanto lo stesso target e soltanto se lo store è vuoto. |
| Conflitto su sibling catalogo/prezzo | PASS unit | Le righe indipendenti eleggibili vengono inviate. |
| Pagina eventi solo altro shop | PASS unit | Nessuna apply cross-shop e watermark avanzato una volta. |
| Logout su questo device | PASS unit/static | Scope `.local` esplicito; nessuna chiamata default/globale. |
| Build finale sul simulatore autenticato reale | PASS safe in-place | Build device-target `BUILD SUCCEEDED`, installazione senza uninstall/reset, launch riuscito e processo singolo attivo. |
| Preservazione dati reali durante update/launch | PASS exact counts | Conteggi DB privacy-safe invariati prima/dopo install e dopo launch/settle: 1 prodotto, 0 fornitori, 0 categorie, 1 prezzo, 0 sessioni history, 2 pending locali, 0 event outbox. Il path container e cambiato, quindi non si dichiara lo stesso UUID; si dichiara soltanto la preservazione dei dati provata dai conteggi. |
| Options owner-safe sul simulatore autenticato reale | BLOCKED_MAC_LOCKED | La build e avviata e non presenta fatal/uncaught; la navigazione read-only a Options resta bloccata perche il Mac e bloccato e Computer Use non puo sbloccarlo automaticamente. |
| Cancellazione di dati autenticati reali | NOT_RUN safety | Vietata: testata solo con fixture isolata. |

## Audit Android read-only

| Gate | Esito | Evidenza statica |
|---|---|---|
| Primitive owner/store | PARTIAL | `Task126OwnerStoreGate` esiste in `Task126SyncPolicy.kt:66-108` e ha test unitari. |
| Gate collegato al runtime automatico | FAIL P0 | `rg Task126OwnerStoreGate` trova solo policy e test. `CatalogAutoSyncCoordinator.runPushCycle` procede da auth/pending alla push senza invocarlo (`CatalogAutoSyncCoordinator.kt:358-482`). |
| Bootstrap scoped per owner | FAIL P0 | `shouldRunCatalogBootstrap(ownerUserId)` ignora `ownerUserId` e controlla solo `productDao.count() == 0` (`InventoryRepository.kt:2373-2375`). |
| Cambio account/shop senza reset implicito | FAIL P0 | `alignBusinessDataScope` chiama automaticamente il reset quando lo scope cambia o alla prima selezione shop (`MerchandiseControlApplication.kt:462-487`). |
| Preservazione dati locali | FAIL P0 | Il reset elimina tombstone, remote refs, prezzi, history, prodotti, fornitori e categorie in transazione senza review/conferma (`InventoryRepository.kt:2408-2425`). |
| Options mostra mismatch e CTA esplicita | FAIL / non cablato | `AccountCloudSyncSection` mostra auth + `catalogSyncUi`, ma non il gate Task126 o una scelta owner/shop (`OptionsScreen.kt:491-565`). |
| Isolamento conflitti runtime | NOT_VERIFIED | Fuori dalla lane writer Android; nessun PASS dichiarato da sola lettura. |

Conclusione Android: la policy esiste come primitiva ma non governa il percorso runtime che può cancellare dati. Questo blocca l'acceptance cross-platform owner-safe finché la lane Android non corregge e prova il wiring reale.

## Check eseguiti

1. Suite P0 iOS sul solo simulatore isolato:
   - classi: `AccountOwnerStoreSafetyTests`, `AccountSyncPolicyTests`, `SyncDecisionEngineTests`, `OptionsLocalDatabaseCloudStatusTests`, `OptionsSyncSummaryProviderTests`, `ShopContextTests`, `SyncEventIncrementalDomainApplyServiceTests`, `SupabaseAuthSignOutScopeTests`;
   - xcresult: `77 passed`, `0 failed`, `0 skipped`, risultato `Passed`;
   - include la prova runtime-spy di `0` outbound business per unbound dirty/account mismatch/shop mismatch.
2. Test conflitto isolati:
   - catalog sibling bloccato + riga eleggibile;
   - prezzo sibling stale + riga eleggibile;
   - xcresult: `2 passed`, `0 failed`, risultato `Passed`.
3. `xcodebuild ... -destination 'generic/platform=iOS Simulator' build-for-testing`:
   - exit `0`, `TEST BUILD SUCCEEDED` (nel run non-quiet precedente e confermato dal run finale quiet).
4. `plutil -lint` sulle quattro localizzazioni EN/IT/ES/ZH-Hans: tutte `OK`.
5. `git diff --check`: PASS, output vuoto.
6. Smoke in-place sul simulatore autenticato reale:
   - build device-target: exit `0`, `BUILD SUCCEEDED`;
   - installazione con `simctl install` senza uninstall, reset o clear data;
   - conteggi DB esatti invariati pre-install, post-install, post-launch e dopo
     `20 s` di settle;
   - processo app attivo in una sola istanza;
   - log fatal/uncaught: `0`;
   - screenshot post-launch: Inventory normale e dati ancora visibili;
   - apertura Options/Diagnostics: `BLOCKED_MAC_LOCKED`, non promossa a PASS.

### Run non verde da non mascherare

Il tentativo di eseguire l'intera classe legacy `Task118AutomaticDomainTests` ha prodotto exit `65`: tre test preesistenti dello `SyncStateStore` hanno terminato il processo XCTest con `pointer being freed was not allocated` anche quando uno è stato rilanciato singolarmente. I file `SyncStateStore.swift` e quei tre test non sono stati modificati da questo fix. Per questo documento non viene dichiarato un PASS della suite Task118 completa; soltanto i due test di conflitto sopra sono PASS verificati.

## File P0 iOS modificati

- `iOSMerchandiseControl/OptionsView.swift`
- `iOSMerchandiseControl/SupabaseAuthService.swift`
- `iOSMerchandiseControl/Sync/Account/AccountBindingStore.swift`
- `iOSMerchandiseControl/Sync/Account/AccountStoreReplacementCoordinator.swift` (nuovo)
- `iOSMerchandiseControl/Sync/Account/AccountSwitchPolicy.swift`
- `iOSMerchandiseControl/Sync/Account/AccountSyncDecision.swift`
- `iOSMerchandiseControl/Sync/Account/AccountSyncDecisionView.swift`
- `iOSMerchandiseControl/Sync/Automatic/Catalog/SyncCatalogPushModels.swift`
- `iOSMerchandiseControl/Sync/Automatic/Decision/SyncDecisionInputProvider.swift`
- `iOSMerchandiseControl/Sync/Automatic/Presentation/OptionsSyncSummaryProvider.swift`
- `iOSMerchandiseControl/Sync/Automatic/ProductPrice/ProductPricePushService.swift`
- `iOSMerchandiseControl/Sync/Automatic/ProductPrice/SyncProductPricePushModels.swift`
- `iOSMerchandiseControl/Sync/Automatic/Pull/SyncEventIncrementalDomainApplyService.swift`
- `iOSMerchandiseControl/Sync/ShopContext/ShopContext.swift`
- `iOSMerchandiseControl/{en,it,es,zh-Hans}.lproj/Localizable.strings`
- `iOSMerchandiseControlTests/AccountOwnerStoreSafetyTests.swift` (nuovo)
- `iOSMerchandiseControlTests/AccountSyncPolicyTests.swift`
- `iOSMerchandiseControlTests/OptionsLocalDatabaseCloudStatusTests.swift`
- `iOSMerchandiseControlTests/ShopContextTests.swift`
- `iOSMerchandiseControlTests/SyncDecisionEngineTests.swift`
- `iOSMerchandiseControlTests/SyncEventIncrementalDomainApplyServiceTests.swift`
- `iOSMerchandiseControlTests/Task118AutomaticDomainTests.swift`
- `iOSMerchandiseControlTests/SupabaseAuthSignOutScopeTests.swift` (nuovo)

## Rischi residui e handoff

1. **Android P0 in verifica separata:** la lane Android sta completando il
   gate owner/shop e i test host; nessun PASS runtime Android viene anticipato
   da questo documento iOS.
2. **iOS Options live bloccata dal lock del Mac:** update in-place, launch,
   preservazione conteggi e assenza di fatal sono PASS; l'ispezione read-only
   della nuova UI Options/Diagnostics resta `BLOCKED_MAC_LOCKED` finche il Mac
   non viene sbloccato manualmente. Nessuna azione “elimina e associa” verra
   eseguita sul container reale.
3. **Task118 legacy instabile:** i tre crash XCTest vanno triagiati separatamente; non sono coperti dal PASS mirato.
4. Warning Swift 6 preesistenti restano nel target test; la build corrente termina con exit 0.
5. Nessuna prova camera fisica né operazione immagini live è inclusa in questo sotto-scope.

Prossima fase: `REVIEW`; completare l'ispezione read-only Options iOS dopo lo
sblocco del Mac e la verifica Android owner/shop prima di dichiarare verde la
matrice cross-platform.

## Checkpoint coordinato successivo — Android chiuso, iOS ancora bloccato

L'audit Android read-only e i rischi Android sopra sono una fotografia
pre-patch. La lane Android ha successivamente collegato il gate TASK-126 a tutti
i percorsi runtime, introdotto il binding singleton Room owner-hash/shop e
chiuso il test autenticato in-place:

- same-account/same-shop `READY` e session restore: PASS;
- zero outbound su unbound/account mismatch/shop mismatch: PASS;
- cold launch offline con thumbnail reale dalla cache owner/shop-scoped: PASS;
- reconnect con retry automatico del contesto shop e ritorno `READY`: PASS;
- JVM forced `674` totali (`669 PASS`, `5` skip opt-in/live/fixture locale),
  `0` failure/error; assemble app/test APK e lint PASS;
- nessun clear-data, reset, discard/replace o remove/delete reale.

Evidence Android: documento TASK-139 corrispondente nel repository Android.

Il blocker coordinato rimasto è iOS: il container autenticato conserva i dati
ma presenta un binding locale non confermato. La sostituzione è distruttiva e
non è stata eseguita senza consenso esplicito; inoltre il Mac era ancora
bloccato all'ultimo tentativo di ispezione Options/Diagnostics. TASK-139 resta
quindi `REVIEW`, con `BLOCKED_MAC_LOCKED` e decisione replace iOS pendente.

## Appendice correttiva post-scelta — 2026-07-21

Questa appendice supersede esclusivamente le conclusioni correnti sopra; non
riscrive i risultati storici dei run P0.

1. La decisione iOS non è più pendente. Dopo aver sbloccato l'interazione,
   l'utente ha toccato realmente `Sostituisci con dati cloud` sulla build già
   installata. Non è stata chiesta né mostrata una seconda conferma.
2. La UI corrente non usa più il testo storico `elimina e associa` né la doppia
   conferma descritta sopra. La dialog SwiftUI mostra esattamente
   `Mantieni dati locali` e `Sostituisci con dati cloud`; cancel/dismiss
   equivalgono al ramo fail-closed keep-local.
3. Il replace ha portato il locale da `1/0/0/1/0/2/0` a
   `19.734/85/54/10.799/77/0/0` per
   prodotti/fornitori/categorie/prezzi/history/pending/outbox. Account binding,
   shop, login e device identity sono rimasti preservati.
4. Il runtime non è però convergente: staging osservato
   `19.746/83/55/41.158`; orchestrator `idle/noWork`; Diagnostics
   `lastOutcome = completed` e, contemporaneamente,
   `lastError = policyBlocked / sync_event_missing_entity_ids`.
5. Il precedente audit Android `read-only` è superseduto. L'utente ha
   autorizzato una patch UI minima Android esclusivamente per questa dialog;
   policy e transazioni restano quelle esistenti. I gate successivi riportano
   mirati `182/182`, immagini P1 `69/69`, JVM `692` pass + `5` skip su `697`,
   device `4/4`, assemble/lint/diff PASS. Non è stato eseguito un replace
   autenticato Android reale.
6. Le tre instabilità Task118 registrate sopra non sono il risultato finale:
   dopo i fix P1, il gruppo automatic domain è `23/23`; il gate centrale iOS è
   `337` pass + `3` skip opt-in su `340`, zero failure. Il supplementare
   `58/58` è sovrapposto al core `162/162` e non viene sommato.
7. `build-for-testing` è PASS con `8` warning soltanto nei test legacy
   preesistenti. Analyze è PASS con `18` issue esclusivamente in
   `Vendor 2/libxls`, file `xls.c` e `ole.c`.

I fix P1 successivi distinguono journal `prepared/wipeCommitted`, linearizzano
owner/shop con lease TASK-126, catturano `W0` prima dello snapshot, richiedono
tail + reconcile prima del clear e rivalidano righe/batch history, catalogo e
prezzi. L'audit finale ha inoltre dimostrato che `Task.detached` non eredita il
`TaskLocal`: lease esplicite proteggono nove save automatici + outbox, tre
watermark e la baseline catalogo; sessione e result `sync_event` sono validati
su owner/shop esatti. Due test nuovi coprono questo confine. I gate sono stati
eseguiti sul Simulator isolato `2B23…`; xcresult conservato fuori dal
repository. Il candidato non è stato
reinstallato o riapplicato al database reale già sostituito.

Il verdict aggiornato è
`REVIEW_WITH_IOS_POST_REPLACE_CONVERGENCE_BLOCKER / REVIEW`, non `DONE`.
Evidence autorevole:
[`13-post-choice-runtime-checkpoint-ios.md`](13-post-choice-runtime-checkpoint-ios.md).
Nessun secondo replace, reinstallazione, clear-data, reset, commit, stage, push
o deploy; production e Win7POS sono intatti.
