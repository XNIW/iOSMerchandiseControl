# Audit funzionale indipendente — 2026-09-28

Reviewer: agente `independent_reviewer`, separato dagli executor Android/iOS. Prima fase: ispezione sorgente read-only; nessuna build/test avviata e nessuna modifica ai repository. Baseline assegnate: Android `d7c4953c4ed6bc2a33cc5dbfd009eb862f70feac`, iOS `30d226d0fb9b8679a1dd034c6e82319645337f22`. Worktree: `/Users/minxiang/.codex/worktrees/mobile-parity-root-cause/{MerchandiseControlSplitView,ios}`. Questo documento non è ancora la review del diff finale.

Letti richiesta utente allegata, AGENTS/CLAUDE, master, task Android 142/iOS 143 e protocolli execution. L'override utente corrente autorizza audit funzionale e agenti separati; task storici non sono stati riaperti dal reviewer. Documentazione storica non trattata come test attuale.

## Rilievi nuovi da riprodurre prima del fix

### R-A01 — P1: editor operativo Android riscrive i campi remoti non modificati dall'utente

Percorso: `ui/screens/DatabaseScreen.kt:515` passa il target iniziale; `EditProductDialog.kt:152–159` conserva campi con `rememberSaveable(sessionId)`, poi `:938–949` crea una copia completa del prodotto; `viewmodel/DatabaseViewModel.kt:persistProductFromEditor` chiama `repository.updateProduct(product)`; `data/InventoryRepository.kt:709–744` legge il prodotto corrente ma esegue `productDao.update(canonicalProduct)` pieno e calcola dirty current→form stale.

Riproduzione deterministica proposta: aprire editor con nome Old/prezzo 10; applicare pull remoto a prezzo 20; modificare soltanto nome New nel form originario; salvare. Dal percorso sorgente il prezzo viene rimesso a 10, marcato dirty e può creare price history 10. Non c'è diff iniziale→form o confronto sovrapposizione con current. La cancellazione degli scope non risolve un aggiornamento remoto nello stesso shop.

Controparte iOS: `EditProductView.swift:save`, righe 822–882, calcola cambi iniziale→form e iniziale→fresh, verifica `Task126ConflictResolver`, applica solo campi utente cambiati. Test da aggiungere Android: merge disjoint, conflitto stesso campo fail-closed, remote delete, zero dirty/history sugli invariati. Evidenza corrente STATIC; il reviewer non ha eseguito questo scenario.

### R-A02 — P1: anagrafica Android e dirty marker non atomici

`InventoryRepository.kt:addSupplier` (869), `addCategory` (1108), `createCatalogEntry` (916), `renameCatalogEntry` (934) separano insert/rename da `touchSupplierDirty`/`touchCategoryDirty` (6304/6317), senza `db.withTransaction`. `withLocalBusinessMutation` (581–588) è una scope lease, non transazione. `deleteCatalogEntry` invece racchiude già le scritture in transazione.

Riproduzione deterministica proposta: supplier già sincronizzato, installare trigger SQLite `BEFORE UPDATE ON supplier_remote_refs` con `RAISE(ABORT,'injected')`, poi rename. L'API fallisce ma il nuovo nome resta committato e revision non cresce; il remoto può poi sovrascriverlo. Ripetere category e creazione. Patch minima suggerita: transazioni Room attorno a write anagrafica e dirty marker, callback dopo commit. Test successo esistenti: `DefaultInventoryRepositoryTest` rename 1913, generic notification 2069; manca fault injection per queste API. Evidenza corrente STATIC, non test eseguito.

## Matrice capacità / sorgenti / test esistenti

Prefissi Android: `app/src/main/java/com/example/merchandisecontrolsplitview/` e `app/src/test/java/com/example/merchandisecontrolsplitview/`. Prefissi iOS: `iOSMerchandiseControl/`, `iOSMerchandiseControlTests/`. Tutti i test qui elencati sono stati soltanto individuati/letti, quindi **NOT_TESTED da questo reviewer**; l'orchestratore deve aggiungere le evidenze effettive della run corrente. `VERIFIED` non è assegnato per sola presenza del codice.

