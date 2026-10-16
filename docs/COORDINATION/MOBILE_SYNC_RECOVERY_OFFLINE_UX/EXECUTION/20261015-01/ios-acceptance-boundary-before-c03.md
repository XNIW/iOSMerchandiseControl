# iOS — confine delle prove locali e accettazione finale

Snapshot documentale UTC: 2026-10-16T05:20:42Z. Coordinamento `MOBILE_SYNC_RECOVERY_OFFLINE_UX`, task iOS `TASK-145`. Questo documento mappa la [matrice canonica CA01–CA12/T01–T20](../../TEST_MATRIX.md) agli artifact già prodotti. Non modifica criteri, sorgenti, test, tracking o storico e non dichiara DONE. I campi finali sono riservati al runner/root dopo il freeze conclusivo.

Repository: `/Users/minxiang/Desktop/iOSMerchandiseControl`; HEAD di partenza `314cf5332d0b889331802a3f886c1910b9b377b0`, con modifiche locali del candidato non committate e configurazione preesistente preservata. La suite canonical02 identifica il candidato con 19 hash di file, non con un nuovo commit. Eventuali fix successivi richiedono il proprio manifest e non ereditano automaticamente quel risultato.

## Prove effettive disponibili

| Riferimento | Risultato verificato | Perimetro e limite |
|---|---|---|
| C02: [summary](ios-canonical-02-summary.json), [test tree](ios-canonical-02-tests.json), [input](ios-canonical-02-input.json), [output](ios-canonical-02-output.json) | **FAIL**, exit65: 1623 casi, 1582 PASS / 5 FAIL / 36 SKIP. UNIT: 1563 PASS / 5 FAIL / 36 SKIP; UI: **19/19 PASS**. Pin 19/19 invariati. | Suite canonica completa su Simulator sintetico posseduto `0674B959-5A88-49CA-AD70-33075F40CE9D`, iPhone 15 Pro Max, iOS26.1/23B86 arm64, ambiente macOS 27.0.1. È esecuzione locale; non CI, installazione utente, sessione reale o server TEST. I cinque FAIL unitari impediscono di chiamare il gate canonico GREEN. |
| U02: [RED](ios-u02-red-summary.json), [GREEN](ios-u02-green-summary.json), [pin](ios-u02-green-output.json), [review](../REVIEWS/IOS_U02.md) | RED 5 PASS / 1 FAIL; GREEN **6 PASS**, exit0. Gli stessi sei test Options sono PASS anche in C02. Review `APPROVED_LOCAL_DELTA`. | 6 ACK + 3 sent + 6 localOnly producono count 0, poi count 1 con un vero pending; record/proof non eliminati. È prova UNIT del conteggio, non terminalità cloud di una sessione installata. |
| R4: [summary](ios-retry-candidate4-summary.json), [pin](ios-retry-candidate4-output.json), [review](../REVIEWS/IOS_RETRY_CANDIDATE4.md) | **252 PASS / 0 FAIL / 0 SKIP**, exit0, 14 pin invariati; review locale approvata sul proprio freeze. | Cinque classi complete; retry, claim, timer, prefix, cancellation/authority e ripresa locale. C02 successivo introduce cinque FAIL più ampi: il precedente GREEN non chiude il candidato finale. |
| D2: [summary](ios-d01-candidate2-summary.json), [pin](ios-d01-candidate2-output.json), [review](../REVIEWS/IOS_D01_CANDIDATE2.md) | **261 PASS / 0 FAIL / 0 SKIP**, exit0, 16 pin invariati; review locale approvata sul proprio freeze. | Origine completa della finalization, date A→B/reopen, epoch e decoder rigoroso. Ulteriori residui errore/proiezione/prima pubblicazione sono stati qualificati dopo questo freeze; non sono coperti dalla sua approvazione. |
| ER: [errore A→B](ios-d01-error-red-summary.json); PR: [projection RED](ios-d01-projection-red-summary.json) | ER: **1 FAIL** qualificato; PR: **2 PASS / 2 FAIL** qualificati. Originali preservati. | Errori/tempi A attribuiti a B e hydration legacy/envelope incoerente; correzioni successive non ancora certificate dal gate finale in questo snapshot. |
| FT: [final qualifiers](ios-d01-final-qualifiers-red-summary.json), [qualificazione runner](ios-d01-final-qualifiers-red-output.json) | Prima vera finalization Engine/Atomic mai pubblicata: **RED qualificato**, tre assert data live/JSON/reopen T1 anziché T0. | Observation originale conserva T0; prima pubblicazione ritardata di un'ora. Il secondo test di quel batch aveva un errore fixture di expectation non attesa: non è un RED ownership di prodotto. |
| HB: [held bootstrap qualificato](ios-d01-held-bootstrap-qualified-summary.json) | **1 PASS / 0 FAIL / 0 SKIP**, exit0, dopo riparazione della sola attesa fixture. | B ha realmente attivato la propria generazione con claim in-flight; A non modifica B; B pubblica e ritira il proprio claim. Vale sulla produzione C02; non cancella gli altri FAIL. |
| PRES: [preservazione](protected-state-check-04.json) | Alle 04:52:51UTC HEAD/index/stash/worktree dei due repo e cinque file protetti invariati rispetto alla baseline. | È prova di preservazione a quell'istante. Controllo finale dopo gli ultimi fix: **PENDING root**. Installazioni/dati/sessioni utente non sono stati usati per queste prove. |

