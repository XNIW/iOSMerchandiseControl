# Piano minimo per batch revisionabili

Solo planning. Baseline e finding in [RCA](ROOT_CAUSE_ANALYSIS.md), invarianti in [CONTRACT](CONTRACT.md), gate in [TEST_MATRIX](TEST_MATRIX.md). Nessun nuovo engine, dipendenza, API pubblica, schema o branch autorizzato da questo documento.

## Batch0 — handoff, baseline e diagnosi del primo errore

Un executor per repository, distinto dal planner; reviewer diverso dal writer. Congelare SHA/WIP, CI e build installata; controllare writer/runner. iOS TASK-144 e Android TASK-143 restano sospesi/BLOCKED, senza perdere storia. Rileggere dati sanitizzati del caso corrente, senza tap Retry, reset o reinstallazione. Android deve legare APK1510010… alla sorgente/config prima di usarlo come prova del candidato. Backend: identificare registry/RPC/hash effettivi prima di qualsiasi witness live.

Artefatti: baseline aggiornata, ammissione per singolo esperimento, matrice casi riusati e nuovi; conservare FAIL/UNKNOWN storici. Stop soltanto della lane dipendente se manca ambiente/authority; regressioni isolate indipendenti possono avanzare dopo assegnazione execution.

## Batch1 — regressioni mirate e diagnosi utile

Prima ROSSO sulla stessa baseline e poi GREEN sullo stesso caso, senza rilassare assert/timeout/fixture. Preparare prioritariamente IOS-R01/R02/U02 e AND-R01/R02/Q01/Q02/D01. IOS-L01/AND-L01 e IOS-Q01 devono essere riprodotti prima di scegliere la patch. Se l'ipotesi è falsificata, registrarla e non introdurre il fix.

iOS test esistenti: `iOSMerchandiseControlTests/Task118AutomaticDomainTests.swift`, `Task119AutomaticArchitectureTests.swift`, `OptionsSyncSummaryProviderTests.swift`, `OptionsLocalSummaryServiceTests.swift`, `OptionsLocalDatabaseCloudStatusTests.swift`, `AtomicGenerationRecoverySnapshotPullServiceTests.swift`, `SyncEventOutboxDrainServiceTests.swift`.

Android test sotto `app/src/test/java/com/example/merchandisecontrolsplitview/`: `MerchandiseControlApplicationTest.kt`; `data/{CatalogAutoSyncCoordinatorTest,HistorySessionPushCoordinatorTest,SyncErrorClassifierTest,DefaultInventoryRepositoryTest,ShopSyncRecoveryCoordinatorTest,SupabaseShopSyncReadRemoteDataSourceTest,SupabaseAuthManagerTest,SupabaseAuthLifecycleTest,ShopContextOfflineAuthorizationTest,Task126BusinessDataScopeRuntimeGuardTest}.kt`; `viewmodel/CatalogSyncViewModelTest.kt`; `ui/navigation/BusinessContentGateTest.kt`.

Una regressione helper-only sul numero5 non prova la presenza di un timer futuro: esercitare il coordinator reale e il tempo controllato. Usare transport/clock già disponibili, storage sintetico isolato; niente reti live nei test deterministici.

## Batch2 — capacità locale e navigazione (solo lacune confermate)

iOS file candidati:

- `iOSMerchandiseControl/SupabaseAuthViewModel.swift`: distinguere stato auth cloud transitorio da logout/revoca.
- `iOSMerchandiseControl/Sync/Policy/Task126SyncPolicy.swift`: capacità locale qualificata, conservando manifest/binding/device/fence.
- `iOSMerchandiseControl/ContentView.swift`: shell/Opzioni accessibili, business content protetto; cancel/review non intrappolano la shell.
- `iOSMerchandiseControl/Sync/SyncOrchestrator.swift`: risveglio alla qualificazione già esistente, modificare solo un ramo RED residuo.

Android candidati, prefisso `app/src/main/java/com/example/merchandisecontrolsplitview/`:

- `data/SupabaseAuthManager.kt`, `data/ShopContext.kt`, `MerchandiseControlApplication.kt` e `ui/navigation/NavGraph.kt`, solo dopo RED del cold auth temporaneo.
- `data/Task126BusinessDataScopeRuntimeGuard.kt` e `data/InventoryRepository.kt` sono guardrail da verificare, non rimuovere: local capability split e NavHost stabile sono già implementati.

Alternativa scartata: rendere sempre vero READY/isSignedIn o mostrare tutto il DB sotto shell. Rischio: fuga cross-account, scritture stale; controlli T06/T07 obbligatori. Gate: A–G, Save durevole e preservazione editor, niente scope foreign.

## Batch3 — retry e ripresa automatica

iOS: `Sync/SyncOrchestrator.swift` (`requestForegroundCheck`, eligibility/deferred retry), `Sync/Automatic/Presentation/SyncStateStore.swift` (record budget), `Sync/Automatic/Core/{AutomaticSyncEngine,AutomaticSyncRetryPolicy}.swift`. Aggiungere tassonomia interna senza serializzare descrizioni come decisioni; finestre bounded riattivabili soltanto transient. Reuse single-flight e scheduler; non creare timer paralleli.