| Capacità / requisito | Android reale | iOS reale | Backend necessario | Test esistenti / stato e rischio |
|---|---|---|---|---|
| Inventario: file→preview→generazione→griglia | `ExcelViewModel.loadFromMultipleUris`, `generateFilteredWithOldPrices`; `PreGenerateScreen`, `GeneratedScreen` | `ExcelSessionViewModel.load`, `generateHistoryEntry`; `PreGenerateView`, `GeneratedView` | Nessuno per uso locale; session contract per sync | `ExcelViewModelTest`, `PreGenerateEntityResolutionTest`; iOS `Task105RealOpsClosureTests`, `Task111ExcelImportParityTests`. NOT_TESTED |
| Salva/annulla inventario, ritorno navigazione | `saveCurrentStateToHistory`, `revertToPreGenerateState`, `GeneratedExitDestinationResolver` | `GeneratedView`, `HistoryEntry` autosave/session persistence | History/session sync per altro device | `GeneratedExitDestinationMatrixTest`, `ImportNavOriginTest`, `ExcelViewModelTest`; iOS `HistorySessionSyncServiceTests`, `InventorySyncServiceTests`. NOT_TESTED |
| Salva editor prodotto, errore, retry/doppio tap | `EditProductDialog`→`startProductEditorSave`→`persistProductFromEditor`→repository transazione prodotto/prezzi/dirty | `EditProductView.save`→`Task126OwnerStoreGate.withLocalMutationFence`→freshContext save prodotto/pending | Offline locale permesso; auto sync dopo commit | Android `DatabaseViewModelTest` failure/retry/post-commit reread/recreation; iOS owner-store/conflict tests. NOT_TESTED; rischio R-A01 da riprodurre |
| Database ricerca/barcode/paginazione | `DatabaseViewModel`, Room Paging/`ProductDao`; scanner ZXing `ScanOptions` | `DatabaseView.filteredProducts`, `@Query Product`, `BarcodeScannerView` AVCapture | Summary RPC solo filtri Storefront | Android search debounce/scanner stale-scope test; iOS `Task105RealOpsClosureTests.testPhysicalCameraBarcodeCaptureCapabilityWhenAvailable` opt-in/capability. NOT_TESTED; iOS filtro locale full-list richiede misura |
| Fornitore/categoria create/rename/assign | `createCatalogEntry`, `renameCatalogEntry`, `addSupplier`, `addCategory`, editor quick-create atomic UI gate | `DatabaseNamedEntityEditorView.save`, `saveSupplier`, `saveCategory`; editor form crea relazione insieme al prodotto | Catalog push/pull e identità remote | Android `DefaultInventoryRepositoryTest` 1817–1936 e `DatabaseViewModelTest`; iOS `CatalogTextIntegrationTests`, `LocalPendingChangeAccumulatorTests`. NOT_TESTED; R-A02 da riprodurre |
| Fornitore/categoria replace/delete con riferimenti | `deleteCatalogEntry` transazione, `ReplaceWithExisting`, `CreateNewAndReplace`, `ClearAssignments` | `DatabaseView.deleteEntity`, `createReplacementAndDelete`, mutation fence | Tombstone + catalog deps | Android test reassign/clear e dirty-field-only; iOS `Task118AutomaticDomainTests` tombstones, `SyncEventIncrementalDomainApplyServiceTests` relation rollback. NOT_TESTED |
| Prezzi e history prezzi | `updateCurrentPriceFromHistory` transazione, ProductPrice key effettiva univoca | `ProductPriceHistoryView.save` fresh-context conflict guard + prezzo corrente + pending | ProductPrice remote contract | Android `Task130PriceContractTest`, repository history tests; iOS `Task130PriceContractTests`, `SupabaseProductPriceApplyServiceTests`. NOT_TESTED |
| History entry rename/delete/filter/group | `ExcelViewModel.renameHistoryEntry/deleteHistoryEntry`; `HistoryScreen`; repository user-visible DAO | `HistoryView`, `HistoryMonthGrouping`, `HistorySessionSyncService` | Session V2 + tombstone | `ExcelViewModelTest`, repo filtered history; iOS `HistoryViewStateTests`, `HistoryMonthGroupingTests`, `HistorySessionSyncServiceTests`. NOT_TESTED |
| Import analisi/conferma/errori/no-op | `DatabaseViewModel.startSmartImport/importProducts`; `InventoryRepository.applyImport` con transaction/mutex; `ImportAnalyzer` | `DatabaseView.applyImportAnalysisInBackground`, `applyConfirmedImportAnalysis`; `ProductImportCore` | Nessuno per apply locale; sync solo delta operativo | Android `FullDbExportImportRoundTripTest` reimport same workbook no-op, VM double-confirm/recovery; iOS `Task105RealOpsClosureTests`, `Task111ExcelImportParityTests`, `CatalogTextIntegrationTests`. NOT_TESTED; harness Excel sospeso non riattivato |
| Import/export numeri CL, barcode zero, Unicode, footer | `ClNumberFormatters`, `ExcelUtils`, `DatabaseExportWriter` | `ProductImportCore`, `ExcelSessionViewModel/ExcelAnalyzer`, `InventoryXLSXExporter` | Nessuno per round-trip | Android `ClNumberFormattersTest`, `ExcelUtilsTest`, `FullDbExportImportRoundTripTest`; iOS `Task141NumericInputTests`, `Task111ExcelImportParityTests` numeric barcode leading zero, `Task105RealOpsClosureTests` round-trip. NOT_TESTED |
| Immagini camera/galleria/preparazione/preview/upload | `EditProductDialog`; `ProductImageProcessor`, `ProductImageService`, staged file store | `EditProductView`; `ProductImageProcessor`, `ProductImageStore`, `ProductImageAPIClient`; decode `Task.detached` | Pipeline Product Images/route contrattuali | Android `ProductImageProcessorTest`, `ProductImageServiceTest`, VM progressive/cancel/retry/staged recovery, device suites; iOS `ProductImages/*Tests`, owner-store races. NOT_TESTED |
| Immagine nuovo prodotto | Android selezione prima del primo save, `PendingStagedProductImageStore` durevole, upload dopo stable remote ref | iOS `EditProductView.productImageSection` mostra `save_first` finché esistente con remoteID, selezione dopo save/sync | Stable remote ID richiesto per upload | INTENTIONAL_PLATFORM_DIFFERENCE candidata: percorso diverso già presente, stessa associazione finale; non classificare nuova feature mancante senza requisito. Runtime NOT_TESTED |
| Sostituzione/rimozione/cache immagini | `ProductImageService.upload/remove/purgeScope`; UI conserva current su failure e scoped thumbnails | `ProductImageStore.activate(scope:)`, mutation generation; `EditProductView.uploadPendingImage/removeCurrentImage` | ACK immagini, URL finalizzate e version ID | Android VM stale completion/scope removal/purge tests; iOS `ProductImageOwnerStoreRaceTests`, `ProductImageCacheTests`, `Task139ProductImageAddendumTests`. NOT_TESTED |
| Login/logout/startup/shop/permessi | `SupabaseAuthManager`; application auth/shop observers, `Task126BusinessDataScopeRuntimeGuard`; business content gate | `SupabaseAuthViewModel`; `ShopContext`; `AccountStoreReplacementCoordinator`, `Task126OwnerStoreGate` | Auth, shop/device authorization, RLS/RBAC già esistenti | Android auth/shop/scope boundary/runtime guard tests; iOS `SupabaseAuthSignOutScopeTests`, `ShopContextTests`, `AccountOwnerStoreSafetyTests`. NOT_TESTED; live credenziali/staging EXTERNAL_DEPENDENCY |
| Trigger automatici locali/reconnect/foreground | application wiring `onProductCatalogChanged`→`CatalogAutoSyncCoordinator.onLocalProductChanged`; generic catalog; history coordinator; network callback | `LocalPendingChangeAccumulator` notification→`ContentView`→`SyncOrchestrator.handleLocalPendingChanges`; foreground/reconnect | Catalog/prices/session/events | Android `CatalogAutoSyncCoordinatorTest` debounce500ms, busy retries, bounded poll, scope; iOS `Task119AutomaticArchitectureTests`, `AutomaticSyncReconnectSchedulerTests`. NOT_TESTED; nessun target 3s misurato |
| Outbox, idempotenza, push/pull/tombstone/conflitti | repository dirty refs/tombstones/event outbox, recovery coordinator, scope lease | `LocalPendingChange`, `SyncAutomaticEngine`, per-domain push/apply, `WatermarkStore`, recovery generation | Shop-scoped read/recovery/events contracts | Android repository/coordinator/scope/recovery suites; iOS `Task118AutomaticDomainTests`, `SyncEventIncrementalDomainApplyServiceTests`, `AtomicGenerationRecoverySnapshotPullServiceTests`. NOT_TESTED; R-A01/R-A02 rilevanti |
| Background, sospensione, force-stop | ProcessLifecycle/foreground loop, reconnect; WorkManager backfill prezzi non prova sync completa in background | `SyncBackgroundTaskScheduler` BGAppRefresh earliest15min, expiration cancella, ritorno foreground recupera | Device/auth + cloud access disponibile | INTENTIONAL_PLATFORM_DIFFERENCE di scheduling OS; determinismo background non promesso. Test force-stop recovery Android presenti; iOS architecture/background source inspected. NOT_TESTED |
| Storefront draft/publish/schedule/hide/archive/conflict | `DatabaseViewModel` + `StorefrontAuthoringContract`; stable remote ID + server ACK | `StorefrontAuthoringStore`, service, `StorefrontAuthoringViews`; same RPC | `storefront_publication_authoring_mutate_v1`, read/summary/bind session | `StorefrontDatabaseViewModelTest`, contract + Compose; iOS `StorefrontAuthoringTests`, `StorefrontEditorUITests`. F01–F03 executor in corso, NOT_TESTED reviewer |
| Storefront prezzo/categoria/immagini/import isolation | editor sezione separata, esplicito align, public image adoption; import contract non contiene publication | stessa separazione, public variant finale, mutate esplicito | Authoring RPC + `storefront/images/adopt` | Storefront contract/state/image/import tests su entrambe. NOT_TESTED |
| IT/EN/ES/ZH, accessibility, empty/loading/error | `values*`, strings semantiche, Compose accessibility; empty filtro reset | `*.lproj/Localizable.strings`, Dynamic Type/accessibility IDs, filter empty reset | Nessuno | Android `StorefrontLocalizationTest`, `CrossPlatformReliabilityPresentationTest`, Compose suites; iOS `LocalizationCoverageTests`, Storefront XCUITest. NOT_TESTED |