C02 conserva tre runtime warning QoS. R4/D2 conservano warning QoS; il cleanup SwiftData di fixture ha inoltre warning storici conservati nei log. Nessuna dichiarazione di assenza di warning o di regressione prestazionale risolta deriva dai conteggi PASS.

## CA01–CA12: prova disponibile e gate mancante

Nella colonna locale, PASS indica solo gli specifici sottocasi nominati. Il criterio comune resta aperto quando manca una delle prove obbligatorie; non si converte un risultato UNIT o UI sintetico in accettazione globale.

| CA | Prove iOS locali effettive | Confine dell'accettazione / stato da completare |
|---|---|---|
| CA01 | C02: manifest19/pin invariati; PRES: WIP/config/HEAD/index preservati all'istante registrato. | Binario finale/config/ambiente/installazione legati da receipt: **NOT_RUN**; manifest conclusivo e ricontrollo preservazione **PENDING root**. Installazione corrente distinta dagli output di build rigenerabili. |
| CA02 | C02 UI PASS: shell con recovery held, editor/draft, Save e navigazione; auth lifecycle 27 e owner/store 46 UNIT PASS. | Cold start offline nelle varianti SDK/sessione, ricerca/editor/Save con readback durevole nell'app candidata installata: **NOT_RUN**. I test di shell non certificano ogni variante offline. |
| CA03 | R4 PASS: finestra automatica, opportunità futura, reopen/timer/backoff e intent conservati. | C02 ha FAIL cancellation/successore da chiudere. Ripresa automatica installata dopo outage/restart: **NOT_RUN**. Legacy già exhausted senza categoria tipizzata: liveness di upgrade **UNKNOWN**. |
| CA04 | C02 owner/store 46 UNIT PASS e UI previous-shop PASS; D2 epoch/scope PASS; HB PASS sul proprio sottocaso. | Tre FAIL Atomic C02 legati a rifiuto authority/ritiro slot e due FAIL Task119 non ancora chiusi dal gate finale. Revoca/cambio scope su sessioni TEST reali: **NOT_RUN**. |
| CA05 | C02 `Task126ConflictReviewTests` 4 PASS; accumulator 19 PASS; apply incrementale 63 PASS/1 SKIP. Policy merge/review e changedFields hanno copertura locale. | Writer reale bidirezionale con base/current/intent e conflitto deciso nelle app TEST: **NOT_RUN**; nessuna inferenza di merge server da policy UNIT. |
| CA06 | C02 UI ACK/replay immutabile e Save con history indipendente PASS; Atomic lostACK prezzo/history e reopen PASS; enqueue 35 / drain 32 UNIT PASS. | Gate finale candidato ancora aperto; roundtrip installato per ID/revision/body e duplicati server: **NOT_RUN**. |
| CA07 | C02 drain 32 PASS, inclusi corrupt/legacy block, exhausted head→later retryable, retryable failure→next entry, scope/cancel rollback; planner 12 PASS. | Scenario completo stable-invalid + indipendente + dipendenza supplier/product nelle app/TEST: **NOT_RUN**. Nessun legacy invalido viene riclassificato come transient per farlo ripartire. |
| CA08 | C02 Atomic 155  PASS / 3 FAIL, contract 26 PASS, recovery adapter 6 PASS; UI shell/recovery/cutover PASS. | Tre FAIL Atomic e regressione conclusiva aperti; certificazione recovery A–G installata e senza perdita su TEST: **NOT_RUN**. Causa storica iOS A: **UNKNOWN**. |
| CA09 | U02 conteggi PASS; D2 date/provenance PASS; C0219 UI PASS nel proprio ambito; ER/PR/FT conservano RED pertinenti. | Correzioni errore/hydration/ownership/tempo prima pubblicazione e regressione finale **PENDING root**. Nessun PASS complessivo della presentazione né accettazione utente ancora. |
| CA10 | C02 UI19 PASS: quattro lingue/font grande, banner default/AXXXL, filtri/editor, input e draft. | Tutte tab/stati/light-dark/font e ultima riga come matrice completa, VoiceOver operativo e giudizio operatore/fisico: **NOT_RUN**. I19 UI non verificano da soli ogni cella T18. |
| CA11 | C02 comprende replay/apply/no-work UNIT e UI feedback locale; nessun roundtrip inter-device viene dedotto. | Bidirezionale TEST create/update/delete/prezzi/history e no-op30 cicli/target prestazioni: **NOT_RUN**. Schema/protocollo/server corrente e autorizzazioni della futura lane: **UNKNOWN** senza receipt specifica. |
| CA12 | Review U02/R4/D2 approvate esclusivamente sui rispettivi manifest; C02 completo eseguito ma **FAIL**. | Regression finale, Debug/Release/analyze, review finale, CI exact-SHA, integrazione e conferma finale: **PENDING root / NOT_RUN** secondo tabella finale. Nessun DONE. |

