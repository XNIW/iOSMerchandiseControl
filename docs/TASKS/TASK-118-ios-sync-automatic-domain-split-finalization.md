# TASK-118: iOS Sync Automatic Domain Split Finalization

## Informazioni generali
- **Task ID**: TASK-118
- **Titolo**: iOS Sync Automatic Domain Split Finalization
- **File task**: `docs/TASKS/TASK-118-ios-sync-automatic-domain-split-finalization.md`
- **Stato**: ACTIVE
- **Fase attuale**: REVIEW
- **Responsabile attuale**: CLAUDE / Reviewer
- **Data creazione**: 2026-05-23
- **Ultimo aggiornamento**: 2026-05-24
- **Ultimo agente che ha operato**: CODEX / Reviewer-Fixer
- **Readiness**: REVIEW_PASS_WITH_NOTES; DONE resta gated da live approval/acceptance.
- **Nota workflow**: TASK-118 e' stato avviato da override esplicito utente end-to-end mentre il file era ancora in PLANNING. Codex ha eseguito HEAD/preflight, execution-audit, implementazione Swift automatic-domain, harness/test/build/smoke/evidence, senza dichiarare DONE e senza abilitare live mutation/cleanup.

## Obiettivo
Completare lo split finale della sync automatica iOS rendendo il path automatico domain-first, separato dal boundary manuale, verificabile con harness TASK-118 e senza usare DTO/result/servizi manuali nel normale runtime automatico.

## Stato corrente pianificato
- TASK-117 resta `ACTIVE / BLOCKED_EXTERNAL_LIVE_GATES`, non DONE.
- TASK-116 resta `ACTIVE / REVIEW`, non DONE.
- TASK-118 e' ora `ACTIVE / REVIEW`, non DONE, dopo execution Codex con gate locali/evidence PASS e live safety-gated non abilitato.
- Il commit hardcoded `315c2f1 / Task 117R` e' advisory; HEAD gate deve verificare dinamicamente local HEAD, `origin/main`, `git ls-remote origin main` e GitHub rendered `main`.

## Harness / Automation requirements
- Comando canonico HEAD: `./tools/agent/mc-agent.sh git head-consistency --task TASK-118`.
- Alternativa preflight reale: `./tools/agent/mc-agent.sh preflight --require-head-consistency --task TASK-118`.
- Scan canonici source: `./tools/agent/mc-agent.sh scan sync-boundaries --task TASK-118 --strict` e `./tools/agent/mc-agent.sh scan no-full-pull-normal-path --task TASK-118 --strict`.
- `ios scan ...`, se aggiunto in futuro, deve essere solo alias thin verso `scan ...`, senza logica duplicata.
- `./tools/agent/mc-agent.sh ios test automatic-domain --task TASK-118` e' distinto da `ios test sync`, perche' `ios test sync` resta regressione generale e include ancora test manual sync.
- Ogni comando TASK-118 deve usare `--task TASK-118` o `MC_TASK_ID=TASK-118`; evidence fuori da `docs/TASKS/EVIDENCE/TASK-118/` e' `FAIL` / `MISCONFIGURED`.
- MCP wrapper deve restare thin sopra `mc-agent.sh`, allowlisted, senza shell arbitraria, senza duplicare logica e senza mutare `MC_ALLOW_LIVE` o `MC_ALLOW_CLEANUP`.

## Acceptance criteria
- **CA-118-21**: harness scan `sync-boundaries` PASS con semantica CA-118.
- **CA-118-22**: harness scan `no-full-pull-normal-path` PASS con semantica CA-118.
- **CA-118-23**: evidence `.md` / `.json` / `.log` redatte.
- **CA-118-24**: nessun comando manuale quando esiste equivalente `mc-agent`.
- **CA-118-25**: HEAD dynamic verified da gate canonico.
- **CA-118-26**: MCP wrapper resta thin/allowlisted.
- **CA-118-27**: Options smoke verifica stato reale, non idle hardcoded.
- **CA-118-28**: simboli stale/fragili risolti da EXECUTION-AUDIT prima dell'execution Swift.