## Traccia sync e limiti

Android: Dialog/VM → repository + Room commit/dirty/tombstone → callback application → CatalogAutoSyncCoordinator (500ms debounce locale) / HistorySessionPushCoordinator → remote ACK → event/outbox → pull/apply scoped → Flow/Paging/override puntuale → UI. Il coordinatore è inizializzato eager in `MerchandiseControlApplication.onCreate`.

iOS: View → owner-store mutation fence/fresh SwiftData context → business mutation + LocalPendingChange → commit → notification ricevuta da ContentView → SyncOrchestrator → automatic engine per dominio → remote ACK/event → incremental apply/watermark/generation → SwiftData UI. Non serve una CTA manuale nel normale percorso osservato staticamente.

Il giro completo tra app e confronto canonico per record NON è stato eseguito dal reviewer. Suite live presenti (`Task103CrossPlatformAcceptanceTests`, `Task072*`, Android device harness) hanno gate opt-in e non vanno contate come eseguite per una suite verde che le salta. Nessuna misura p50/p95/max; codice iOS full-fetch editor/search è solo hotspot candidato. Nessuno scan globale security, deploy, cleanup dati o harness Excel riattivato.

## Handoff

1. Executor Android: riprodurre R-A01/R-A02 con test rossi, quindi correzione minima nel batch autorizzato e regressioni adiacenti.
2. Orchestratore: integrare matrice con risultati reali della run corrente, separando app locale, staging/device e merge.
3. Reviewer: attendere diff congelato e relativi log. Review indipendente coordinata del diff intero; un batch fix + re-review; nessuna approvazione anticipata.

## Review coordinata — slice integrità Android (2026-09-28)

Avvio richiesto dall'orchestratore sulle fonti stabili, senza modifica codice e senza build parallele. Letti diff `InventoryRepository.kt`, nuova `ProductEditConflictException.kt`, tutti i 15 casi `OperationalMutationIntegrityTest.kt`, callsite operativo attuale `DatabaseViewModel.saveProductFromEditor` e `ProductWithDetails`/DAO per verificare la provenienza dei prezzi.

- R-A01: merge dei 9 campi modificabili contro baseline immutabile e current nella stessa transazione; proprietà immagine e history preesistenti preservate; overlap con valori differenti e prodotto rimosso falliscono senza commit. Stesso valore concorrente e form invariato sono no-op. Inserimento price history limitato al delta prezzo effettivo: il pull catalogo arrivato prima della history non genera storia manuale fittizia.
- R-A02: add/create/rename supplier/category hanno entity e dirty ref nella stessa transazione Room; mutex preesistenti preservati e callback solo dopo commit. Test con trigger SQLite effettivo, non mock di transazione.
- Evidence letta: `/tmp/task143-integrity-red/TEST-com.example.merchandisecontrolsplitview.data.OperationalMutationIntegrityTest.xml` contiene `8 tests / 8 failures / 0 errors / 0 skipped`; `/tmp/task143-integrity-green-initial.xml` contiene `8 tests / 0 failures / 0 errors / 0 skipped`. Log operativo `/tmp/mobile-parity-android-integrity.md` coerente con file/test.
- I 7 test estesi sono stati letti ma il loro gate non era ancora disponibile. Nessuna esecuzione autonoma reviewer.
- Finding nuovi nella slice stabile: **P0=0, P1=0, P2=0**. Non è un'APPROVED globale: restano review Storefront Android/iOS congelati, integrazione VM, suite finale e limiti live.

## Review coordinata — Android source freeze F01/F03 (2026-09-28)

Diff completo Android esaminato rispetto a `d7c4953`, inclusi nuovi file untracked, UI/IT-EN-ES-ZH, fixture condivisa e test. Nessuna build o modifica del reviewer. Receipt lookup-before-version e TTL verificati con il rapporto `/tmp/mobile-parity-contract-staging.md`; il suo SQL transaction rollback non è app-auth/HTTP E2E.

### R-A03 — P2 — pending scaduto con publication assente non è recuperabile

`DatabaseViewModel.mutateStorefrontOnline`, ramo `recovering && dispatchedAtMs >= 7 giorni` (circa righe 866–884): readback `ok=true, rows=[]` lascia il record `DISPATCHED`, imposta soltanto `mutation_recovery_required` e ritorna. Ogni retry o nuovo Save torna allo stesso ramo. La UI di reapply/cancel richiede `StorefrontConflictState`, non creabile qui perché `server=null`.

Riproduzione deterministica: intento SAVE_DRAFT expectedVersion=0 salvato DISPATCHED 8 giorni prima; timeout della richiesta precedente prima del commit; backend restituisce read ok senza publication. Retry non manda richieste mutation e lascia pending. Modificare draft e salvare aggiorna desiredDraft ma resta bloccato. Chiudere/riaprire o riavviare non sblocca, proprio perché il record è ora durevole. Il test expiry corrente copre solo publication presente.

Fix richiesto nel batch: riconciliazione esplicita anche dell'assenza confermata per quel prodotto/scope, mantenendo desired e offrendo un intento nuovo verificato o uno scarto intenzionale; non cancellare silenziosamente e non inviare una nuova chiave alla cieca. Coprire primo tentativo mai committato + rows empty dopo TTL, restart, nuova bozza e fallimento della persistenza della risoluzione.

Altre aree sorgente esaminate senza finding P0/P1/P2: file app-private noBackup con fsync file/replace atomico, scope account/shop/product, nessuna eviction pending, errore disco prima del dispatch, payload immutabile DISPATCHED A + desired B, replay stessa key prima di successor, readback dopo receipt vecchia, conflitto durevole, override pending solo dopo rifiuto noto, nessun ACK offline per publish/hide/schedule/archive, fallimento remove dopo ACK conserva record per exact replay. Gate finali non ancora valutati. Verdetto Android sorgente attuale: **CHANGES_REQUIRED (R-A03)**.

## Review coordinata — iOS source freeze (2026-09-28)

Esaminati diff rispetto a `30d226d0`, Storefront authoring/storage/UI, fixture, test e compatibilità toolchain nei 24 file dichiarati. Nessuna build o modifica repository del reviewer. Confermata nel diff definitivo la disabilitazione dei campi durante loading/mutation/image adoption; il relativo test UI rosso è stato comunicato dall'executor e resta separato dalle prove autonome.

### R-I01 — P1 — readback di receipt vecchia perde la base ACK e crea conflitti/reapply errati

`StorefrontAuthoringStore.sendIntent`, ramo `response.idempotent` (circa righe 1156–1162), lancia `.conflict(current)` se la versione readback è diversa da quella del receipt prima di riconciliare il journal con l'ACK. Il catch elimina `journal.intent` ma mantiene `journal.draft` e `baseDraft` antecedenti A. `StorefrontAuthoringViews.reapplyConflict` usa quella base precedente per il three-way overlay.

Scenari deterministici da aggiungere:
1. Base nomeOld → A nomeA committata con ACK perso → altro device C nomeC → retry identico A. Il receipt prova che A è già riuscita e non resta un nuovo intento utente, ma iOS conserva A come local draft in conflitto. Android adotta il readback corrente in questo caso. È il falso conflitto che F03 richiede di evitare.
2. Stessa sequenza, ma dopo A l'utente prepara B cambiando soltanto il prezzo e lasciando nomeA. Al readback C il journal B rimane basato su nomeOld: il reapply include anche nomeA e sovrascrive nomeC, benché dopo l'ACK A il solo campo da riapplicare sia il prezzo. Il test concurrent attuale modifica di nuovo il nome e non copre questo delta disgiunto.