## T01–T20: corrispondenza operativa

| Test | Sottoprove iOS effettive | Prova mancante / stato del caso completo |
|---|---|---|
| T01 | C02: auth lifecycle 27 / owner-store 46 UNIT PASS; UI shell held e empty bootstrap PASS. | Cold start candidato con rete già assente, cached/Initializing/nil e timestamp first-frame/data: **NOT_RUN**. |
| T02 | C02 UI input numerico/draft/correction/Save e query/filter PASS; Saved/UnsavedIntentAcrossCutover PASS. | Sequenza offline T01→search→editor nome/prezzo→Save/readback per ID e fallimento disco del caso completo: **NOT_RUN**. |
| T03 | C02 Atomic lostACK prezzo/history, replay originale/reopen e drain terminale PASS. | Restart non distruttivo delle app candidate con perdita risposta reale e ledger/peer correlato: **NOT_RUN**. |
| T04 | R4 UNIT clock/transport PASS per opportunità dopo budget e timer automatico; nessun tap artificiale richiesto dal test. | Ritorno rete su app installata e trigger→ACK→peer/readback TEST: **NOT_RUN**; ripresa legacy exhausted priva di categoria **UNKNOWN**. |
| T05 | R4 policy/claim/backoff/RetryAfter/prefix/timeout PASS nel freeze dichiarato. | Fault runtime pre/postcommit/429/500/503/DNS e conteggi fisici/RPC su fixture isolata installata: **NOT_RUN**; regressione conclusiva **PENDING root**. |
| T06 | C02 `SupabaseAuthLifecycleTests`27 PASS e signout 1 PASS. | Sessione test reale, refresh differito/SDKnil/local capability e logout esplicito in app installata: **NOT_RUN**. |
| T07 | D2 full identity/epoch e held completion PASS; C02 UI previous-shop PASS; owner/store UNIT46 PASS; HB PASS. | Tre Atomic FAIL C02 e riprova finale da chiudere; due scope TEST reali/revoca/UI spiegazione: **NOT_RUN**. |
| T08 | C02 accumulator/coalescing e review mergeable-vs-review PASS; contesto UNIT changedFields conservato. | Due device con edit disgiunti reali e readback campi/ref/prezzi non riscritti: **NOT_RUN**. |
| T09 | C02 `testDeleteVsEditRoutesToReview`, policy prezzo stesso slot e UI review locale PASS. | Scelta operatore nel conflitto reale tra due app e dato finale backend/peer: **NOT_RUN**. |
| T10 | C02 UI `CurrentProductACKWithIndependentHistorySurvivesImmutableCommittedResponseReplay` PASS; Atomic lostACK prezzo/history con Save successivo e drain PASS. | Commit/ACK perso e SaveB in app installata più unicità server per ID/revision: **NOT_RUN**. |
| T11 | C02 outbox drain 32 PASS, inclusi head exhausted/nonblocking, corrupt/legacy blocco e scope/cancel; planner 12 PASS. | Intera matrice malformed/stable/dependency supplier→product con ledger app/TEST: **NOT_RUN**. |
| T12 | C02 Atomic 155 PASS / 3 FAIL; R4 prefix resumption/lease/claim PASS; shell/empty qualification UI PASS. | Tre FAIL Atomic C02 restano aperti; interrupt B–G installato e recovery A–G reale **NOT_RUN**; storico A **UNKNOWN**. |
| T13 | C02 real UI Saved/UnsavedIntentAcrossCutover PASS; Atomic cutover, lostACK e writer stale qualificati nei sottocasi PASS. | Editor app candidata installata durante pagine/cutover con revision/readback TEST e interruzione lifecycle: **NOT_RUN**. |
| T14 | C02 real root/navigation/options, draft conservato e filtri/search/editor PASS nel run UI sintetico. | Sessione di10 min editing normale, quiet gap, focus/selection/scroll a tutte le condizioni della matrice: **NOT_RUN**. |
| T15 | U02 6 PASS e C02 Options6 PASS; D2 date epoch/reopen PASS; ER/PR/FT RED pertinenti preservati. | Fix/errori/proiezione/prima data e review/regressione finale **PENDING root**; tab/remount installato **NOT_RUN**. |
| T16 | Nessuna prova nuova di due app reali/TEST; i test apply/replay locali C02 sono sottoprove UNIT. | Entrambe direzioni create/update/delete/ref/prezzi/history, ID/versione/tombstone, manifest fixture/cleanup esatto: **NOT_RUN**. |
| T17 | PRES attesta preservazione sorgenti/config; nessuna installazione o upgrade effettuato. | Debug→Release e Release→Release non distruttivi con DB/pending/journal/draft/sessione e receipt packaging/signature/hash: **NOT_RUN**. Stato reale upgrade legacy **UNKNOWN**. |
| T18 | C0219 UI PASS includono quattro lingue/font grande, banner default e AccessibilityXXXL, filtri/editor. | Griglia completa tutti stati/tab/font/light-dark, AX/VoiceOver effettivo, tastiera/focus e fisico: **NOT_RUN**. |
| T19 | C02 U02/noWork/drain/replay e date duplicate/reopen hanno PASS locali; prima data FT e proiezione PR conservano FAIL. |30 cicli no-op con VM/tab/duplicati su app installata, DB diff e trace richieste: **NOT_RUN**; finale UNIT **PENDING root**. |
| T20 | C02 raccoglie una metrica XCTest, che non è il protocollo T20. Nessun risultato T20 promosso da essa. | Dataset20k prodotti / ≥40k prezzi,30 campioni / direzione,Save / no-work idle+recovery,CSV raw/p50 / p95 / max / lock/profiling nativo: **NOT_RUN**. |