## Review / Done policy
TASK-118 puo' passare a REVIEW solo con HEAD, strict scans, Debug/Release, `ios test sync`, `ios test automatic-domain`, Options/root smoke, evidence scan, JSON validation, redaction e path evidence corretti tutti PASS, salvo `BLOCKED_EXTERNAL` reale dove ammesso.

TASK-118 puo' passare a DONE solo dopo REVIEW approval e live gates PASS, oppure accettazione esplicita utente per eventuali `BLOCKED_EXTERNAL` residui.

## Execution (Codex)

### Automatic-domain execution - 2026-05-23

#### Obiettivo compreso
Completare TASK-118 end-to-end sulla repo iOS principale: separare il runtime automatico dal boundary manuale, introdurre contratti/result automatici domain-first, rendere la decisione state-driven, rendere Options/root observer-only con stato reale, usare harness TASK-118 e produrre evidence redatta.

#### File controllati
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-118-ios-sync-automatic-domain-split-finalization.md`
- `docs/TASKS/EVIDENCE/TASK-118/`
- `iOSMerchandiseControl/ContentView.swift`
- `iOSMerchandiseControl/iOSMerchandiseControlApp.swift`
- `iOSMerchandiseControl/OptionsView.swift`
- `iOSMerchandiseControl/AutomaticSyncReconnectScheduler.swift`
- `iOSMerchandiseControl/SupabaseManualSyncReleaseFactory.swift`
- `iOSMerchandiseControl/SupabaseManualSyncReleaseActivityRegistrationAdapter.swift`
- `iOSMerchandiseControl/Sync/SyncAutomaticRuntime.swift`
- `iOSMerchandiseControl/Sync/SyncAutomaticRuntimeProviders.swift`
- `iOSMerchandiseControl/Sync/SyncDecisionEngine.swift`
- `iOSMerchandiseControl/Sync/SyncDecisionInputProvider.swift`
- `iOSMerchandiseControl/Sync/SyncOrchestrator.swift`
- `iOSMerchandiseControl/Sync/SyncState.swift`
- `iOSMerchandiseControl/Sync/SyncStateStore.swift`
- `iOSMerchandiseControl/Sync/SyncTrigger.swift`
- `iOSMerchandiseControl/Sync/AutomaticPushServices.swift`
- `iOSMerchandiseControl/Sync/Presentation/SyncStatusPresenter.swift`
- `iOSMerchandiseControl/SyncEventOutboxEnqueueService.swift`
- `iOSMerchandiseControl/SyncEventOutboxEntry.swift`
- `iOSMerchandiseControl/SupabaseManualSyncOutboxProducerConversions.swift`
- `iOSMerchandiseControlTests/Task115RealRootLifecycleTests.swift`
- `iOSMerchandiseControlTests/Task118AutomaticDomainTests.swift`
- `tools/agent/lib/ios.sh`

#### Piano minimo
1. Eseguire HEAD/preflight e baseline scan TASK-118 via harness.
2. Salvare execution-audit con call graph, root wiring, contaminazioni manuali, rischi e file da modificare.
3. Aggiungere test `Task118AutomaticDomainTests` e includerli in `ios test automatic-domain`.
4. Rimuovere `SupabaseManualPushService?` dal root wiring e da `SyncAutomaticRuntimeFactory.make`.
5. Introdurre result/plan automatici e `SyncAutomaticRunResult`.
6. Separare servizi automatici domain sotto `Sync/`.
7. Aggiungere `SyncDecisionInputProvider` reale con account binding, reachability, pending changes/outbox, baseline/recovery/drift e realtime status.
8. Rendere Options/root observer-only tramite `SyncStateStore`, `SyncStatusPresenter` e `OptionsSyncSummaryProvider`.
9. Rieseguire scans/build/test/smoke/evidence e aggiornare tracking.

#### Modifiche fatte
- Root automatic wiring ripulito: `ContentView` e `iOSMerchandiseControlApp` non costruiscono ne' passano piu' `SupabaseManualPushService` nel path automatico.
- `SyncAutomaticRuntimeFactory.make` non accetta piu' manual push service e crea provider automatici domain: `CatalogPushService`, `ProductPricePushService`, `HistorySessionPushService`, `SyncActivityRegistrationService`.
- Contratti automatici estesi con `SyncCatalogPushPlan/Result`, `SyncProductPricePushPlan/Result`, `SyncHistorySessionPushPlan/Result`, `SyncActivityRegistrationResult` e `SyncAutomaticRunResult`.
- `run()` non ritorna piu' `Bool`: usa esiti espliciti `success`, `noWork`, `blocked`, `busy`, `failed`, `cancelled`, `scheduledRetry`.
- `SyncStateStore` e' observer reale (`ObservableObject`) e registra ogni outcome automatico.
- `SyncDecisionInputProvider` legge stato reale da auth/account binding, reachability, pending local changes, outbox, baseline/bootstrap/recovery/drift e realtime event.
- `SyncOrchestrator` usa snapshot decisionale reale, aggiorna `SyncStateStore` e blocca bootstrap/full recovery fuori da contesti espliciti.
- `OptionsView` riceve `SyncStateStore`, rimuove `CloudSyncProgressState.idle()` hardcoded e resta observer-only.
- Conversioni outbox da result manuali spostate in `SupabaseManualSyncOutboxProducerConversions.swift`, esclusa dal boundary automatico.
- Adapter manuali conservati nel boundary manuale, senza conformare piu' ai protocolli automatici `Sync*Providing`.
- Aggiunta suite `Task118AutomaticDomainTests` e inclusione harness in `ios test automatic-domain`.
- Evidence MCP fallback per Options smoke salvata sotto `docs/TASKS/EVIDENCE/TASK-118/`.

#### Check eseguiti
- ✅ ESEGUITO — HEAD consistency finale PASS: `20260524T000229Z-git-head-consistency-task-TASK-118-p15990`.
- ✅ ESEGUITO — Preflight HEAD PASS: `20260523T233202Z-preflight-require-head-consistency-task-TASK-118-p82634`.
- ✅ ESEGUITO — Baseline scan iniziali FAIL attesi e documentati prima dello split.
- ✅ ESEGUITO — `scan sync-boundaries --strict` finale PASS: `20260524T001448Z-scan-sync-boundaries-task-TASK-118-strict-p38828`.
- ✅ ESEGUITO — `scan no-full-pull-normal-path --strict` finale PASS: `20260524T001448Z-scan-no-full-pull-normal-path-task-TASK-118-strict-p38874`.
- ✅ ESEGUITO — Build Debug PASS: `20260524T001448Z-ios-build-debug-task-TASK-118-p38829`.
- ✅ ESEGUITO — Build Release PASS: `20260524T001506Z-ios-build-release-task-TASK-118-p40203`.
- ✅ ESEGUITO — `ios test automatic-domain` PASS: `20260524T001428Z-ios-test-automatic-domain-task-TASK-118-p38177`.
- ✅ ESEGUITO — `ios test sync` PASS: `20260524T001618Z-ios-test-sync-task-TASK-118-p40975`.
- ✅ ESEGUITO — Options/root smoke PASS via XcodeBuildMCP fallback: `options-smoke-mcp.md/json/log` + screenshot. Harness primario `ios smoke options` resta BLOCKED da Accessibility/JXA: `20260523T235852Z-ios-smoke-options-task-TASK-118-p6951`.
- ✅ ESEGUITO — Supabase status redacted PASS: `20260524T000127Z-supabase-status-redacted-task-TASK-118-p11781`.
- ⚠️ NON ESEGUIBILE — Live sync matrix: safety gate refused senza `MC_ALLOW_LIVE=1`, evidence `20260524T000151Z-live-sync-matrix-task-TASK-118-prefix-TASK118_FINAL_-p12577`; necessario consenso/ambiente live esplicito per DONE.
- ✅ ESEGUITO — Sensitive/redaction scan PASS finale: `20260524T002051Z-scan-sensitive-task-TASK-118-p46437`.
- ✅ ESEGUITO — Evidence scan PASS finale: `20260524T002117Z-scan-evidence-task-TASK-118-p46871`.
- ✅ ESEGUITO — JSON validation PASS finale: `20260524T002125Z-report-validate-json-task-TASK-118-path-docs-TASKS-EVIDENCE-TASK-118-agent-runs-p50923`.
- ✅ ESEGUITO — Warning check: build Debug/Release finali non riportano warning Swift introdotti da TASK-118; i test log contengono warning preesistenti in suite legacy non modificate (`Task097RuntimeSmokeTests`, `SyncEventOutboxDrainDebugViewModelTests`, `SyncRecoveryPolicyTests`, `AccountSyncPolicyTests`) e l'avviso AppIntents metadata di Xcode.
- ✅ ESEGUITO — `git diff --check` PASS.
- ❌ NON ESEGUITO — Evidence cleanup/prune: non necessario; nessun cleanup richiesto o sicuro da eseguire in questa execution.

#### Rischi rimasti
- Catalog/ProductPrice automatic push services sono ora separati dal boundary manuale e pianificano/leggono pending domain, ma la validazione live completa resta non eseguita per safety gate `MC_ALLOW_LIVE` non abilitato.
- Harness `ios smoke options` primario resta bloccato da prerequisito esterno macOS Accessibility/JXA; il fallback MCP ha verificato Options su simulatore reale e ha prodotto evidence.
- iOS physical device, Android live e account/live matrix restano gated da prerequisiti esterni e non consentono DONE senza live PASS o accettazione esplicita utente.

#### Handoff post-execution
TASK-118 passa a `ACTIVE / REVIEW` per review Claude: HEAD, strict scans, Debug/Release, `ios test sync`, `ios test automatic-domain`, redaction/evidence/JSON e Options smoke via fallback MCP sono PASS; il comando smoke harness primario e live matrix restano esterni/gated come documentato. Non dichiarare DONE finche' review non approva e live gates non passano oppure l'utente non accetta esplicitamente i residui `BLOCKED_EXTERNAL`/safety-gated.

## Fix (Codex review)

### Review/fix pass - 2026-05-24

#### Obiettivo compreso
Eseguire review severa, indipendente e repo-grounded di TASK-118, correggendo direttamente problemi reali senza ridefinire il piano e senza dichiarare DONE. Il task resta `ACTIVE / REVIEW`.

#### File controllati
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-118-ios-sync-automatic-domain-split-finalization.md`
- `docs/TASKS/EVIDENCE/TASK-118/README.md`
- `docs/TASKS/EVIDENCE/TASK-118/agent-runs/`
- `iOSMerchandiseControl/ContentView.swift`
- `iOSMerchandiseControl/iOSMerchandiseControlApp.swift`
- `iOSMerchandiseControl/OptionsView.swift`
- `iOSMerchandiseControl/Sync/AutomaticPushServices.swift`
- `iOSMerchandiseControl/Sync/SyncAutomaticRuntime.swift`
- `iOSMerchandiseControl/Sync/SyncAutomaticRuntimeProviders.swift`
- `iOSMerchandiseControl/Sync/SyncDecisionEngine.swift`
- `iOSMerchandiseControl/Sync/SyncDecisionInputProvider.swift`
- `iOSMerchandiseControl/Sync/SyncOrchestrator.swift`
- `iOSMerchandiseControl/Sync/SyncStateStore.swift`
- `iOSMerchandiseControl/Sync/Presentation/OptionsSyncSummaryProvider.swift`
- `iOSMerchandiseControl/SupabaseInventoryService.swift`
- `iOSMerchandiseControl/SyncEventOutboxEnqueueService.swift`
- `iOSMerchandiseControl/SyncEventOutboxEntry.swift`
- `iOSMerchandiseControlTests/Task118AutomaticDomainTests.swift`
- `tools/agent/mc-agent.sh`
- `tools/agent/lib/common.sh`
- `tools/agent/lib/ios.sh`
- `tools/agent/lib/task117_scans.py`
- `tools/agent/mcp/server.mjs`