Fix richiesto nel singolo batch: riconciliare in modo durevole receipt A prima di classificare il readback corrente; senza successor eliminare solo il pending riconciliato e restituire il record corrente; con B conservare base ACK A e delta A→B e renderli disponibili alla UI prima del reapply, anche dopo restart. Coprire fallimento disco durante il rebase senza perdere l'intento originale.

Nessun altro finding P0/P1/P2 emerso: F02 controlla generation+filterGeneration+scope+query e protegge anche defer; migration legacy rimuove UserDefaults solo dopo write riuscita; errore storage blocca il dispatch e viene mostrato; pending separati dalla LRU; scope e stable ID derivano dalla chiave; scadenza con readback assente/expected0 viene riconciliata con precondition0 e retry della stessa key; ACK cleanup fallito mantiene record; publish/hide/schedule/archive non diventano successi offline. iOS Application Support usa file protection + atomic write e resta incluso nel normale backup, mentre Android usa noBackup: differenza di storage osservata, nessun nuovo leak/auth bypass dimostrato.

Compatibilità XCTest: ispezionate RATIONALE.md, owned-files.json e assertion-check.json. Il reviewer ha eseguito un confronto indipendente di tutte le 24 sorgenti rispetto a `30d226d0`: ogni riga `XCTAssert`, `XCTFail`, `XCTSkip`, continuation registration, `Task.sleep`, `Task.yield` è invariata (24/24). Il diff contiene conversione dei fake ai protocolli MainActor, init Sendable nonisolated/await e letture helper coerenti; la correzione Task103 spezza soltanto il log timing mantenendo chiavi/calcoli. Nessun cambiamento del runtime actor isolation o build settings nel diff. `git diff --check` eseguito dal reviewer: PASS. Il gate comportamentale completo resta necessario.

Verdetto iOS sorgente attuale: **CHANGES_REQUIRED (R-I01)**. Batch coordinato totale: R-A03 P2 Android + R-I01 P1 iOS; gli originari R-A01/R-A02 risultano risolti nella slice integrità, subordinati ai gate finali.

## Re-review limitata Android R-A03 — 2026-09-28

**Sorgente: APPROVED condizionato ai gate finali; R-A03 chiuso nel codice.** Nessun nuovo P0/P1/P2 nella patch di recupero e nella guardia di decoding adiacente. Non è approvazione globale Android/iOS né accettazione staging.

- `RECOVERY_REQUIRED` viene scritto atomicamente solo dopo readback riuscito con publication assente; nessun replay cieco oltre TTL, nessuna nuova identità implicita.
- Il caricamento ripristina il flag dal journal dopo nuova istanza; VM e pulsanti bloccano retry e nuove mutation fino alla decisione esplicita.
- `discardExpiredStorefrontIntent` verifica lo stato persistito, elimina solo la chiave account/shop/product corretta, azzera pending/publication dopo successo IO e conserva draft/dirty input corrente. Gli errori non eliminano lo stato visibile e mostrano `local_persistence_failed`; callback tardi protetti da scope/generation/session.
- Azione Compose esplicita e spiegazione disponibili in IT/EN/ES/ZH. Il nuovo test verifica restart, scarto, conservazione nome e nuovo save con chiave nuova. Test Compose verifica che l'azione sia presente e cliccabile; test runtime finale affidato all'executor.
- La guardia `state/operation/desiredOperation in entries` rifiuta enum Gson sconosciuti/null prima che il record possa essere trattato come nuovo intent; `baseDraft` obbligatorio. Test corruzione esteso con stato non riconosciuto.
- Evidenza letta direttamente: `/tmp/task143-android-expiry-red.log` contiene il test R-A03 fallito prima del fix (BUILD FAILED 22s); `/tmp/task143-android-review-fix-green.log` contiene `testDebugUnitTest` e BUILD SUCCESSFUL 35s. Suite canonicali post-fix/Compose/ultima guardia ancora in esecuzione al momento del verdetto; nessun test eseguito dal reviewer.

Il solo finding aperto del batch resta iOS R-I01 P1; re-review limitata dopo fix e prove rosso/verde attesa.

## Re-review limitata iOS R-I01 — 2026-09-28

**R-I01 chiuso nel codice.** Nessun nuovo P0/P1/P2 nel fix congelato.

- `sendIntent` separa ricevuta ACK e publication corrente. Prima del readback rimuove l'intent A dal journal e, se resta B, ne scrive atomicamente `baseDraft = ricevuta A` ed `expectedVersion = versione A`. Fallimento del write/cleanup mantiene il precedente intent su disco e propaga `localPersistence`.
- Retry identico senza successore restituisce la publication corrente C e non lascia un falso conflitto o una draft A già applicata. Non genera una seconda identità per lo stesso tentativo.
- Un successore B diverso da A resta persistito con base A; se C è più recente viene richiesto il conflitto esplicito. `reconciledBase` espone la ricevuta al solo scope/product corretto e l'editor aggiorna base/versione prima di reapply, anche nei ritorni offline/errore dopo ACK. Il delta A→B contiene solo prezzo nel caso di regressione; la reapply preserva il nome modificato da C.
- `loadEditor` rilegge il journal persistito e ripristina `localExpectedVersion`; scope/cancellazione impediscono aggiornamenti tardivi dopo cambio account/shop. Le ultime guardie UI su reset scope e fine loading/mutating/adoptingImage sono incluse nella review.
- Evidenza letta direttamente: `/tmp/mc-task144-ios/review-r-i01-red.log`, 2 test eseguiti con 5 failure (il retry identico lancia conflitto; il test disgiunto osserva base Original/versione7 e dirty name+price invece di baseA/versione8 e solo price). `/tmp/mc-task144-ios/review-r-i01-green.log`, 34 test (28 Storefront store +6 filter) con 0 failure e TEST SUCCEEDED. Il test disgiunto verifica reload dal journal e overlay che conserva il nome remoto C. Sono risultati dell'executor, non test eseguiti dal reviewer.
- Reviewer: `git diff --check` iOS corrente PASS; nessuna modifica codice e nessuna build concorrente.

## Conclusione coordinata sul sorgente

**APPROVED sul sorgente revisionato Android+iOS, condizionato alla chiusura documentata dei gate finali.** Tutti i finding concreti del ciclo (R-A01 editor merge, R-A02 atomicità anagrafiche, R-A03 recovery scaduta senza publication, R-I01 settlement/ribase ACK) sono chiusi nel codice e accompagnati da riproduzioni rosse e risultati verdi mirati. Nessun P0/P1/P2 aperto nel perimetro della review.

Questa conclusione non dichiara PASS di suite canonicali/Compose/XCUITest ancora in esecuzione né sostituisce la verifica autenticata bidirezionale Android↔iOS, l'E2E dei servizi esterni, la sweep manuale completa, CI o autorizzazione al rilascio. Le righe della matrice iniziale rimangono classificate secondo l'evidenza effettiva; presenza di un test non è esecuzione PASS. Nessun ulteriore audit generalista è richiesto da questo verdetto; un nuovo ciclo serve solo per una regressione concreta dei gate.