## Cinque FAIL canonici da conservare

C02 conserva questi test falliti; un successivo PASS deve indicare artifact e manifest nuovi, senza riscrivere il risultato originale:

1. `Task119AutomaticArchitectureTests/testImmediateRetryAfterCancellationRunsWhenCancelledFlightFinishes` — reconciling anziché idle.
2. `Task119AutomaticArchitectureTests/testOrchestratorAcceptsVerifiedTerminalCommitAfterOuterCancellation` — recoveryRequired anziché idle.
3. `AtomicGenerationRecoverySnapshotPullServiceTests/testOrdinaryContinuationReceiptRejectsChangedAuthority` — pullingEvents anziché recoveryRequired.
4. `AtomicGenerationRecoverySnapshotPullServiceTests/testOrdinaryContinuationRejectsReplacementContainerAndOtherDefaults` — pullingEvents anziché recoveryRequired.
5. `AtomicGenerationRecoverySnapshotPullServiceTests/testRejectedHeldTerminalReleasesOnlyItsForegroundSlotAndCoalescesNextAdmission` — successoreB non entra entro la expectation originale.

Le36 SKIP restano SKIP: includono Task072DLiveAcceptanceHarness 2, Task097RuntimeSmoke 1, Task098CrossPlatformSmoke 4, Task100LargeDatasetAcceptance 9, Task103CrossPlatformAcceptance 14, Task105RealOpsClosure 1 e altri 5. I loro nomi non sono prove di esecuzione live/crossplatform/performance. Non è stata introdotta alcuna esclusione per rendere verde questa mappatura.