#### Piano minimo
1. Rilanciare preflight/head/config/evidence baseline.
2. Auditare automatic-domain runtime, domain services, decision provider, Options, harness/MCP/evidence.
3. Correggere solo i problemi trovati nella review.
4. Aggiungere test mirati per i bug corretti.
5. Rilanciare i gate canonici TASK-118 e aggiornare tracking/evidence.

#### Modifiche fatte
- Corretto finding P1: `CatalogPushService` e `ProductPricePushService` non sono piu' writer cosmetici/plan-only; ora scrivono via `SupabaseInventoryService` automatic domain protocols, aggiornano remote ID locali e riconoscono solo le pending changes scritte.
- Aggiunto outbox event automatico per catalogo/prezzi dopo write riuscita, cosi' `SyncActivityRegistrationService` ha lavoro reale da registrare/drainare.
- Reso idempotente il push automatico ProductPrice con deterministic ID + `upsert(..., onConflict: "id")`.
- Corretto `SyncDecisionInputProvider`: gli errori di lettura stato SwiftData non degradano piu' a falso no-work, ma producono `hasStateReadFailure` e blocco `.localStateUnavailable`.
- Rafforzata redazione errori `SyncAutomaticRuntime` usando `SyncEventOutboxPrivacySanitizer`.
- Options/root status card ora legge `syncState.lastOutcome` e distingue success/noWork/blocked/busy/failed/cancelled/retry con microcopy localizzata EN/IT/ES/ZH.
- Aggiunto cancel del drift task in `OptionsSyncSummaryProvider.deinit`.
- Estesi `Task118AutomaticDomainTests` per write remoto reale, outbox automatico, state-read failure, redaction e UI outcome binding.
- Salvata evidence fallback MCP Options sotto `docs/TASKS/EVIDENCE/TASK-118/30-review-options-smoke-mcp-fallback.md` e screenshot dedicato.