### Addendum finale R-I01 — scope cambiato durante readback

Re-review **limitata al delta**: la nuova chiamata `validateCurrentScope` prima di rimuovere conflitti/aggiornare summary/restituire ACK copre anche il ramo in cui il readback sospeso riprende con `.offline` o `.unavailable`. Il controllo esistente interno al `do` non veniva raggiunto in quei due catch; ora cancellazione, generation e active scope sono ricontrollati prima di qualsiasi effetto UI. La persistenza della ricevuta già confermata resta correttamente conclusa nel vecchio scope prima dell'attesa.

Il test controllato `testScopeSwitchDuringReceiptReadbackCannotApplyOfflineFallbackToNewScope` sospende il readback, cambia shop, riprende con offline e richiede CancellationError, summary assente e nessun conflitto nel nuovo scope. Nessuna temporizzazione arbitraria e nessuna assertion precedente indebolita. **Delta source APPROVED; nessun nuovo P0/P1/P2.** `git diff --check` PASS. Questo test non è ancora dichiarato PASS dal reviewer: la full suite in corso era partita prima del delta; slice Storefront/UI/build/analyze successivi e CI sull'exact SHA finale restano gate espliciti.

## Verifica evidenze gate locali finali — 2026-09-28

**Android: gate locali verificati PASS**, commit `0f6e353488578ce946b7d1a8a1a2be8786af0ec1`. I 16 hash `changed_app_files_sha256` del manifest TASK-143 coincidono sia con il working tree sia con i blob del commit. Lettura diretta di tutti gli XML elencati: JVM debug **960 PASS, 7 SKIP, 0 FAIL/ERROR** (967 totali); Compose su emulator-5554 **5 PASS, 0 SKIP/FAIL/ERROR**. Nessuna divergenza XML/manifest. Log finale `BUILD SUCCESSFUL in 1m 4s`; lint eseguito, 53 warning preesistenti e nessuno sulle righe cambiate secondo manifest. I JVM output riutilizzati dal comando finale provengono dal precedente run sul medesimo sorgente produzione/JVM; era fallita esclusivamente la compilazione del nuovo callsite androidTest poi corretta. Test release JVM non eseguiti, correttamente distinti nel manifest. I sette skip restano tali (fixture live/benchmark opzionale/workbook/harness sospesi), non trasformati in PASS.

**iOS: slice finale e gate build/static verificati PASS.** Lettura diretta con `xcresulttool get test-results summary` di `post-review-final.xcresult`: **50 PASS, 0 FAIL, 0 SKIP**, 46 unit +4 UI; include `testScopeSwitchDuringReceiptReadbackCannotApplyOfflineFallbackToNewScope`. Log Release post-guard: BUILD SUCCEEDED; log analyze: ANALYZE SUCCEEDED. I 303 hash `final_files` del manifest coincidono con il working tree esaminato. La feature non è ancora nel commit HEAD `4575eefbd4e71914f0031c580de43325f3942b30` al momento della verifica; manifest valida il sorgente finale, mentre l'exact commit sarà verificato dopo il commit/CI.

La ricostruzione in memoria dei due file della full precedente mediante inversione di `post-full-scope-guard.patch` coincide esattamente con entrambi gli hash `full_differing_files`. Quella full precede l'ultima guardia ed è quindi distinta dal gate finale 50-test. Il log attuale contiene **1.353 test-case unici passati, 36 skipped, zero failed**; il precedente riepilogo 1.352 differisce di uno. Il risultato ufficiale della full resta da attendere perché xcresult sta finalizzando diagnostica. Non sommare full e slice come test unici.

**Conclusione locale:** sorgente APPROVED, regressioni mirate e gate finali Android/iOS sopracitati confermati. Nessuna nuova build o audit effettuata dal reviewer. Restano separati CI sui commit finali, completamento ufficiale della full iOS e accettazione autenticata mobile↔mobile/staging; nessuna dichiarazione di rilascio o di E2E completo.

## Review mirata R-A04 — bootstrap identità prima del recovery confermato

**R-A04 chiuso nel sorgente; APPROVED condizionato ai nuovi gate e al ritest live dello stesso scenario.** Delta revisionato rispetto a HEAD `575ea71`; nessun nuovo audit generale, nessuna build o modifica del reviewer.

La riproduzione autenticata del coordinator è concreta: binding presente, device_state e journal assenti, DB/queue vuoti; Review→Replace fallisce `binding_replace_device_identity_missing`. Il percorso ordinario di registrazione richiede READY, che il recovery deve ripristinare. La patch rompe questo ciclo senza dichiarare READY anticipatamente:

- `replaceMismatchedBusinessDataAndBind` usa `DeviceInstallIdProvider.getOrCreate()` dentro la transazione Room già esistente per il journal. Il DAO canonico ha chiave singleton e INSERT IGNORE: identità presente riusata, nessuna rotazione; failure su identity/journal fa rollback di entrambe. Binding e dati precedenti restano fino all'attivazione verificata.
- `ShopSyncRecoveryCoordinator` richiede il callback di registrazione esplicito, eseguito solo in `MISMATCH_REPLACE_CONFIRMED`. `MerchandiseControlApplication` collega l'RPC canonica `registerShopDeviceForShop`, con target shop catturato dal recovery. Nessun bypass al gate ordinario, lease fabbricato o mutazione backend.
- Prima e dopo la sospensione RPC vengono verificati auth/shop tramite `scopeStillValid`, identità dispositivo e uguaglianza completa del journal del run. Solo risposta `ok` sullo stesso shop procede; autorizzazione checkpoint A e verifiche B/C/digest/attivazione preesistenti restano obbligatorie.
- Denial, errore rete, shop errato, scope cambiato e journal più recente impediscono checkpoint/attivazione. CancellationException viene ripropagata dopo registrazione durevole del retry; la vecchia generazione resta integra.
- Factory androidTest aggiornata con fake esplicito, nessun permissive default introdotto in produzione.

**Prove lette direttamente:** `/tmp/task143-ra04-red.log`: 1 test eseguito/1 failure su identità mancante, BUILD FAILED 16s. `/tmp/task143-ra04-green.log`: BUILD SUCCESSFUL 27s. XML correnti: 331 test totali, **330 PASS, 1 SKIP, 0 FAIL/ERROR**: 66 recovery,20 binding,218 repository (1 fixture live SKIP),15 integrity,6 authorization,6 application. I 10 test nuovi coprono bootstrap idempotente, due rollback SQLite reali, ordine registrazione/checkpoint, identità riusata, denial/shop errato/network/retry, scope stale, journal concorrente e cancellazione. `git diff --check` PASS.

La precedente accettazione locale riguarda il commit precedente. R-A04 richiede nuovo build/lint/test/CI e installazione/ritest autenticato coordinato prima della chiusura live; questi risultati non sono inferiti dalle prove JVM.

### Gate canonico R-A04 verificato indipendentemente

**PASS locale sul delta congelato.** Verificati `android-ra04-test-manifest.json`, `android-ra04-build-receipt.json`, XML e log effettivi; nessun file tracked modificato dal reviewer.

