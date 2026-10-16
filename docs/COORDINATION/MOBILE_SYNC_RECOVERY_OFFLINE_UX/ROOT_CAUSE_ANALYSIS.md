# Baseline e root-cause analysis

Coordination key: `MOBILE_SYNC_RECOVERY_OFFLINE_UX`. Snapshot 2026-10-15; linee sorgenti riferite agli SHA sotto. STATIC conferma il percorso del codice, non una riproduzione runtime. L'osservazione persistita non equivale allo stato RAM corrente.

## Baseline, integrazioni e ownership

| Ambiente | Stato verificato |
|---|---|
| iOS checkout e GitHub | Branch main, HEAD e origin/main `314cf5332d0b889331802a3f886c1910b9b377b0`. Letti via GitHub a SHA fissato tutti gli otto entry point indicati dall'utente, byte-identici ai locali. Due file Xcode dirty preesistenti + evidenze untracked, 14 file complessivi preservati. |
| iOS CI | [38429535889](https://github.com/XNIW/iOSMerchandiseControl/actions/runs/38429535889) SUCCESS sul medesimo SHA, metadata riletti oggi. Conteggi 1548 PASS/36 SKIP/19 UI sono evidenza storica nel dossier precedente, non test rieseguiti oggi. CI precedenti 38391768338 e 38203952665 FAIL conservate. |
| iOS integrazioni | PR18 local availability/ACK, PR20 qualification, PR21 stale activated recovery, PR22 language, PR23 diagnostic readiness, PR24 completion/layout, PR25 populated resume, PR26 native taps: MERGED verificato. Non riapplicare questi fix. Nessuna PR aperta emersa dall'inventario pertinente. |
| Android checkout e GitHub | Branch main, HEAD/origin/main/GitHub `4b74ed5cfb4e4bce024513561e7dc1b6998003ae`. Dirty `gradle/libs.versions.toml`, `gradle/wrapper/gradle-wrapper.properties`; untracked IDE/TASK140F/tools, 6 file preservati. |
| Android CI/integrazioni | [38623121443](https://github.com/XNIW/MerchandiseControlSplitView/actions/runs/38623121443) SUCCESS sullo SHA corrente; 38622829780 CANCELLED distinto. PR23 V6/retry, PR24–27 layout/localizzazione, PR28 account prerequisites, PR29 system bars MERGED. Nuovi test non eseguiti. |
| Supabase workspace | `/Users/minxiang/Desktop/MerchandiseControlSupabase` NON Git, nessun HEAD/branch/PR/CI attribuibile; root `MASTER_PLAN.md` IDLE, ultimo 047 DONE. Foundation SQL presente, RPC recovery attuali assenti nella ricerca delimitata. Nessun master parallelo creato. |
| Fonte backend effettiva | `/Users/minxiang/Projects/merchandise-control-admin-web`, HEAD `d283f76a4f9cd59e63e75c00ef831df0efee53c5`, sola lettura. Quattro migration pertinenti puliti. 169 file locali non sono una migration history TEST. |

`baseline.json` conserva worktree, stash (vuoti), index e hash delle modifiche estranee. Non sono stati rimossi worktree, compreso quello iOS prunable. Nell'inventario delle 30 chat recenti, i precedenti owner mobile risultano notLoaded/idle; nessun executor mobile attivo osservato. Due processi Java Gradle presenti, attività effettiva non attribuita: nessun build aggiuntivo avviato. Questo inventario è bounded, non una garanzia universale di assenza writer. Prima delle patch occorre un nuovo controllo e l'assegnazione di un unico executor per repo.

Tracking iniziale incoerente: iOS titolo TASK-144/FIX, sezione workflow TASK-132, sezione task corrente nessuno; Android TASK-143/FIX con branch diagnostico storico. La nuova assegnazione autorizza la correzione dei puntatori e la sospensione esplicita dei vecchi task; storico e criteri restano intatti.

## Build installata e osservazione corrente

iOS Simulator iPhone 15 Pro Max, runtime iOS26.1, app 1.0(1), SDK build iphonesimulator27.0/Xcode2700. Binario corrente SHA256 `e21efd770fc432d2191f363d6c5212a59448fd57ef6a0bab6df5ee79b98a9f78`. La receipt storica di installazione preservativa del 14 ottobre lo lega al build originario `a731464…`, Release-equivalent a `e6a286f…` e main `314cf533…`; non è una compilazione odierna. Receipt SHA256 `045f83b7bb5e47823ec496256fb0877d2db7d7fb92d78f0afb94e2e6b19072a7`.

Config installata SHA256 `154a137692161c1a1f5d1014567501428d1706945285431b7639aa5546d302cc`: endpoint TEST `jpgoimipbothfgkokyvm`, image API staging. Nessun token/Keychain letto o esportato. Il project-ref locale Supabase coincide: questo non dimostra le migration distribuite.

Android Emulator API35/Android15, package `com.example.merchandisecontrolsplitview`, 1.0(1), DEBUGGABLE, aggiornamento device-clock `2026-10-12 19:18:37`; APK SHA256 `1510010be33b2201343e2fcf97b188034b71f56eb95fb76813c74be8c8d8bb3e`. Provenienza esatta verso main corrente e endpoint dell'APK **UNKNOWN**: non sostituiti con la configurazione del checkout. Solo metadata `dumpsys package/pm path/sha256sum/getprop`; nessun input/launch/reset o lettura DB Android.

Letture iOS: file journal/manifest e preferenze allowlisted; SQLite URI `mode=ro`, `query_only`, transazione SELECT aggregata chiusa con rollback. Nessun payload, ID business, nome cliente o credenziale nel dossier. Risultati in `ios-readonly-observation.json`:

- journal `sameScopeRecovery`, `staging`, `wipeCommitted=false`; generazione staging diversa dall'active manifest (non è da sola corruzione);
- identità journal ricalcolata esattamente come `automaticRecoveryResumeIdentity` corrisponde al budget persistito, `attemptCount=3`; `nextAllowedAt` già passato;
- fase persistita `recoveryRequired`, ultimo trigger `appForeground`, azione `bootstrap`, esito `failed`, errore `unknown(networkError HTTP500)`;
- lastRunCompletedAt/lastProgressAt `1791998171.3666139`, lastVerifiedAt `1784504924.2825851`, verifiedConvergence false; safety tick successivo al fallimento. Le date non hanno tutte lo stesso significato;
- diagnostica persistita signed-in, device active/canWrite true: non è una verifica attuale di autorizzazione remota o qualificazione RAM;
- store attivo: 19.775 prodotti, 41.256 righe prezzo, 83 history; 6 LocalPendingChange = 2 product +4 productPrice, tutti acknowledged; 9 eventi = 3 sent +6 localOnly body proof;
- formula attuale del contatore Options = 6, interamente dovuti ai localOnly. Le ricevute sono dati di integrità da conservare.

Gli screenshot originali non sono allegati come immagini a questa esecuzione. Sintomi layout trattati come segnalazioni finché non verificati sulla build qualificata. Nessuno screenshot/UI acceptance simulato.

## Sequenza causale del caso iOS osservato

`appForeground → admission automatic recovery → bootstrap same-scope → checkpoint/page/reconcile remoto → HTTP500 → failed/recoveryRequired → budget3 exhausted → tick foregroundPoll senza resume`.

È dimostrato il ramo che impedisce il prossimo tentativo: guard attemptCount prima del tempo, identità esatta e source poll non ammesso. Non è dimostrata qui la richiesta remota precisa che ha originato il primo 500; `sync_event_missing_entity_ids` nelle preferenze è una diagnosi persistita antecedente, non root cause automaticamente attuale. Il readback non misura lock/busy/autorità RAM né prova la traversata di push/ACK di quell'ultimo tentativo fallito.

Receipt storica `native-test-backend-500-readonly-20261014-01.json`: finestra 17:10:40–17:17:00Z, HTTP500 checkpoint/page/marker e PostgreSQL `57014`, statement_timeout=true/user_cancel=false. `exactDeviceRequestJoin=false`: correlazione temporale, non join causale. Prodotti 12.060/201 pagine erano il progresso di quella recovery, non il totale dello store attivo odierno.

Prossimo esperimento discriminante backend: su TEST ammesso, un singolo ciclo con request ID/categoria/operazione e schema/hash RPC effettivi; correlare backend lock wait/query/serialization/transport senza payload. Fermare l'esperimento al primo errore causale conservando trace; nessun rilancio identico o aumento timeout per ottenere PASS.

## Finding iOS

Path relativi sotto `iOSMerchandiseControl/`; test sotto `iOSMerchandiseControlTests/`. Ogni finding è una proposta, non una patch già fatta.

| ID / gravità | Sintomo e causa / livello di prova | File e simboli | Modifica minima / regressione |
|---|---|---|---|
| IOS-R01 P1 | Recovery non riparte: budget permanente3 più fonti ristrette. STATIC + stato persistito corrente con identità verificata. | `Sync/Automatic/Presentation/SyncStateStore.swift:320`, `automaticRecoveryAttemptEligibility`; `Sync/SyncOrchestrator.swift:429,608,733,985` | Finestra bounded riattivabile per transitori, categoria persistita e timer/evento idoneo; T04/T05/T12, terzo timeout seguito da tempo/reconnect/restart senza tap. |
| IOS-R02 P1 | HTTP500 confluisce in unknown/stringa, policy non distingue transient/stable. STATIC. | `Sync/Automatic/Core/AutomaticSyncEngine.swift:210,592`, `AutomaticSyncRetryPolicy.swift` | Mappare errori transport esistenti a esito interno strutturato; T05/T06, 429/503/timeout vs schema/403. |
| IOS-U02 P2 | Sei ricevute interne conteggiate come modifiche pending. STATIC + query corrente, nessuna perdita dati provata. | `OptionsSyncSummaryProvider.swift:280,496`, `OptionsPendingAttentionCounter.countAll`; `OptionsView.swift:262,1394`; `Sync/Automatic/Recovery/LocalCatalogBodyProofStore.swift:8,115` | Escludere localOnly dal pending cloud, distinguere errori bloccati da invii; RED 6ACK+3sent+6proof→0, poi vero pending→1; T15/T19. Non cancellare proof. |
| IOS-L01 P1 condizionale | Snapshot SDK nil toglie identità locale; transient auth e logout richiedono discriminante. STATIC, scenario da riprodurre. | `SupabaseAuthViewModel.swift:90`, `localMutationOwnerUserID`; `ContentView.swift:343`; `Task126SyncPolicy.swift:579` | Usare soltanto capacità locale già autorizzata e revocabile; T01/T06/T07 prima di patch. Mai dedurre autorizzazione dal solo binding. |
| IOS-L02 P2 | Gate privacy sostituisce TabView e Opzioni quando locale non qualificato. STATIC; gate business spesso legittimo. | `ContentView.swift:228`, `SyncReplacementPrivacyGate` | Shell e Opzioni accessibili con business protetto; A–G, dismiss/review/cancel; T07/T12/T14. |
| IOS-U01 P2 | Banner checking/error immediato su tab0/1/2 e cloud failure nella card locale. STATIC. | `SyncOrchestrator.swift:211,341`; `OptionsView.swift:1117,1308` | Resolver da capacità locale + cloud; soglia attività lunga, deduplica per episodio, azioni pertinenti; T14/T15/T18. |
| IOS-D01 P2 | Date/errori orchestrator globali senza provenance owner/shop/generation. STATIC, contaminazione visuale da testare. | `SyncStateStore.swift:65,291,418`; `OptionsView.swift:1455,2024` | Provenienza del successo; T07/T15 successo A→scope B senza attribuire data A a B. |
| IOS-Q01 P1 condizionale | Catalog first throw interrompe ciclo prima di prezzi/history indipendenti. STATIC; starvation da riprodurre. | `CatalogPushService.swift:69,157`; `AutomaticSyncEngine.swift:269` | Continuazione solo per record/domino dimostrabilmente indipendente; T11 con negativo supplier dipendente, scope error globale. |

## Finding Android

Path relativi sotto `app/src/main/java/com/example/merchandisecontrolsplitview/`; mappatura completa in IMPLEMENTATION_PLAN.

| ID / gravità | Sintomo e causa / prova | Simboli e linee | Modifica / regressione |
|---|---|---|---|
| AND-R01 P1 | Cinque tentativi recovery/window, uscita senza timer futuro; cloud gate impedisce drain ordinario. STATIC, runtime attuale NOT_RUN. | `MerchandiseControlApplication.kt:333,1649,1677,1940`, `shouldAttemptAutomaticBusinessRecovery` | Cooldown successor su stesso scope e solo transient; T04/T05/T12 con window esaurita. |
| AND-R02 P2 | History network retry ogni250ms; 429/500/503→Unknown; catalog/recovery backoff senza jitter. STATIC. | `HistorySessionPushCoordinator.kt:131,355`; `SyncErrorClassifier.kt:72` | Tassonomia e pacing condiviso semanticamente, Retry-After; T05/T06 con clock controllato. |
| AND-Q01 P1 | Event outbox transient escluso dopo5 fallimenti, anche reconnect non lo seleziona. STATIC. | `InventoryRepository.kt:6605,6737` | Separare tentativi della finestra e retryabilità durevole; T03/T05/T10; non riabilitare payload permanentemente invalido. |
| AND-Q02 P2 | Decode entityIdsJson prima del per-item catch abortisce loop e catalog cycle. STATIC. | `InventoryRepository.kt:3749,6633` | Classificare/quarantinare il record conservandolo; continuare indipendenti, T11 con malformed+valid e dipendenza negativa. |
| AND-D01 P2 | Summary recovery/blocked pubblicato come outcome, VM assegna now a lastSuccessAt e replay su nuova VM lo rinnova. STATIC. | `CatalogSyncStateTracker.kt:307`; `CatalogAutoSyncCoordinator.kt:914`; `CatalogSyncViewModel.kt:358,1051` | Timestamp e scope dell'esito effettivo, successo soltanto pertinente; T15/T19 recreation senza nuova rete. |
| AND-U01 P2 | FAILED persistente generico, non distingue offline/transient/azione; banner ricompare tra tab. STATIC. | `CloudSyncIndicator.kt:63`; `CatalogSyncStateTracker.kt:58`; `NavGraph.kt:131,238` | Proiezione UX e deduplica; preservare delay RUNNING700ms e completion800ms già esistenti; T14/T18. |
| AND-L01 P1 condizionale | Auth Initializing timeout/RefreshFailure può pubblicare SignedOut e sospendere locale; ramo Deferred già conserva utente noto. STATIC, RED richiesto. | `SupabaseAuthManager.kt:304,761`; `NavGraph.kt:687`; `MerchandiseControlApplication.kt:620` | Discriminare bootstrap cloud temporaneo da revoca/logout; T01/T06/T07 senza indebolire gate. |
| AND-P01 misura | No-work può rileggere prova canonica completa sotto transazione a intervallo2s. Impatto UNMEASURED. | `InventoryRepository.kt:5090`; `ShopSyncRecoveryCoordinator.kt:1815,2000` | Profilare T20 prima di qualsiasi cache/invalidation; non cambiare proof sulla sola ipotesi. |

## Contratti backend e limiti

Sotto `Admin/supabase/migrations/`:

- `20260722013109_cross_platform_sync_event_completeness.sql`: trigger atomici3739/4096; capabilities4720; replay evento5355–5396 (stesso ID+payload o conflict); recovery page9594 (keyset/budget/fence); event page10371 (limite1–150, scope/asOf); marker8835 chiama checkpoint completo.
- `20260722020000_task_139_recovery_runtime_lease.sql`: resolver scope8, lock SHARE61–133 su shop/profile/membership/device/mapping, auth/role/revoca e rilettura mapping. Non aggirare lease o RLS.
- `20261002150909_wechat_010_bounded_product_bytes.sql`: checkpoint761, fence841, preflight857, short refusal envelopes894–930; safety scan10000/unsafe event933–988. SHA256 `9a09b8106aa8dbb3f86365ef964cc0e6a204fc8e38440b660716ebb179f04e27`.
- `20260812010000_cross_platform_product_revision_guard.sql`: CAS timestamp additive Admin63/126, vecchi RPC compatibili. Non prova CAS per ogni mutation mobile né changed-fields universale.

BACK-01 P1 dipendenza: l'errore500 con57014 storico richiede join esatto e schema runtime; costo checkpoint/marker confermato, causa SQL precisa UNKNOWN. BACK-02 limite contrattuale: replay evento non equivale a idempotenza di ogni mutation business; T08/T10 devono usare writer mobile effettivo. BACK-03 tracking: workspace Supabase storico non può essere attestazione di TEST attuale. Nessuna migration proposta senza RED e scope dedicato.

`sync_events.id` è identity globale, fetch filtrato per scope/domain: discontinuità numerica non basta a provare gap. Price UNIQUE `(owner_user_id,product_id,type,effective_at)` e `price_idempotency_conflict` preservati; history usa remote_id, tombstone e trigger propri. Runbook Admin `docs/RUNBOOKS/wechat-recovery-checkpoint-performance.md` conserva FAIL8s e oracle120s, non acceptance terminale.

## Trigger, concorrenza e protezioni già presenti

| Trigger | iOS | Android |
|---|---|---|
| Startup/foreground | root.task/bootstrap/rootForeground; shop/device prima dell'ammissione | Application auth/shop bootstrap + foreground coordinator |
| Reconnect | NWPathMonitor debounce2s/networkReconnect | callback connectivity al coordinator/recovery |
| Session refresh/shop | invalidazione scope, qualification, rootForeground | auth lifecycle generation, ShopContext resolution, recovery trigger |
| Local save | notifica pending dopo writer lease → localMutation | Room/repo pending → catalog/history coordinator |
| Realtime | watcher per owner/shop, evento coalesced | History subscriber; catalog callback non collegata, app usa bounded foreground poll (Application:780–786) |
| Scheduler | safety foregroundPoll30s, recovery source esclusa | poll2–30s, recovery window5 tentativi |
| Background | BGAppRefresh earliest15min, discrezionale, expiration cancel, no journal | Foreground poll/device polling fermati; nessun general sync WorkManager trovato, PriceBackfillWorker è backfill locale distinto; force-stop non garantito |

Single-flight, typed stale-scope cancellation, rilascio in finally/cooperative completion e coalescing esistono; non è emersa prova di doppio motore. I test dovranno coprire callback vecchie, evento durante run, cancellation/sospensione e attività editor prolungata. Non dichiarare listener duplicati dalla sola pluralità dei trigger.

Conservare: iOS Task126 same-scope local proof, Save business+intent atomico, intent A immutabile/Save B distinta, exact ACK e trasferimento recovery; Android local capability split/NavHost stabile, ordinary outbox e recovery overlay, generation guard/join. Il layout iOS main attuale usa VStack banner+contenuto, non i vecchi `safeAreaInset/rootBannerReservedTopPadding`: nessuna patch di padding derivata dalla memoria storica. TASK-144/TASK-143 e dossier precedente rimangono fonti dei FAIL e delle prove già integrate, non attestazioni della build futura.

## Riferimenti storici riletti

- iOS `docs/TASKS/TASK-144-mobile-parity-root-cause-ios.md` e Android `docs/TASKS/TASK-143-mobile-parity-root-cause-android.md`, inclusi addenda/review/handoff.
- `/Users/minxiang/Projects/MerchandiseControl-Ecosistema/evidence/native-local-availability-20261004/n-root-final-result-draft/MERCHANDISECONTROL_MOBILE_PARITY_ROOT_CAUSE_RESULT.md`.
- Sotto `.../native-residuals-continuation-20261007-01/`: `name-cell-stable-replay-final-primary-preserving-install-20261014-01/receipt.json`; `native-resume-20261009-01/ios-language-label-regression-01/native-test-backend-500-readonly-20261014-01.json`.

Il caso A storico resta UNKNOWN; source CI e replay sintetico non lo chiudono. La propagazione iOS→Android peer-read precedente non copre inversa, editor, offline/reconnect, accessibilità o prestazioni.

## Indice dei path abbreviati

I nomi brevi usati nelle tabelle identificano questi file effettivamente presenti (linee alla baseline congelata):

- `OptionsSyncSummaryProvider.swift` → `iOSMerchandiseControl/Sync/Automatic/Presentation/OptionsSyncSummaryProvider.swift`.
- `Task126SyncPolicy.swift` → `iOSMerchandiseControl/Sync/Policy/Task126SyncPolicy.swift`.
- `CatalogPushService.swift` → `iOSMerchandiseControl/Sync/Automatic/Catalog/CatalogPushService.swift`.
- `SyncStateStore.swift` → `iOSMerchandiseControl/Sync/Automatic/Presentation/SyncStateStore.swift`.
- `AutomaticSyncEngine.swift` → `iOSMerchandiseControl/Sync/Automatic/Core/AutomaticSyncEngine.swift`.
- `LocalCatalogBodyProofStore.swift` → `iOSMerchandiseControl/Sync/Automatic/Recovery/LocalCatalogBodyProofStore.swift`.
- `SyncDecisionInputProvider.swift` → `iOSMerchandiseControl/Sync/Automatic/Decision/SyncDecisionInputProvider.swift`.
- `SyncEventOutboxState.swift` → `iOSMerchandiseControl/Sync/Outbox/SyncEventOutboxState.swift`.
- `HistorySessionPushCoordinator.kt` → `app/src/main/java/com/example/merchandisecontrolsplitview/data/HistorySessionPushCoordinator.kt`.
- `SyncErrorClassifier.kt` → `app/src/main/java/com/example/merchandisecontrolsplitview/data/SyncErrorClassifier.kt`.
- `InventoryRepository.kt` → `app/src/main/java/com/example/merchandisecontrolsplitview/data/InventoryRepository.kt`.
- `CatalogSyncStateTracker.kt` → `app/src/main/java/com/example/merchandisecontrolsplitview/data/CatalogSyncStateTracker.kt`.
- `CatalogAutoSyncCoordinator.kt` → `app/src/main/java/com/example/merchandisecontrolsplitview/data/CatalogAutoSyncCoordinator.kt`.
- `CatalogSyncViewModel.kt` → `app/src/main/java/com/example/merchandisecontrolsplitview/viewmodel/CatalogSyncViewModel.kt`.
- `CloudSyncIndicator.kt` → `app/src/main/java/com/example/merchandisecontrolsplitview/ui/components/CloudSyncIndicator.kt`.
- `NavGraph.kt` → `app/src/main/java/com/example/merchandisecontrolsplitview/ui/navigation/NavGraph.kt`.
- `SupabaseAuthManager.kt` → `app/src/main/java/com/example/merchandisecontrolsplitview/data/SupabaseAuthManager.kt`.
- `ShopSyncRecoveryCoordinator.kt` → `app/src/main/java/com/example/merchandisecontrolsplitview/data/ShopSyncRecoveryCoordinator.kt`.