#### Check eseguiti
- ✅ ESEGUITO — HEAD consistency PASS: `20260524T005749Z-git-head-consistency-task-TASK-118-p88863`.
- ✅ ESEGUITO — Preflight require HEAD PASS: `20260524T005749Z-preflight-require-head-consistency-task-TASK-118-p88864`.
- ✅ ESEGUITO — Config validate PASS: `20260524T005749Z-config-validate-task-TASK-118-p88881`.
- ✅ ESEGUITO — `scan sync-boundaries --strict` PASS: `20260524T010037Z-scan-sync-boundaries-task-TASK-118-strict-p92435`.
- ✅ ESEGUITO — `scan no-full-pull-normal-path --strict` PASS: `20260524T010038Z-scan-no-full-pull-normal-path-task-TASK-118-strict-p92467`.
- ✅ ESEGUITO — Build Debug PASS: `20260524T010042Z-ios-build-debug-task-TASK-118-p93293`.
- ✅ ESEGUITO — Build Release PASS: `20260524T010049Z-ios-build-release-task-TASK-118-p93881`.
- ✅ ESEGUITO — `ios test automatic-domain` PASS: `20260524T010013Z-ios-test-automatic-domain-task-TASK-118-p91771`.
- ✅ ESEGUITO — `ios test sync` PASS: `20260524T010200Z-ios-test-sync-task-TASK-118-p94650`.
- ⚠️ NON ESEGUIBILE — Harness primario `ios smoke options` resta BLOCKED da Accessibility/JXA: `20260524T010451Z-ios-smoke-options-task-TASK-118-p95638`.
- ✅ ESEGUITO — Options smoke fallback XcodeBuildMCP PASS: `30-review-options-smoke-mcp-fallback.md` + `options-smoke-mcp-fallback-20260524T0106.jpg`.
- ✅ ESEGUITO — Supabase status redacted PASS: `20260524T010718Z-supabase-status-redacted-task-TASK-118-p5263`.
- ⚠️ NON ESEGUIBILE — Live sync matrix refused da safety gate senza `MC_ALLOW_LIVE=1`: `20260524T010803Z-live-sync-matrix-task-TASK-118-prefix-TASK118_FINAL_-p6201`.
- ✅ ESEGUITO — Sensitive/redaction scan PASS: `20260524T010656Z-scan-sensitive-task-TASK-118-p97345`.
- ✅ ESEGUITO — Evidence scan PASS: `20260524T010809Z-scan-evidence-task-TASK-118-p6619`.
- ✅ ESEGUITO — JSON validation PASS: `20260524T010827Z-report-validate-json-task-TASK-118-path-docs-TASKS-EVIDENCE-TASK-118-agent-runs-p14094`.
- ✅ ESEGUITO — `git diff --check` PASS.
- ✅ ESEGUITO — Warning check: build/test log finali non contengono warning/error nei file modificati da questa review; restano warning preesistenti in test legacy e AppIntents metadata processor.