- Sei hash sorgente/test correnti coincidono tra filesystem, manifest e build receipt. I tre hash produzione coincidono con quelli letti alla review R-A04. Il digest effettivo `git diff 575ea71 -- app` è `3b5f335b7cc069763f92f1c14216ad66a2ec33d6b6eb959daba46456e104505d`, identico a entrambe le evidenze: nessun delta produzione aggiuntivo.
- Tutti gli XML elencati coincidono con i conteggi del manifest: **977 JVM debug, 970 PASS,7 SKIP,0 FAIL/ERROR;5 Compose PASS,0 SKIP/FAIL/ERROR** su emulator-5554. JVM release correttamente NON ESEGUITI.
- `/tmp/task143-ra04-final.log`: cinque test device avviati e `BUILD SUCCESSFUL in 1m 31s`. XML lint letto direttamente: **0 errori,53 warning**; intersezione indipendente con le righe modificate del diff app: **zero**.
- SHA256 del candidato APK letto direttamente: `0ebd6f8147d34669540aaa6faf943a7553dc2c1a8b79ddab0658156101b43e41`, uguale alla receipt. Verificato anche hash dell'APK precedente preservato. La receipt dichiara correttamente build da base575ea71 più patch non ancora committata; non attribuisce falsamente il nuovo APK al solo commit precedente.

R-A04 ha ora review sorgente e gate canonico locale verificati. Commit/CI finale e ritest autenticato dello stesso APK sul dispositivo del coordinator rimangono evidenze separate e non vengono anticipati da questo PASS locale. Nessun accesso del reviewer al dispositivo o a configurazione/credenziali protette.

## Review mirata Android R-A05 — short denial checkpoint/convergence marker

**Sorgente APPROVED condizionato al nuovo gate canonico e al retry autenticato. R-A05 chiuso nel codice; nessun nuovo P0/P1/P2.** Review limitata al delta rispetto `78d1fbc8163b7e06f5dc8d5d92406450c59b182f`. Otto hash del freeze `/tmp/task143-ra05-freeze.json` coincidono con i file correnti (3 produzione,2 test,3 fixture); nessuna build o modifica del reviewer.

- `validateResponseStatus` decodifica l'envelope obbligatoria prima dei cinque domain success-only: schema, shop, scope/account/device/legacy-owner, history kind, digest checkpoint e scope atteso vengono controllati prima di interpretare status. Aggiunto confronto `expectedBaselineScopeKey` anche quando non è presente l'intero expectedScope.
- La logica è comune a checkpoint e convergence marker; controllato il costruttore SQL canonico del marker, che deriva status/scope/digest dal checkpoint e può avere domain null nel rifiuto breve. Il test marker esercita proprio quel caso. Denial riconosciuti `resource_exceeded`, `invalid_baseline`, `integrity_blocked`; status ignoti diventano codice statico unsupported, senza riportare il valore remoto non fidato.
- Solo `ready` prosegue verso i DTO completi originali, ancora rigorosi. I cinque domain non ricevono default vuoti; missing status, ready incompleto e JSON non decodificabile sono errori di contratto. Budget e trasporto bounded/controlli di scope esistenti non modificati. Le due fixture coincidono semanticamente con gli envelope sintetici prodotti dalla diagnosi SQL; non sono catture di una sessione app.
- Il coordinator conserva il motivo nel journal retry e la generazione precedente, cancella staging non attivato e restituisce Rejected per i rifiuti deterministici. Il scheduler esistente termina **la finestra corrente**; un successivo trigger può ritentare dopo una correzione server. Questo non viene descritto come blocco permanente di ogni trigger automatico. Nessuna publication o recovery riuscita viene sintetizzata.
- Diagnostica limitata a codice/RPC noti e nomi dei campi mancanti filtrati; niente payload, account/shop/device o dati business nei nuovi log.

**Prove lette:** `/tmp/task143-ra05-red.xml`:2 test/2 failure MissingFieldException dei cinque domain. `/tmp/task143-ra05-scope-red.xml`:test scope fallito con denial al posto di baseline_scope_key_mismatch prima dell'ultima guardia. `/tmp/task143-ra05-green2.log`:BUILD SUCCESSFUL11s; XML congelati in `/tmp/task143-ra05-targeted/`:113 PASS,0 FAIL/ERROR/SKIP. Coperti denial, ready incompleto, scope/account/device/shop/schema errati, marker breve, diagnostic privacy, conservazione dati/journal e recupero dopo trigger successivo.

Il difetto classificazione è corretto; il preflight reale `resourceExceeded` relativo a storia compressa resta un blocco server da riportare, non è risolto dal decoder. La sua attribuzione al request autenticato esatto richiede il retry del coordinator. Nessuna autorizzazione implicita a decomprimere/cambiare dati o allargare limiti/policy.

## Review mirata iOS R-I02 + crash test runtime26.2

**R-I02: CHANGES_REQUIRED per un solo completamento concreto, P2 marker breve.** Il checkpoint patchato valida schema/shop/scope/account/device/legacy-owner e expectedBaselineScopeKey dopo i controlli di sessione/local lease e budget, prima dello status. Solo ready raggiunge il DTO rigoroso originale; rifiuti e status sconosciuti hanno codici statici. Il servizio atomico propaga il denial senza consumare il secondo tentativo riservato a checkpointChanged, senza pubblicare staging; test confrontano anche byte del journal e binding. Nessun finding aggiuntivo su questa parte.

**Finding R-I02-marker [P2], `ShopSyncRecoveryContract.swift`, metodo `ShopSyncRecoveryRemoteAdapter.marker`, decode completo originariamente a riga945:** questo metodo continua a decodificare `ShopSyncRecoveryConvergenceMarker` prima dello status. Il costruttore SQL canonico `shop_sync_convergence_marker_v1` deriva lo status dal checkpoint e, se il preflight diventa resource_exceeded/invalid_baseline tra B e C, restituisce catalog/prices/history/images null e integrity.totalViolationCount null. Ne segue ancora DecodingError prima che sia possibile classificare il rifiuto server. Stesso root cause già coperto dal marker Android; richiesta estensione dell'envelope stretta anche al marker iOS, verificando schema marker e scope completo/chiave della baseline prima del codice denial, mantenendo il DTO ready invariato. Richieste regressioni del marker breve e dei mismatch, conservazione journal/staging senza falso successo. Nessuna build del reviewer; segnalato al parent per lo stesso batch.

Evidenze primo freeze: due fixture iOS semanticamente identiche alle fixture diagnostiche sintetiche. `/tmp/mc-task144-ios/ri02/red.log`:6 test con4 casi falliti (9 assertion failure) e2 pass, missing catalog/keyNotFound. `green.xcresult` letto direttamente:48 PASS,0 FAIL/SKIP (26 atomic +22 contract). Il verde non copre il finding marker sopra.

**Crash test26.2: delta APPROVED, condizionato ai gate finali/CI.** Verificato indipendentemente che cambia soltanto `testFileStorageReportsActualFilesystemError`: entry point async, stessa chiamata reale al filesystem, assertThrows conservato e rafforzato con dominio/codice Foundation e byte del file bloccante intatti. Contenuto fuori dalla funzione identico al baseline97b6c812; produzione StorefrontAuthoring.swift byte-per-byte invariata. Nessun actor setting globale, skip, fake o indebolimento.