## Completamento riservato al root

| Gate finale | Stato a questo snapshot | Artifact / pin da registrare dal root |
|---|---|---|
| Freeze finale sorgenti/config/test | **PENDING** | Manifest, patch immutabile, hash, UTC, differenze dal C02. |
| Regressione qualificatori e suite canonica dopo fix | **PENDING** | Comando/exit, summary/xcresult/testtree, conteggi UNIT/UI/SKIP,pin del manifest finale o manifest finale completo; esito dei 5 FAIL C02 e RED ER/PR/FT. |
| Debug build | **PENDING** | Comando, config, destination,exit, log,hash output se esportato. |
| Release build | **PENDING** | Comando, config, destination,signing state,exit, log,hash output se esportato. Build non equivale a installazione. |
| Analyze e confronto warning / controllo sensibili | **PENDING** | Comando,exit, log,classificazione warning baseline/nuovi, perimetro scan e receipt senza valori sensibili. |
| Review indipendente finale | **PENDING** | Reviewer distinto, manifest esatto, finding disposition e limite APPROVED_LOCAL_DELTA. |
| Preservazione WIP/config/installazioni | **PENDING** | Ricontrollo finale contro baseline, output rigenerati separati da binari/receipt probatori preesistenti. Nessun reinstall/reset/logout richiesto da questo documento. |
| CI exact-SHA candidato | **NOT_RUN** | Richiede candidato integrabile e autorizzazione separata ove necessaria; la CI di main antecedente non certifica il WIP finale. |
| Collaudo nativo app candidata installata / TEST / fisico / operatore | **NOT_RUN** | Lane autorizzata, lineage binary/config/install, scope/dataset/fixture isolata, readback e giudizio umano; nessuna credenziale in documento/log. |
| Upgrade legacy exhausted senza classificazione | **UNKNOWN** | La policy failclosed preserva il dato e non prova la liveness della vera installazione legacy. Serve una prova upgrade pertinente. |
| Accettazione comune e DONE | **NOT_RUN** | Prove comuni CA/T sulle revisioni dichiarate e conferma finale. Nessun PASS derivato da sola build/CI/UI19. |

Documento redatto soltanto da lettura della matrice e degli artifact nominati. Nessuna invocazione SDK, test, build, device o nuova scena/asserzione è stata eseguita per produrlo.