#### Rischi rimasti
- Live matrix non eseguita: serve `MC_ALLOW_LIVE=1` e consenso esplicito per mutazioni live scoped con prefisso `TASK118_FINAL_`.
- Harness primario Options smoke dipende da Accessibility/JXA e resta BLOCKED; fallback MCP e' valido ma non trasforma il primary gate in PASS.
- L'outcome live end-to-end di catalogo/prezzi/history/realtime resta da validare con matrix live prima di DONE.

#### Handoff post-fix
Verdict Codex review: `REVIEW_PASS_WITH_NOTES`. TASK-118 resta `ACTIVE / REVIEW`, responsabile `CLAUDE / Reviewer`, non DONE. Prossimo passo: review Claude dei fix/evidence e decisione su live gate (`MC_ALLOW_LIVE=1`) o accettazione esplicita dei residui `BLOCKED_EXTERNAL`.

### Harness foundation implementation - 2026-05-23

#### Obiettivo compreso
Implementare solo il foundation harness/tracking di TASK-118: comando HEAD, scan CA-118, suite iOS automatic-domain, path/evidence guard TASK-118, MCP allowlist TASK-118 e documentazione minima. Vietati Swift/Kotlin/SQL, build/test/runtime, Supabase live e cleanup.

#### File controllati
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-117-ios-sync-final-architecture-cleanup.md`
- `AGENTS.md`
- `tools/agent/mc-agent.sh`
- `tools/agent/lib/common.sh`
- `tools/agent/lib/ios.sh`
- `tools/agent/lib/task117_scans.py`
- `tools/agent/mcp/server.mjs`
- `tools/agent/README.md`

#### Piano minimo
1. Aggiungere dispatch `git head-consistency` e `preflight --require-head-consistency`.
2. Aggiungere scan top-level `scan sync-boundaries` e rendere `scan no-full-pull-normal-path --task TASK-118` CA-118-aware.
3. Aggiungere `ios test automatic-domain`.
4. Applicare guard evidence TASK-118 e parser `report validate-json --task`.
5. Aggiornare MCP allowlist con tool TASK-118 thin sopra `mc-agent.sh`.
6. Aggiornare tracking/evidence README senza dichiarare REVIEW/DONE.

#### Modifiche fatte
- Harness dispatcher esteso con `git head-consistency`, `scan sync-boundaries`, preflight arg-aware.
- `common.sh` esteso con HEAD consistency dinamica, guard evidence TASK-118, `report validate-json --task`, help/list aggiornati.
- Scanner Python esteso con scan CA-118 `sync-boundaries` e `no-full-pull-normal-path` task-aware.
- `ios test automatic-domain` aggiunto come suite separata da `ios test sync`.
- MCP wrapper aggiornato con allowlist TASK-118/generic task-safe per HEAD, preflight, scans, automatic-domain e JSON validation.
- README harness aggiornato con comandi canonici TASK-118.

#### Check eseguiti
- ❌ NON ESEGUITO — Build Debug/Release: vietato dal prompt utente.
- ❌ NON ESEGUITO — iOS test sync / automatic-domain: vietato dal prompt utente.
- ❌ NON ESEGUITO — Runtime/smoke Options/root: vietato dal prompt utente.
- ❌ NON ESEGUITO — Supabase live/status: vietato dal prompt utente.
- ❌ NON ESEGUITO — Cleanup/evidence prune: vietato dal prompt utente.
- ✅ ESEGUITO — Lettura statica repo/tracking/harness prima delle modifiche.

#### Rischi rimasti
- Gli scan CA-118 sono attesi FAIL finche' lo split Swift automatic-domain non verra' implementato in una fase EXECUTION esplicita.
- `ios test automatic-domain` punta ai test automatic-domain esistenti; i test specifici per nuovi servizi automatici dovranno essere aggiunti quando quei servizi Swift saranno implementati.
- HEAD/preflight/scan/report commands non sono stati eseguiti in questo turno per vincolo utente; la verifica reale resta `NOT_RUN`.

#### Handoff post-execution
Nota storica del turno foundation-only: al termine di quel passaggio TASK-118 restava `ACTIVE / PLANNING`; lo stato corrente e' aggiornato nella sezione automatic-domain execution sopra come `ACTIVE / REVIEW`.