Verificati gli hash dei tre artefatti raw elencati in `ci97b6-runtime26-2/artifact-manifest.json`; summary baseline0PASS/1CRASH/0SKIP, stack locale SIGABRT TaskLocal::StopLookupScope→swift_task_deinitOnExecutorImpl→StorefrontPendingFileStorage deinit→funzione test. Summary verde29PASS/0FAIL/0SKIP sullo stesso runtime26.2. Il runtime coincide con CI; il compilatore locale27.0 differisce dal CI26.6 e il rapporto lo dichiara: la riproduzione non viene spacciata per stack CI esatto. Nessun test del reviewer e nessun accesso device.

### Re-review finale R-I02-marker

**Finding marker chiuso; sorgente iOS R-I02 APPROVED condizionato ai gate canonici e CI. Nessun nuovo P0/P1/P2 nel delta.** L'envelope comune viene ora applicata anche al marker dopo budget/auth/local-scope freshness e prima del DTO completo. Verifica schema marker, shop, intero scope della baseline, chiave attesa e binding account/device/legacy prima dello status. Otto codici statici checkpoint/marker allineati ad Android; unsupported non riporta valori remoti. Le risposte ready attraversano ancora il decoder e la validazione completa originali.

La regressione attraversa realmente checkpoint A, pagine, checkpoint B e marker rifiutato; verifica due checkpoint, una sola chiamata marker, nessuna attivazione/finalization, stesso modelContainer e binding, journal conservato senza watermark. Il caso scope differente non può essere classificato come normale denial. Ready marker con domain null resta DecodingError. Fixture marker coerente con builder SQL canonico (quattro domain null, integrity total null, eligibility false).

Evidenze `.xcresult` lette direttamente con xcresulttool: `marker-red.xcresult` **1 PASS,2 FAIL,0 SKIP**; entrambe le failure erano DecodingError/valueNotFound a catalog prima di denial o scope check. `marker-green.xcresult` **81 PASS,0 FAIL,0 SKIP**:30 atomic,22 contract,29 Storefront. Quindi include anche il test storage rafforzato, oltre alla sua precedente prova29/29 su runtime26.2. Reviewer `git diff --check` PASS, nessuna build.

Hash congelati letti alla re-review: `ShopSyncRecoveryContract.swift` b929be1006a846e94617548b53cc787e08ebb5e2dc70d35b67629c9fa7aec772; `AtomicGenerationRecoverySnapshotPullServiceTests.swift` ea7727ac87f4959f785a01f326af0380e3349e8e330caacf34290b8f35f08d0c; `StorefrontAuthoringTests.swift` a9ce902874d156f25bbc2445edabeb737f39405416cd12803ae0a60c94b002fd.

Android R-A05 e iOS R-I02 sono ora entrambi approvati sul sorgente; resta distinto il rifiuto reale di policy/storage sul TEST shop, che il client deve mostrare fedelmente senza attivare snapshot incompleti. Nessuna modifica backend/data autorizzata da questo verdetto.

## Gate locale finale iOS R-I02 e test26.2 — evidenza verificata

**Full finale, Release e analyze PASS sul sorgente già approvato.** Fingerprint ricalcolata indipendentemente dal mapping JSON ordinato compatto: `9f1d274203133bdef7baac3af73aae95955fedd10ce280e5cbd81b5f3cf10a2d`. Verificati325/325 file app/test/resource correnti e hash project/scheme; elenco completo coincide con tracked/nonignored untracked nei tre alberi. I tre hash del delta R-I02/test crash coincidono con la re-review: nessuna nuova patch sorgente.

Lettura diretta di `final-full.xcresult` con xcresulttool: **1.402 totali,1.366 PASS,36 SKIP,0 FAIL**; dal tree dei bundle1358 unit/integration PASS e8 XCUITest PASS. I36 skip sono esplicitamente live/external29, synthetic opt-in4, Excel sospeso2 e physical1. Nessun PASS attribuito agli skip. Summary registra un runtime warning QoS in `SyncEventIncrementalDomainApplyServiceTests`, distinto dai risultati dei test e dai warning analyzer; nessun test fallito.

Hash dei log full/Release/analyze coincidono con `final-gate-manifest.json`; Release ha BUILD SUCCEEDED, analyze ha ANALYZE SUCCEEDED. Manifest dichiara zero nuovi warning analyze rispetto alla precedente baseline. La review non ha eseguito build/test.

Al momento di questa verifica, `sensitive_scan` nel manifest finale è ancora **Pending final evidence scan**: il riepilogo scan generale già disponibile riferisce i pass precedenti, non è assunto come scan della nuova evidenza congelata. Attesa conferma dell'executor per questa sola voce. CI sull'exact commit iOS e accettazione autenticata restano gate separati; Android merge/CI sono gestiti dal parent e non rianalizzati in questo passaggio.

### Chiusura scan evidenze iOS finale

Riletta la versione congelata di `final-gate-manifest.json`: il campo `sensitive_scan` ora contiene i report finali. **Scope canonici source/evidence PASS**, più scan esplicito dei file Swift cambiati (lo scanner per directory non include Swift). Verificati gli hash dei cinque report JSON. Recovery e atomic-tests espliciti PASS; Storefront-tests presenta un solo match della regex email nella URL negativa `example.test` di `testPublicImageURLFailsClosed`, riga94, verificata byte-per-byte identica a97b6c812 e con hash baseline corrispondente. Nessun nuovo dato sensibile;0 match protetti dopo redazione. La segnalazione sintetica preesistente è classificata esplicitamente, non nascosta come zero-match scan.

Questo addendum risolve l'attesa scan della sezione precedente. Gate locali finali iOS ora verificati per full1366PASS/36SKIP/0FAIL inclusi8UI, Release, analyze e scan con l'eccezione sintetica documentata, sul fingerprint9f1d2742…10a2d. Restano separati exact-SHA CI e accettazione autenticata; nessuna modifica tracked o build del reviewer.


## Follow-up live iOS post-5db — attribution of displayed catalog error

Read-only investigation at source commit `5dbcb6e7`; no build, test execution, device access or tracked edits. Read only the route/error labels from the authorized UI attachment, excluding identity/session values. The attachment shows `Owner-scope sync`, `anonymous`, and a truncated `keyNotFound(...catalog...)`; it does not contain the codingPath or prove a fresh RPC failure.

Source-grounded diagnostic defect (executor owns red reproduction and fix):
- `OptionsView.swift`, `AutomaticSyncDiagnosticsSnapshot.init` lines 1917–1933 reads a historical watermark-derived scope and prioritizes `sync.runtime.automatic.lastError` over the canonical orchestrator error.
- `accountAndStoreScope` at 2086 selects the lexicographically last historical watermark key, not the authenticated current scope. `shopSourceText` at 1972 maps `anonymous` to the owner-scope label. Thus this UI label is not route evidence.
- `lastErrorText` at 2002 attaches `lastProgressAt ?? startedAt` to whichever error was selected, so a prior error can acquire the current retry timestamp.
- `AutomaticSyncEngine.recordDiagnostic` at 484 and `recordVerifiedRecoveryDiagnostics` at 474 write/clear automatic diagnostics only under `#if DEBUG`. A Release installation preserving defaults can retain a previous Debug error.
- `SyncStateStore` completion at 191–207 records the current completion time and writes/removes the current orchestrator error in Release as well, but Options can obscure it with the older automatic key.