Android: `MerchandiseControlApplication.kt` (`schedulePendingBusinessRecovery`), `data/{CatalogAutoSyncCoordinator,HistorySessionPushCoordinator,SyncErrorClassifier,SupabaseShopSyncReadRemoteDataSource,InventoryRepository,SyncEventModels}.kt`. Conservare `nextRetryAtMs` e identity; dare un successore al journal recoverable e non rendere permanente l'esaurimento di eventi transient. Recuperare Retry-After dal transport esistente ove disponibile, non dedurlo dal testo errore.

Alternative scartate: retry infinito rapido, reset del journal/budget a ogni launch, full sync universale o pulsante obbligatorio. Rischi: tempesta richieste, timer stale, battery use, tentativo ripetuto su payload invalido. Gate T03–T07/T12/T19, numero tentativi e istanti osservati, nessun timer precedente scope.

## Batch4 — integrità e progresso indipendente

iOS: `Sync/Automatic/Catalog/CatalogPushService.swift`, `Sync/Automatic/Core/AutomaticSyncEngine.swift`, test atomic recovery/outbox. Android: `data/InventoryRepository.kt` (outbox decode/per-item boundary), `data/BusinessWriteAttempt.kt` solo se RED dimostra il bisogno e la dipendenza è definita. Eventuali cambi a `SyncEventModels.kt` solo metadata indispensabili.

Classificare malformed item conservato, stable conflict e scope/integrity global barrier. Continuare soltanto componenti indipendenti con base/relazioni valide. Non reimplementare exact ACK, durable receipt, generation transfer o price dedup già presenti. Test perso ACK/replay/Save B, failure disco, dipendenze, recovery con edit concorrente.

Aggiornare esplicitamente `docs/SYNC_POLICY.md` iOS per l'eccezione verificata descritta in CONTRACT. Le policy storiche Supabase restano linkate con la decisione di superamento del retry manuale; la semantica conflitti non cambia implicitamente.

Backend **condizionale**, nessuna patch assegnata ora: se T08/T10 rivela un gap del writer effettivo, documentare esatto RPC e proporre estensione additiva circoscritta sul contratto esistente. Se timeout persiste, usare join request/query e replica sintetica per localizzare costo/lock prima di cambiare helper/checkpoint. La lane backend vive nel repository proprietario Admin con suo owner, non nei vecchi SQL Supabase. No migration/deploy da questo handoff senza successivo scope autorizzato.

Alternative scartate: catch-all+continue, scarto record invalidi, LWW globale, update riga intera, conversione di un timeout in conflitto. Gate T08–T13/T16/T19 e review integrità prima delle prove live.

## Batch5 — stato e UI coerenti

IOS-U02 è indipendente e può essere eseguito subito dopo batch1 anche mentre la diagnosi backend resta aperta. File:

- `iOSMerchandiseControl/Sync/Automatic/Presentation/OptionsSyncSummaryProvider.swift`: conteggio cloud esclude localOnly; attenzione separata.
- `Sync/Automatic/Presentation/{SyncState,SyncStateStore,SyncStatusPresenter}.swift`, `Sync/SyncOrchestrator.swift`, `OptionsView.swift`, `ContentView.swift`: provenance/date, local card vs cloud, quiet state e single presentation.
- Localizzazioni esistenti IT/EN/ES/ZH, solo chiavi usate dal delta; layout adattivo dei pulsanti verificato prima di modificare.

Android: `data/CatalogSyncStateTracker.kt`, `viewmodel/CatalogSyncViewModel.kt`, `ui/components/CloudSyncIndicator.kt`, `ui/navigation/NavGraph.kt`, `ui/screens/OptionsScreen.kt`, `app/src/main/res/values*/strings.xml`. Timestamp all'origine dell'esito, no now al replay; errore transient vs azionabile; preservare layout/ritardi già corretti.

Alternative scartate: nascondere tutti gli errori, azzerare diagnostica/contatori, “Sincronizzato” dal solo pending0. Rischi: verità falsata, successo cross-scope, focus/scroll perso. Gate T14/T15/T18/T19; test visuali reali richiesti, non dedotti dal codice.

## Batch6 — collaudo cross-platform e prestazioni

App vere su Simulator/Emulator separati, TEST ammesso e fixture con manifest; verifiche per ID/campi/relazioni in entrambe le direzioni. Nessuna acceptance da conteggi soli. Test upgrade Debug/Release preservativo con pending su installazioni sintetiche, non sul dataset reale. Gate fisico separato quando richiesto dalla pipeline.

Profilare percorso no-work/qualification Android e checkpoint/marker backend, oltre Save/UI iOS, su 20k prodotti/oltre40k prezzi locali sintetici. Nessuna ottimizzazione predefinita: se T20 dimostra costo, piccolo batch aggiuntivo approvato nel piano con prova equivalenza. Non indebolire digest/body qualification per migliorare tempi. Target foreground e distribuzioni definiti nella matrice.

## Batch7 — review e consolidamento

Reviewer indipendente sul diff immutabile e prove esatte. Writer corregge finding → nuova REVIEW, mai FIX→DONE. Aggiornare task/CA/T-NN, proteggere WIP e file degli altri task. Integrazione preferita su main secondo protezioni effettive, review e CI final SHA; nessuna branch in planning. Prima di integrare inventariare HEAD/ancestry/PR/index/stash/writer/lock e required checks, commit selettivi normali, niente reset/clean/stash/force-push o bypass. Se la protezione richiede PR/procedura diversa, documentare il vincolo reale. Chiusura soltanto utente/pipeline dopo tutti i gate obbligatori.