Routing inspection: Retry in `OptionsView.actionRow` calls explicit recovery for `recoveryRequired`, otherwise the automatic cloud-check callback. `AutomaticSyncEngine.recoverRemoteSnapshot` captures/revalidates the owner/shop scope and delegates only to an atomic provider. `AtomicGenerationRecoverySnapshotPullService.recoverFromRemoteSnapshot` uses `ShopSyncRecoveryRemoteAdapter`; the only remote checkpoint and marker full DTO decoders found are at `ShopSyncRecoveryContract.swift:848` and `:968`, both preceded by the approved R-I02 scope/status envelope. No owner-scope decoder bypass is established. A truncated `catalog` key could also be nested; it is not sufficient to attribute a new contract failure.

Proposed deterministic tests for executor: seed an old automatic error and anonymous watermark, then a current scoped orchestrator denial at T2; assert current error/scope and correctly associated time. Current completion without an error must not resurrect the old automatic error. Any retained historical diagnostic must remain explicitly historical and must not receive a new progress timestamp. Existing `Task118AutomaticDomainTests` checks UI source strings, not this precedence/freshness behavior. Tests not run by reviewer. Await the executor red/frozen patch and selective fresh runtime evidence; do not claim new decoder regression or current recovery success from the UI packet alone.


## R-I03 — scoped review of the frozen Options diagnostics fix

**Source verdict: APPROVED**, no concrete P0/P1/P2 findings in the three-file application/test delta against `5dbcb6e7`. No production change outside OptionsView, no decoder/auth/storage modification, no reviewer build or test execution. Parent task/master documentation was excluded from this limited source review.

Reviewed behavior:
- Signed-in card supplies the authenticated session UUID; signed-out state supplies nil. The snapshot requires its account hash to equal the current shop-context account, reads the resolved selection for that account, and applies the existing `LinkedShop.isValidSelection`. Missing/mismatched/unresolved/nonselectable scope stays unavailable. This displays the selected shop, not a write authorization or legacy watermark-derived scope.
- `SelectedShopStore.init`, `selectedShop` and `isResolutionReady` are pure preference reads; this code neither captures a lease nor creates device identity. Added runtime assertion compares the complete isolated defaults dictionary before/after snapshot creation.
- Last error reads canonical `orchestrator.lastRunErrorCode`, falling back only to canonical `lastRunBlockReason`. Both are written/removed by `SyncStateStore.recordRunResult` in Release. A current success therefore cannot resurrect the old DEBUG-only error.
- Error display uses the same canonical result's `lastRunCompletedAt`; later progress does not relabel an old error with a new time. Missing completion time leaves the error undated. Existing truncation is preserved; no new payload/token logging or preference writes.
- Existing release UI source-contract test only updates its struct-boundary delimiter from private to internal; every assertion is retained. Six added runtime tests cover precedence, block/success, later progress, missing timestamp, authenticated resolved shop, and signed-out/account-change/unresolved scope.

Freeze hashes independently recalculated and matched `review-source-hashes.json` (3/3):
- OptionsView.swift `df163923ebe2720274992ac05d38accc20dfd039d4f14ff0ce437e07c5f5b209`
- Task118AutomaticDomainTests.swift `66c87646b94d995a2c2ad038d02d424a976417b86d952d4414990a7eb4c6e070`
- SupabaseManualSyncReleaseUITests.swift `c73c5dff706dd95534a5c213e94586ef830ef464c52cf146d40bedca4d01aa7b`

Evidence read directly using xcresulttool (read-only, no rerun): `/tmp/mc-task144-ios/ri03/red.xcresult` reports 0 PASS / 6 FAIL / 0 SKIP, all six added diagnostics cases failing on the original behavior; `green.xcresult` reports 123 PASS / 0 FAIL / 0 SKIP. Green log confirms 30 atomic recovery + 29 Storefront + 26 release UI source-contract + 38 Task118 tests; these release UI source-contract tests are unit/source checks, not an authenticated XCUITest result. Initial failed compile attempt is retained in the executor evidence and precedes the frozen green source.

Parent reports the second authenticated retry now records `checkpoint_resource_exceeded` while the old DEBUG error remains unchanged, supporting the original attribution and R-I02 live classification. This was not independently performed by this reviewer. Final canonical gates, exact-SHA CI and validation of the newly built live diagnostics UI remain separate from this source approval.


## R-I03 adjacent general Options label — source attribution

Parent reports the newly installed live diagnostics now show the correct `checkpoint_resource_exceeded`, selected scope and completion time, but the general local-database card says “Cloud permission problem” while authentication is connected. No additional private payload was needed for source attribution.

Read-only confirmation: `LocalDatabaseCloudStatusResolver.resolve` in OptionsView.swift at 1085–1086 maps any generic `.failed` sync phase/outcome or `syncCountDriftCheckFailed` to `.cloudPermissionProblem`, even with `isAuthFailed == false`. An ordinary nonempty, unaligned recovery failure therefore gets the permission-specific title. Real auth failure has an earlier distinct branch at 1061, and `.deviceNotActive` has a distinct block-reason mapping at 1167.

Executor owns red reproduction and minimal copy/resolver fix. Review guardrails sent: cover all three generic triggers; preserve actual auth/device permission, sign-in, network/offline, aligned historical-failure behavior and the existing automatic-retry policy. Existing `OptionsLocalDatabaseCloudStatusTests` has no regression for the generic-failure/permission distinction. No build/test/source edit by reviewer. Await frozen patch and evidence before a verdict.


## R-I03 — final scoped card-label extension review

**Source verdict: APPROVED**, no concrete P0/P1/P2 finding. The adjunct introduces `.cloudCheckFailed`, reuses the existing localized generic title/detail, and changes only the generic failed phase/outcome/count-check branch to that reason. Reversing these six changed production lines in memory exactly recreates the prior approved OptionsView SHA (`df163923...5b209`); no further production delta is hidden in this review.

The real auth-failure, deviceNotActive, authRequired, network/offline, aligned historical failure, resolution precedence and `shouldRequestAutomaticCloudCheck` behavior are unchanged. Existing strings were inspected in Italian, English, Spanish and simplified Chinese: each says the cloud check failed and a retry is available, without incorrectly asserting a permission problem. No localization files changed. Two runtime tests add the three generic triggers and explicit auth/device/authRequired/network guards; existing assertions are unchanged.

Four freeze hashes independently matched `/tmp/mc-task144-ios/ri03/card-review-source-hashes.json`:
- OptionsView.swift `d57bb1a45fb947c3ed22f9ae6d74214cd5774eb6baa6e23669b8a9c5742b0527`
- Task118AutomaticDomainTests.swift `66c87646b94d995a2c2ad038d02d424a976417b86d952d4414990a7eb4c6e070`
- SupabaseManualSyncReleaseUITests.swift `c73c5dff706dd95534a5c213e94586ef830ef464c52cf146d40bedca4d01aa7b`
- OptionsLocalDatabaseCloudStatusTests.swift `426e45715b9e2c9271ba951da498cd45b46c112a48013cf560429638f0672269`

Direct read-only xcresult summary verification: `card-red.xcresult` 12 PASS / 1 FAIL / 0 SKIP (generic failure regression), `card-green.xcresult` 136 PASS / 0 FAIL / 0 SKIP. These are executor-run results, not reviewer test executions. No build, device action or tracked file modification by reviewer. Signed final artifact, full canonical gate, exact-SHA CI and updated live UI validation remain separate.
