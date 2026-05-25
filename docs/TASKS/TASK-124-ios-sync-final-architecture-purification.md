# TASK-124: iOS Sync Final Architecture Purification and Residue Eradication

## Informazioni generali
- **Task ID**: TASK-124
- **Titolo**: iOS Sync Final Architecture Purification and Residue Eradication
- **File task**: `docs/TASKS/TASK-124-ios-sync-final-architecture-purification.md`
- **Evidence dir**: `docs/TASKS/EVIDENCE/TASK-124/`
- **Stato**: DONE
- **Fase attuale**: SIMULATOR_EMULATOR_SCOPE_VERIFIED
- **Responsabile attuale**: USER / Accepted simulator-emulator closure
- **Data creazione**: 2026-05-25
- **Ultimo aggiornamento**: 2026-05-25 17:52 -0400 — review/fix finale completato; simulator/emulator/Supabase scope verified; physical/background/long-offline real-device deferred to TASK-125
- **Ultimo agente che ha operato**: CODEX / Reviewer+Fixer
- **Tipo task**: architecture purification execution/review closure; planning storico conservato sotto per tracciabilita'.
- **Readiness**: DONE_BY_USER_OVERRIDE_FOR_TASK124_SCOPE. Override esplicito utente 2026-05-25: Codex autorizzato a fare review/fix/check iterativi e chiudere TASK-124 a DONE solo nel perimetro iOS Simulator + Android Emulator `emulator-5554` + Supabase linked/local. Il DONE non copre iPhone fisico, Android fisico, locked/background, long-offline real-device o production globale; questi restano deferred TASK-125.

## Execution
### Avvio execution — 2026-05-25 11:12 -0400
- User override ricevuto: avvio end-to-end execution autorizzato per Swift, harness CLI, scanner, refactor strutturali, debugging, test automatici/manuali, simulatori/emulatori/device se disponibili, Supabase live/dev scoped e cleanup sicuro task-scoped.
- Divieti confermati: no schema/RLS/grant/RPC changes salvo blocker separato Supabase; no service_role client; no RLS bypass lato app; no cleanup globale; no `auth.users` delete; no hidden manual sync; no full pull normal path; no claim 100%/DONE.
- Lettura iniziale obbligatoria completata: `docs/MASTER-PLAN.md`, TASK-124, evidence README TASK-124, TASK-123 file/evidence, TASK-122 file/evidence.
- Canonical snapshot pre-execution: local HEAD `951547ab1e4ed63a9f6a730c293ee278a67ef17c`; origin/main `951547ab1e4ed63a9f6a730c293ee278a67ef17c`; `git ls-remote origin refs/heads/main` `951547ab1e4ed63a9f6a730c293ee278a67ef17c`.
- Piano minimo Codex: aggiornare tracking a EXECUTION; eseguire harness discovery/preflight canonical; creare/migliorare scanner TASK-124 con fixture RED/GREEN; produrre inventory/call-site/pbx evidence; poi refactor Swift a slice minime solo dopo scanner self-test.
- File previsti iniziali: `docs/MASTER-PLAN.md`, `docs/TASKS/TASK-124-ios-sync-final-architecture-purification.md`, `docs/TASKS/EVIDENCE/TASK-124/README.md`, `docs/TASKS/EVIDENCE/TASK-124/agent-runs/`.

### Handoff post-execution — 2026-05-25 11:39 -0400
- Refactor applicati: split ProductPrice remote in automatic/preview/manual-push/release composite; split Options counts fuori da `SyncEventRemoteSupabaseAdapter`; naming transport corretto in app/root/factory; wrapper legacy `SupabaseManualSyncAggregatedPushOutboxProducer.swift` e marker `SyncAutomaticRuntime.swift` rimossi; test aggiornati ai nuovi boundary.
- Harness applicato: `tools/agent/lib/task124_scans.py`, fixture RED/GREEN `tools/agent/fixtures/task124_scanners/`, routing `mc-agent.sh`, discovery `help-json`/`commands-json`, inventory/pbx/evidence JSON+Markdown.
- PASS locali: scanner TASK-124 + self-tests; iOS Debug/Release build; iOS `sync`, `automatic-domain`, `automatic-architecture`, `manual-sync-regression`; Android build/debug sync/offline/offline-tier; Supabase linked schema/RLS/grants/contract read-only; sensitive/evidence/repo-diff; cleanup dry-run/residue `TASK124_`.
- BLOCKED_EXTERNAL: offline/reconnect live matrix and TASK-123 speed regression live gates require `MC_ANDROID_DEVICE_SERIAL`; `supabase status-redacted` requires local Supabase CLI/Docker stack; `ios smoke options` requires macOS Accessibility/JXA permission.
- Stato finale Codex: `BLOCKED / BLOCKED_EXTERNAL_LIVE_DEVICE`. Nessun `DONE`, nessun `REVIEW PASS`, nessun claim 100% o production globale.
- Evidence finale: `docs/TASKS/EVIDENCE/TASK-124/final-handoff.md`, `offline-reconnect-matrix.md/json`, `automation-discovery.md/json`, `harness-routing.md/json`, `file-inventory.md/json`, `pbxproj-target-membership.md/json`, agent reports in `agent-runs/`.

### Ripresa simulator/emulator scope — 2026-05-25 13:10 -0400
- Decisione utente recepita: device fisici esclusi da TASK-124; iPhone fisico, Android fisico, locked/background/long-offline real-device rimandati a TASK-125.
- Preflight TASK-124 PASS: `20260525T170629Z-preflight-task-TASK-124-p28599`.
- Head consistency PASS: `20260525T170629Z-git-head-consistency-task-TASK-124-p28600`; local HEAD/origin/main/ls-remote allineati su `6e8ee53b89be42be84b9d5645ff19379a5bc137b`.
- Supabase `status-redacted` PASS: `20260525T170629Z-supabase-status-redacted-p28677`; precedente blocker Docker/local stack risolto.
- Android Emulator boot fallback documentato: `adb` non era nel PATH shell, usato SDK locale per avviare AVD `Medium_Phone_API_35`; seriale emulator-only selezionato `emulator-5554`; nessun device fisico usato.
- Android auth-preflight live PASS con `MC_ANDROID_DEVICE_SERIAL=emulator-5554`: `20260525T170833Z-android-auth-preflight-live-p32621`.
- iOS smoke simulator PASS: `20260525T170848Z-ios-smoke-simulator-p33393`.
- iOS auth-preflight live resta BLOCKED_EXTERNAL: `20260525T170716Z-ios-auth-preflight-live-task-TASK-124-p30454` e retry `20260525T170916Z-ios-auth-preflight-live-task-TASK-124-p34245` falliscono con sessione iOS non scaduta assente. Next action harness: aprire app, completare login/session restore, poi retry.
- Gate non eseguiti per assenza sessione iOS Simulator: offline/reconnect simulator/emulator, TASK-123 speed regression simulator/emulator, runtime parity/near realtime. Stato finale ripresa: `ACTIVE / BLOCKED_EXTERNAL_SIMULATOR_ENV`, non `REVIEW`, non `DONE`.

### Handoff post-execution — 2026-05-25 16:23 -0400
- User override applicato: TASK-124 chiude il perimetro iOS Simulator + Android Emulator `emulator-5554` + Supabase linked/local; device fisici, locked/background/long-offline real-device restano `DEFERRED_TO_TASK-125`.
- iOS Simulator auth blocker risolto con polling documentato: smoke simulator PASS `20260525T192132Z-ios-smoke-simulator-p46903`; auth-preflight live PASS `20260525T192259Z-ios-auth-preflight-live-task-TASK-124-p48048`.
- Fix harness mirati applicati: `TASK124_` ammesso nei fixture live iOS/Android di `Task103CrossPlatformAcceptanceTests`; no-op speed harness non include piu' un `sleep 1` artificiale nel budget misurato e registra `settleSeconds`.
- Offline/reconnect simulator/emulator PASS: `20260525T192951Z-live-offline-reconnect-sync-task-TASK-124-prefix-TASK124_OFFLINE_SIM_-p59570`.
- TASK-123 speed regression simulator/emulator PASS: single propagation `20260525T193243Z-live-task123-single-propagation-task-TASK-124-prefix-TASK124_SPEED_SIM_-p64766`; no-op `20260525T195458Z-live-task123-noop-task-TASK-124-prefix-TASK124_SPEED_SIM_-p17878`; burst-10 `20260525T195639Z-live-task123-burst-10-task-TASK-124-prefix-TASK124_SPEED_SIM_-p21549`; cold-restart `20260525T200412Z-live-task123-cold-restart-task-TASK-124-prefix-TASK124_SPEED_SIM_-p36557`.
- Runtime gates PASS: mutation-near-realtime `20260525T200943Z-live-mutation-near-realtime-task-TASK-124-prefix-TASK124_RT_SIM_-p49942`; runtime-parity PASS after explicit Android full-pull setup `20260525T201515Z-live-runtime-parity-task-TASK-124-prefix-TASK124_RT_SIM_-profile-linked-p57963`. The explicit full pull is setup evidence for parity only, not a normal-path workaround.
- Cleanup scoped PASS: dry-run `20260525T201625Z-supabase-cleanup-task-TASK-124-prefix-TASK124_-profile-linked-dry-run-p59913`; execute `20260525T201647Z-supabase-cleanup-task-TASK-124-prefix-TASK124_-profile-linked-execute-cleanup-plan-id-cleanup-TASK-124-20260525T201625Z-TASK124_-p60875`; residue-check PASS `20260525T201658Z-supabase-residue-check-prefix-TASK124_-profile-linked-p61341`.
- Final verification PASS: all TASK-124 scanners `20260525T201721Z` through `20260525T201735Z`; sensitive `20260525T201736Z`; evidence final `20260525T202253Z`; repo-diff final `20260525T202306Z`; `git diff --check` PASS; iOS Debug `20260525T201834Z`; iOS Release `20260525T201845Z`; iOS sync tests `20260525T202012Z`; Android Debug `20260525T201953Z`; Android sync tests `20260525T202001Z`.
- Stato finale Codex: `ACTIVE / REVIEW — SIMULATOR_EMULATOR_SCOPE_PASS`. Non `DONE`, non `REVIEW PASS`, nessun claim 100%, production-ready globale o device fisici.

### Review/fix finale — 2026-05-25 17:52 -0400
- User override applicato: Codex ha eseguito review tecnica/fix/check fino alla chiusura `DONE — SIMULATOR_EMULATOR_SCOPE_VERIFIED`, superando la regola standard che limitava Codex a `ACTIVE / REVIEW`. Impatto: chiusura valida solo nel perimetro TASK-124 simulator/emulator/Supabase; device fisici e scenari real-device restano esplicitamente fuori scope.
- Preflight finale iniziale PASS: local HEAD/origin/main/ls-remote allineati su `472e1bbb39ed556bfbe5b1536df56d1d1aec35cb`; evidence `20260525T204408Z-preflight-require-head-consistency-task-TASK-124-p66803` e `20260525T204408Z-git-head-consistency-task-TASK-124-p66802`.
- Finding HIGH corretto: il no-op TASK-123 live harness misurava anche il settle sleep e non esponeva evidence machine-readable sufficiente. Fix in `tools/agent/lib/supabase.sh`: `started_ms` spostato dopo il settle e `settleSeconds`/`elapsedMsExcludesSettle` aggiunti al JSON. Rerun PASS: `20260525T204759Z-live-task123-noop-task-TASK-124-prefix-TASK124_SPEED_SIM_-p68189`.
- Finding HIGH corretto: cleanup/residue `TASK124_` poteva produrre falso PASS per perdita di `MC_RESIDUE_COUNT` dentro command substitution. Fix in `tools/agent/lib/supabase.sh`: parser JSON `mc_supabase_residue_total_from_output` e valorizzazione esplicita in dry-run/residue-check. Rerun PASS: dry-run `20260525T214252Z-supabase-cleanup-task-TASK-124-prefix-TASK124_-profile-linked-dry-run-p91911`, execute `20260525T214302Z-supabase-cleanup-task-TASK-124-prefix-TASK124_-profile-linked-execute-cleanup-plan-id-cleanup-TASK-124-20260525T214252Z-TASK124_-p92464`, residue `20260525T214312Z-supabase-residue-check-task-TASK-124-prefix-TASK124_-profile-linked-p93000`.
- Finding MEDIUM risolto: runtime parity era fragile dopo scritture live residue/speed (`20260525T210140Z-live-runtime-parity-task-TASK-124-prefix-TASK124_RUNTIME_SIM_-profile-linked-p92037`). Evidenza di drift raccolta con sync-counts Supabase/iOS/Android; riallineamento eseguito con full-pull setup esplicito iOS `20260525T214326Z-ios-live-full-pull-live-task-TASK-124-p93531` e Android `20260525T214506Z-android-live-full-pull-live-task-TASK-124-p95200`, poi runtime-parity PASS `20260525T214541Z-live-runtime-parity-task-TASK-124-prefix-TASK124_RUNTIME_SIM_-profile-linked-p96011`. Il full pull resta setup parity, non normal path.
- Finding LOW/MEDIUM risolto: evidence scan ha rilevato log raw eccessivo (`20260525T214751Z-scan-evidence-task-TASK-124-p5313`). Il log PASS oversized e' stato sintetizzato mantenendo JSON/Markdown; evidence scan finale PASS `20260525T214908Z-scan-evidence-task-TASK-124-p19457`.
- Finding documentale corretto: `offline-reconnect-matrix.md/json` era rimasto su un vecchio `BLOCKED_EXTERNAL` fisico/live; aggiornato al PASS simulator/emulator `20260525T205558Z-live-offline-reconnect-sync-task-TASK-124-prefix-TASK124_OFFLINE_SIM_-p81521` e al deferred TASK-125 per il vecchio scope fisico.
- Check finali rieseguiti o coperti da evidence canonica: preflight/head `20260525T215657Z-preflight-require-head-consistency-task-TASK-124-p35156` e `20260525T215657Z-git-head-consistency-task-TASK-124-p35155`; iOS Debug `20260525T205052Z-ios-build-debug-task-TASK-124-p72454`; iOS Release `20260525T205103Z-ios-build-release-task-TASK-124-p73070`; iOS sync tests `20260525T205209Z-ios-test-sync-task-TASK-124-p73691`; Android Debug `20260525T205452Z-android-build-debug-task-TASK-124-p76963`; Android sync tests `20260525T205457Z-android-test-sync-task-TASK-124-p78020`; Android offline/emulator `20260525T205504Z-android-test-offline-task-TASK-124-p79163`; iOS auth-preflight live `20260525T205517Z-ios-auth-preflight-live-task-TASK-124-p80081`; offline/reconnect `20260525T205558Z-live-offline-reconnect-sync-task-TASK-124-prefix-TASK124_OFFLINE_SIM_-p81521`; mutation near realtime `20260525T205849Z-live-mutation-near-realtime-task-TASK-124-prefix-TASK124_REALTIME_SIM_-p86887`; TASK-123 speed single/no-op/burst/cold `20260525T210831Z`, `20260525T204759Z`, `20260525T213215Z`, `20260525T212622Z`; TASK-124 scanners `20260525T215724Z` through `20260525T215757Z`; sensitive `20260525T215758Z-scan-sensitive-task-TASK-124-p42892`; evidence `20260525T215758Z-scan-evidence-task-TASK-124-p43198`; repo-diff `20260525T215819Z-scan-repo-diff-task-TASK-124-p57995`; JSON validation `20260525T215820Z-report-validate-json-task-TASK-124-path-docs-TASKS-EVIDENCE-TASK-124-agent-runs-p36282`; `bash -n tools/agent/lib/supabase.sh` PASS; `git diff --check` PASS.
- Stato finale TASK-124: `DONE — SIMULATOR_EMULATOR_SCOPE_VERIFIED`. Non restano BLOCKER/HIGH dentro il perimetro TASK-124. Non viene dichiarata copertura di iPhone fisico, Android fisico, locked/background, long-offline real-device o production globale.

## Verifiche canonical iniziali
- Local iOS repo: `/Users/minxiang/Desktop/iOSMerchandiseControl`.
- Local branch: `main`.
- Local HEAD: `951547ab1e4ed63a9f6a730c293ee278a67ef17c`.
- `origin/main` dopo `git fetch origin main --prune`: `951547ab1e4ed63a9f6a730c293ee278a67ef17c`.
- `git ls-remote origin refs/heads/main`: `951547ab1e4ed63a9f6a730c293ee278a67ef17c`.
- GitHub raw/API main: raw `docs/MASTER-PLAN.md` letto da `main`; API commit `main` sha `951547ab1e4ed63a9f6a730c293ee278a67ef17c`.
- `docs/MASTER-PLAN.md`, TASK-123, evidence TASK-123, TASK-122 ed evidence TASK-122 letti localmente prima della pianificazione.

## Relazione con TASK-123 e TASK-122
TASK-123 resta `DONE / REVIEW PASS — STRICT SPEED ACCEPTANCE PASSED` nel perimetro iOS Simulator 26.4 <-> Android Emulator <-> Supabase live/dev same-account. Non viene riaperto e non prova production-global architecture.

TASK-122 resta `DONE / CLOSED_BY_USER_OVERRIDE_AFTER_SYNC_RESTRUCTURING`: `SupabaseTransportClient.swift` e' thin transport da 117 LOC, gli adapter Remote possiedono query/domain behavior, e i gate architetturali TASK-122 sono passati. TASK-124 non ripete TASK-122: chiude residui finali, naming, boundary leakage, manual/recovery isolation e scanner piu' severi post speed acceptance.

## Obiettivo
Arrivare, in futura EXECUTION, a una struttura Sync iOS realmente pulita, efficiente e manutenibile quanto il riferimento Android:
- niente root legacy service o mega-service runtime;
- normal automatic path senza dipendenze nominali/runtime dal manual path;
- transport, query primitives, remote adapters, automatic runtime, manual/recovery e outbox con responsabilita' singola;
- nessun full pull normale per ogni local write;
- nessuna sync manuale nascosta usata per far passare test;
- scanner/harness con fixture RED/GREEN, non grep casuali;
- build/test/scanner/runtime gates prima di qualsiasi claim forte.

## Perimetro
- Audit e futura pulizia di `iOSMerchandiseControl/Sync/`, incluse `Automatic/`, `Remote/`, `Manual/`, `Recovery/`, `Outbox/`, `Shared/`, `Account/`.
- Audit root app sync/Supabase: `ContentView.swift`, `OptionsView.swift`, `iOSMerchandiseControlApp.swift`, root `Supabase*.swift`.
- Audit `project.pbxproj` / target membership e riferimenti stale.
- Audit harness/scanner `tools/agent`.
- Lettura Android solo come riferimento funzionale/architetturale.
- Lettura Supabase solo read-only; nessuna migration, grant, RLS o write nel planning.

## Non-obiettivi
- Nessuna modifica Swift/Kotlin/SQL in PLANNING.
- Nessuna nuova dipendenza.
- Nessuna modifica API pubblica non richiesta.
- Nessuna feature utente nuova.
- Nessun cambio schema/RLS/grants/RPC.
- Nessun cleanup live globale.
- Nessun claim `100% completato`, `production-ready globale`, `DONE` o `REVIEW PASS` in questa fase.

## Review professionale del planning — esito
Il piano corrente e' solido come piano architetturale, ma prima di EXECUTION deve essere rafforzato sul lato automation/harness. TASK-124 non deve autorizzare sequenze manuali lunghe o ricostruite a mano se esiste gia' un comando canonico in `tools/agent/mc-agent.sh`.

Verdict planning: **CHANGES_REQUIRED_BEFORE_EXECUTION_HANDOFF** finche' non sono documentati e/o creati i comandi TASK-124 sotto. Il planning resta valido, ma l'handoff EXECUTION deve includere l'uso obbligatorio di discovery `help-json`/`list commands-json`, report JSON/Markdown, redazione log, safety gates live/cleanup, scanner self-tests e stato tassonomico coerente.

Principio operativo: **canonical harness first, fallback only with evidence**. Cursor/Codex deve sempre provare il comando `mc-agent` esistente prima di usare Xcode/Gradle/Supabase/adb/xcrun manualmente. Un fallback e' ammesso solo se il report `mc-agent` e' `BLOCKED_EXTERNAL`, `MISCONFIGURED` o non copre il caso richiesto, e deve essere documentato con motivo, comando manuale usato, output redatto e proposta di miglioramento del harness.

## Stato attuale iOS
Root legacy audit:
- `iOSMerchandiseControl/SupabaseInventoryService.swift`: NOT PRESENT su local/main verificato.
- `iOSMerchandiseControl/InventorySyncService.swift`: NOT PRESENT su local/main verificato.
- `iOSMerchandiseControl/SupabaseManualSyncCompatibilityAdapter.swift`: NOT PRESENT su local/main verificato.
- Root Supabase rimasti: `SupabaseAuthService.swift`, `SupabaseAuthViewModel.swift`, `SupabaseClientProvider.swift`, `SupabaseConfig.swift`; classificazione iniziale KEEP auth/config/provider, non sync domain service.
- `Sync/Recovery/InventorySyncService.swift`: PRESENT, non root legacy; da classificare come recovery-only e verificare che non entri nel normal automatic path.

Automatic path:
- `AutomaticSyncRuntimeFactory` compone provider automatici da `SupabaseTransportClient` verso adapter domain (`CatalogRemoteSupabaseAdapter`, `ProductPriceRemoteSupabaseAdapter`, `HistorySessionRemoteSupabaseAdapter`, `SyncEventRemoteSupabaseAdapter`).
- `AutomaticSyncEngine` usa single-flight, cancellation token, push pending, incremental drain, e blocca `bootstrap/fullRecovery` nel normal automatic run con `blocked_full_pull_requires_explicit_context`.
- `SyncOrchestrator` gestisce foreground/background, deferred foreground, realtime watcher, safety loop e local mutation trigger.
- Residuo naming: `ContentView` e `iOSMerchandiseControlApp` usano `supabaseInventoryService` / `inventoryService` per un `SupabaseTransportClient`; da rinominare in futura execution se non cambia API pubblica.

Remote boundary:
- `SupabaseTransportClient.swift`: 117 LOC, thin transport/error/session/client mapping.
- `SupabaseRemoteQueryExecutor.swift`: 183 LOC, query primitives generiche. Da mantenere primitive-only, non domain mega-service.
- `CatalogRemoteSupabaseAdapter.swift`: 159 LOC, catalog-only.
- `HistorySessionRemoteSupabaseAdapter.swift`: 132 LOC, history/session-only.
- `ProductPriceRemoteSupabaseAdapter.swift`: 268 LOC, MIXED RISK: automatic insert/incremental fetch/keyset preview/manual push verification/manual push insert/dry-run dedupe/product update access. TASK-124 execution deve split o motivare con evidence.
- `SyncEventRemoteSupabaseAdapter.swift`: 137 LOC, MIXED RISK: `sync_events` incremental + Options counts + deleghe cross-domain catalog/productPrice/history. TASK-124 execution deve split o motivare con evidence.

Manual/recovery:
- `Sync/Manual/SupabaseManualSyncViewModel.swift` e' molto grande (6550 LOC) e contiene presentation/review orchestration: KEEP per explicit Review/Recovery flow, ma candidata a SPLIT se execution dimostra responsabilita' miste senza refactor cosmetico.
- `Sync/Manual/LocalPendingAggregatedPushPlanner.swift` (1222 LOC), `SupabaseManualPushService.swift` (1149 LOC), `SupabaseManualPushPreflightService.swift` (872 LOC), `SupabaseManualSyncReleaseFactory.swift` (846 LOC), `SupabaseProductPricePushDryRunService.swift` (882 LOC), `SupabaseProductPriceManualPushService.swift` (746 LOC): KEEP/SPLIT candidates, da classificare file-by-file.
- `Sync/Manual/SupabaseSyncEventIncrementalApplyService.swift`: compatibility-looking manual wrapper around incremental apply; candidate RENAME/MOVE/DELETE only after call-site proof.
- `Sync/Recovery/*`: KEEP recovery/full-pull only; verify no normal automatic dependency.

## Riferimento Android usato
Repo: `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView`.

File letti/individuati:
- `CatalogAutoSyncCoordinator.kt`: coordinator foreground/background, debounce, sync events drain, outbox pending.
- `HistorySessionPushCoordinator.kt`: history push coordinator con dirty set/debounce/foreground policy.
- `InventoryRepository.kt`: repository/outbox/pending/catalog bootstrap and push/pull owner.
- `ProductPriceRemoteDataSource.kt` e `SupabaseProductPriceRemoteDataSource.kt`: product price remote interface e keyset/page fetch.
- `MerchandiseControlApplication.kt`: composition e lifecycle foreground/background/network/realtime.

Android e' riferimento architetturale, non sorgente da copiare in Swift.

## Riferimento Supabase usato
Repo: `/Users/minxiang/Desktop/MerchandiseControlSupabase`.

Read-only inventory:
- catalog/prices/history SQL in `sql/000_init.sql` ... `sql/006_inventory_product_prices_candidate.sql`.
- migrations rilevanti: ownership/RLS TASK-012/013, product prices TASK-016, restrict authenticated delete TASK-038, sync_events TASK-045, catalog updated_at TASK-086, RLS execute revoke TASK-101, history/session TASK-110/114.
- Nessuna tabella/colonna inventata in planning. Qualunque mismatch reale in execution va marcato `BLOCKED_SEPARATE_SUPABASE_TASK`.

## File inventory completo iOS Sync
Account:
- KEEP: `AccountBindingStore.swift`, `AccountSwitchPolicy.swift`, `AccountSyncDecision.swift`, `AccountSyncDecisionView.swift`, `LocalStoreIdentity.swift`.

Automatic:
- KEEP: `CatalogPushPayloads.swift`, `CatalogPushService.swift`, `CatalogRemoteWriting.swift`, `SyncCatalogPushModels.swift`.
- KEEP: `AutomaticSyncRuntimeFactory.swift`, `AutomaticSyncCancellationPolicy.swift`, `AutomaticSyncEngine.swift`, `AutomaticSyncRetryPolicy.swift`, `AutomaticSyncRuntimeFacade.swift`, `AutomaticSyncSingleFlight.swift`, `SyncAutomaticRunResult.swift`.
- KEEP: `AutomaticDecisionBoundary.swift`, `SyncAutomaticTriggerSource.swift`, `SyncDecisionEngine.swift`, `SyncDecisionInputProvider.swift`, `SyncTrigger.swift`.
- KEEP: `HistorySessionAutomaticPushService.swift`, `HistorySessionRemoteWriting.swift`, `SyncHistorySessionPushModels.swift`.
- KEEP: `AutomaticSyncEventOutboxWriter.swift`, `SyncActivityRegistrationModels.swift`, `SyncActivityRegistrationService.swift`.
- KEEP: `AutomaticPresentationBoundary.swift`, `AutomaticSyncReconnectScheduler.swift`, `OptionsSyncSummaryProvider.swift`, `SyncState.swift`, `SyncStateStore.swift`, `SyncStatusPresenter.swift`.
- KEEP: `ProductPricePushPayloads.swift`, `ProductPricePushService.swift`, `ProductPriceRemoteWriting.swift`, `SyncProductPricePushModels.swift`.
- KEEP: `AutomaticPullBoundary.swift`, `CatalogIncrementalApplyService.swift`, `CatalogIncrementalApplySummary.swift`, `HistoryIncrementalApplyService.swift`, `HistoryIncrementalApplySummary.swift`, `ProductPriceIncrementalApplyService.swift`, `ProductPriceIncrementalApplySummary.swift`, `SyncEventIncrementalApplyHelpers.swift`, `SyncEventIncrementalContracts.swift`, `SyncEventIncrementalDomainApplyService.swift`, `SyncEventIncrementalPullService.swift`, `SyncIncrementalPullSummary.swift`, `WatermarkStore.swift`.
- AUDIT/KEEP: `AutomaticPushServices.swift`, `SyncAutomaticRuntime.swift`, `SyncAutomaticRuntimeProviders.swift` are tiny compatibility/marker files; execution must prove needed or delete if dead.

Manual:
- KEEP explicit review/recovery flow: `CloudSyncOverviewState.swift`, `HistorySessionPayloadSnapshotFactory.swift`, `HistorySessionSyncService.swift`, `ManualSyncBoundary.swift`, `SupabaseCatalogBaselineModels.swift`, `SupabaseCatalogBaselineReader.swift`, `SupabaseCatalogBaselineWriter.swift`, `SupabaseCatalogFingerprintNormalizer.swift`, `SupabaseManualSyncBaselineCommitter.swift`, `SupabaseManualSyncCoordinating.swift`, `SupabaseManualSyncCoordinator.swift`, `SupabaseManualSyncCoordinatorModels.swift`, `SupabaseManualSyncLifecycleRunGate.swift`, `SupabaseManualSyncLocalPendingSnapshotProvider.swift`, `SupabaseManualSyncReleaseActivityRegistrationAdapter.swift`, `SupabaseManualSyncReleaseFactory.swift`, `SupabaseManualSyncRemotePreview.swift`, `SupabaseManualSyncSemiAutomaticPolicy.swift`, `SupabaseManualSyncViewModel.swift`, `SupabaseSyncPlanContract.swift`.
- KEEP/SPLIT: `LocalPendingAggregatedPushPlanner.swift`, `SupabaseManualPushPreflightModels.swift`, `SupabaseManualPushPreflightService.swift`, `SupabaseManualPushService.swift`, `SupabaseManualSyncOutboxProducerConversions.swift`, `SupabaseProductPriceManualPushService.swift`, `SupabaseProductPricePreviewService.swift`, `SupabaseProductPricePushDryRunService.swift`.
- KEEP debug-only or test/dev UI if not app-normal: `ProductPriceManualPushDebugViewModel.swift`, `SupabasePushPreflightViewModel.swift`, `SupabaseSyncEventDebugFormatting.swift`, `SupabaseSyncEventDebugViewModel.swift`, `SyncEventOutboxDrainDebugViewModel.swift`.
- RENAME/MOVE/DELETE candidate after call-site proof: `SupabaseManualSyncAggregatedPushOutboxProducer.swift` (15 LOC wrapper), `SupabaseSyncEventIncrementalApplyService.swift` (manual path naming for incremental apply compatibility), any file whose only role is compatibility naming.

Outbox:
- KEEP: `LocalOutboxStore.swift`, `PendingChangeCoalescer.swift`, `SyncEventOutboxDrainService.swift`, `SyncEventOutboxDrainer.swift`, `SyncEventOutboxEnqueueService.swift`, `SyncEventOutboxEntry.swift`, `SyncEventOutboxRecorder.swift`, `SyncEventOutboxState.swift`.

Recovery:
- KEEP recovery-only: `BootstrapPullService.swift`, `DriftReconciliationService.swift`, `FullRecoveryService.swift`, `InventorySyncService.swift`, `RecoveryRemoteSupabaseAdapter.swift`, `SupabaseProductPriceApplyService.swift`, `SupabasePullApplyService.swift`, `SupabasePullPreviewModels.swift`, `SupabasePullPreviewService.swift`, `SwiftDataInventorySnapshotService.swift`, `SyncCountReconciliation.swift`.
- Special audit: `InventorySyncService.swift` name is legacy-looking but path is Recovery; classify KEEP if only recovery/full pull, otherwise RENAME to recovery-specific name.

Remote:
- KEEP: `CatalogRemoteSupabaseAdapter.swift`, `HistorySessionRemoteSupabaseAdapter.swift`, `SupabaseInventoryDTOs.swift`, `SupabaseRemoteQueryExecutor.swift`, `SupabaseSyncEventDTOs.swift`, `SupabaseSyncEventLiveRecorder.swift`, `SupabaseSyncEventRPCTransport.swift`, `SupabaseSyncEventRealtimeWatcher.swift`, `SupabaseTransportClient.swift`, `SyncEventRPCRequestMapper.swift`, `SyncEventRecording.swift`.
- SPLIT/MOTIVATE: `ProductPriceRemoteSupabaseAdapter.swift`, `SyncEventRemoteSupabaseAdapter.swift`.

Shared:
- KEEP pure helpers/value boundaries: `AutomaticSharedBoundary.swift`, `HistorySessionSyncShared.swift`, `SyncStringCollectionHelpers.swift`.

## Boundary map corrente
- App/root composition: `iOSMerchandiseControlApp` creates `SupabaseTransportClient`, recovery adapter, sync event live recorder, automatic runtime factory and root `SyncOrchestrator`.
- UI host: `ContentView` owns sheet routing including manual sync sheet and passes observer/remote count dependencies.
- Options UI: `OptionsView` remains primary explicit Review/Recovery/manual surface; must not be used by hidden automatic normal path.
- Automatic: `SyncOrchestrator` -> `SyncDecisionInputProvider`/`SyncDecisionEngine` -> `AutomaticSyncRuntimeFacade` -> `AutomaticSyncEngine` -> automatic domain push/pull providers.
- Remote: automatic providers use Remote adapters; adapters use `SupabaseRemoteQueryExecutor` and thin `SupabaseTransportClient`.
- Manual: explicit review/preflight/push/preview/dry-run services under `Sync/Manual`.
- Recovery: bootstrap/full recovery/drift reconciliation under `Sync/Recovery`.
- Outbox: pending/outbox enqueue/drain services shared by automatic and explicit flows by protocol/adapter only.

## Target architecture map
- `SupabaseTransportClient`: client/session/error/network only.
- `SupabaseRemoteQueryExecutor`: generic query primitives only; no domain table orchestration beyond primitive table/id/page/count helpers.
- `CatalogRemoteSupabaseAdapter`: supplier/category/product catalog only.
- `ProductPriceRemoteSupabaseAdapter`: automatic/incremental product price only, or split into `ProductPriceAutomaticRemoteSupabaseAdapter`, `ProductPriceManualPushRemoteSupabaseAdapter`, `ProductPricePreviewRemoteSupabaseAdapter` if call-site map confirms mixed responsibilities.
- `SyncEventRemoteSupabaseAdapter`: sync_events incremental only, or split Options counts into `RemoteCountSupabaseAdapter` and cross-domain fetch delegates into explicit incremental fetch facade.
- Manual/recovery flows: explicit user flow only, no normal automatic invocation.
- Composition names: replace `inventoryService`/`supabaseInventoryService` with `transportClient`/`supabaseTransportClient` where scoped and low-risk.

## Delete / keep / rename / split matrix
| Item | Classificazione iniziale | Motivo | Gate prima di execution |
| --- | --- | --- | --- |
| Root `SupabaseInventoryService.swift` | NOT PRESENT | rimosso da main | scanner `no-root-supabase-legacy` |
| Root `InventorySyncService.swift` | NOT PRESENT | non presente in root | scanner `no-root-supabase-legacy` |
| Root `SupabaseManualSyncCompatibilityAdapter.swift` | NOT PRESENT | rimosso da main | scanner `no-root-supabase-legacy` |
| `Sync/Recovery/InventorySyncService.swift` | KEEP/RENAME candidate | recovery-only se provato; nome legacy-looking | call-site + no automatic dependency |
| `ContentView.supabaseInventoryService` | RENAME candidate | naming falso per transport | build + no API public break |
| `iOSMerchandiseControlApp.inventoryService` | RENAME candidate | naming falso per transport/recovery composition | build + target membership |
| `ProductPriceRemoteSupabaseAdapter.swift` | SPLIT/MOTIVATE | automatic + incremental + keyset preview + manual push + dry-run | call-site map + remote-adapter-single-domain |
| `SyncEventRemoteSupabaseAdapter.swift` | SPLIT/MOTIVATE | sync_events + Options counts + cross-domain delegates | call-site map + remote-adapter-single-domain |
| `SupabaseRemoteQueryExecutor.swift` | KEEP with guard | primitive query helper only | `transport-thin-only`, domain table primitive limit |
| `SupabaseManualSyncViewModel.swift` | KEEP/SPLIT candidate | huge explicit Review UI/state | size/responsibility map, no cosmetic split |
| `SupabaseSyncEventIncrementalApplyService.swift` | RENAME/MOVE/DELETE candidate | manual-named compatibility wrapper | call-site proof + tests |
| `SupabaseManualSyncAggregatedPushOutboxProducer.swift` | DELETE/MERGE candidate | 15 LOC wrapper-like | dead-code/responsibility proof |
| Debug view models in Manual | KEEP debug-only or move test/debug | explicit/debug surfaces | target membership no test-only fixture |

## Execution slices
0. **Harness discovery obbligatoria**: eseguire e salvare evidence di `./tools/agent/mc-agent.sh help-json` e `./tools/agent/mc-agent.sh list commands-json` con `MC_TASK_ID=TASK-124`, poi usare solo comandi discoverable o creare/migliorare il harness prima di procedere.
1. **Preflight canonical**: usare `mc-agent preflight --task TASK-124` e `mc-agent git head-consistency --task TASK-124`; provare local/origin/ls-remote/GitHub raw/API alignment per TASK-124 e master plan; stop su mismatch.
2. **Inventory and call-site evidence**: generare file inventory, LOC, pbx membership, protocol conformance, import graph, call-site map per automatic/manual/recovery/remote; produrre JSON + Markdown sotto `docs/TASKS/EVIDENCE/TASK-124/agent-runs/`.
3. **Scanner foundation**: creare `tools/agent/lib/task124_scans.py` e routarlo in `mc-agent.sh`; aggiungere fixture RED/GREEN; eseguire scanner self-tests prima di qualsiasi Swift refactor.
4. **Harness routing/health**: aggiornare `help-json`/`commands-json`, aggiungere comandi TASK-124 mancanti, verificare exit code 0/1/2/3/4 e report schema 1.1.
5. **Root/naming cleanup**: rinominare variabili fuorvianti `inventoryService` in transport naming se scoped e safe; no public API break; aggiornare pbx/call-site evidence.
6. **Automatic path hardening**: provare/rimuovere dipendenze Manual/Recovery nel normal path; provare no full pull per local writes; provare no MainActor heavy mutative sync.
7. **Remote split**: split o motivated-keep di `ProductPriceRemoteSupabaseAdapter`; split o motivated-keep di `SyncEventRemoteSupabaseAdapter`; preservare `SupabaseTransportClient` thin e `SupabaseRemoteQueryExecutor` primitive-only.
8. **Manual/recovery classification cleanup**: delete/rename/move solo dopo call-site proof; mantenere explicit Review/Recovery safety; nessuna rimozione cieca di flow di protezione dati.
9. **pbxproj/target cleanup**: rimuovere stale references, prevenire fixture/test-only nel target app; produrre report `no-stale-pbxproj-reference`.
10. **Offline/reconnect matrix**: se runtime/outbox/incremental/recovery/remote sono toccati, eseguire o creare comando canonico TASK-124 per matrice post-offline; fix immediato nello stesso task per inefficienze reali salvo blocker esterno ammesso.
11. **Verification**: Debug/Release build, iOS sync tests, automatic-domain, automatic-architecture, manual regression se toccata, scanner TASK-124, TASK-123 speed regression se runtime touched, residue/security scans.
12. **Tracking handoff**: aggiornare Execution + Handoff, evidence index e MASTER-PLAN; spostare solo a REVIEW se tutti i gate required sono PASS o PASS_WITH_NOTES accettabile e motivato. No DONE.

## Test matrix futura
| Area | Check richiesto | Stato planning |
| --- | --- | --- |
| iOS build Debug | `mc-agent ios build debug` or Xcode equivalent | REQUIRED in execution |
| iOS build Release | `mc-agent ios build release` or Xcode equivalent | REQUIRED in execution |
| iOS sync tests | sync targeted suite | REQUIRED |
| iOS automatic architecture tests | automatic-domain/automatic-architecture | REQUIRED |
| Manual/recovery regression | explicit Review/Recovery tests or smoke if touched | REQUIRED if touched |
| TASK-123 speed regression | single propagation/burst/no-op subset | REQUIRED if runtime sync touched |
| Android assemble/test | targeted only | REQUIRED only if Android/harness cross-platform touched |
| Supabase read-only | schema/RLS/grant/status maps | REQUIRED read-only |
| Supabase cleanup/residue | dry-run scoped only | REQUIRED only if live data used in execution |

## Automation / harness contract obbligatorio
TASK-124 deve usare `./tools/agent/mc-agent.sh` come fonte primaria per preflight, build, test, scanner, live gate, cleanup e report. Il wrapper esistente supporta `help-json` e `list commands-json`, mappa exit code canonici, produce report Markdown/JSON/log sotto `agent-runs`, redige path/email/token/JWT/project ref/device serial, e gia' contiene safety gate live/cleanup.

### Comandi discovery e preflight
Da eseguire sempre all'inizio della futura EXECUTION, salvando output redatto in evidence:
```bash
MC_TASK_ID=TASK-124 ./tools/agent/mc-agent.sh help-json
MC_TASK_ID=TASK-124 ./tools/agent/mc-agent.sh list commands-json
MC_TASK_ID=TASK-124 ./tools/agent/mc-agent.sh preflight --task TASK-124
MC_TASK_ID=TASK-124 ./tools/agent/mc-agent.sh git head-consistency --task TASK-124
```

### Comandi iOS canonici
Usare questi prima di qualsiasi `xcodebuild` manuale:
```bash
MC_TASK_ID=TASK-124 ./tools/agent/mc-agent.sh ios build debug
MC_TASK_ID=TASK-124 ./tools/agent/mc-agent.sh ios build release
MC_TASK_ID=TASK-124 ./tools/agent/mc-agent.sh ios test sync
MC_TASK_ID=TASK-124 ./tools/agent/mc-agent.sh ios test automatic-domain
MC_TASK_ID=TASK-124 ./tools/agent/mc-agent.sh ios test automatic-architecture
MC_TASK_ID=TASK-124 ./tools/agent/mc-agent.sh ios test manual-sync-regression
MC_TASK_ID=TASK-124 ./tools/agent/mc-agent.sh ios test offline
MC_TASK_ID=TASK-124 ./tools/agent/mc-agent.sh ios smoke options
```
Se uno di questi comandi non copre un test TASK-124 necessario, execution deve migliorare `tools/agent/lib/ios.sh` o aggiungere suite mirata invece di aggirare stabilmente il wrapper.

### Comandi Android canonici
Usare Android solo quando il task tocca cross-platform, offline matrix o regressione sync Android/iOS:
```bash
MC_TASK_ID=TASK-124 ./tools/agent/mc-agent.sh android build debug
MC_TASK_ID=TASK-124 ./tools/agent/mc-agent.sh android test sync
MC_TASK_ID=TASK-124 ./tools/agent/mc-agent.sh android test offline
MC_TASK_ID=TASK-124 ./tools/agent/mc-agent.sh android offline-tier-status
MC_TASK_ID=TASK-124 ./tools/agent/mc-agent.sh android offline-write --tier L1 --prefix TASK124_OFFLINE_L1_
MC_TASK_ID=TASK-124 ./tools/agent/mc-agent.sh android reconnect-drain --tier L1 --prefix TASK124_OFFLINE_L1_
MC_TASK_ID=TASK-124 ./tools/agent/mc-agent.sh android offline-write --tier L2 --prefix TASK124_OFFLINE_L2_
MC_TASK_ID=TASK-124 ./tools/agent/mc-agent.sh android reconnect-drain --tier L2 --prefix TASK124_OFFLINE_L2_
```
L3/live Android richiede `MC_ALLOW_LIVE=1`, app autenticata e `MC_ANDROID_DEVICE_SERIAL`; senza questi prerequisiti il risultato corretto e' `BLOCKED_EXTERNAL`, non FAIL.

### Comandi Supabase canonici
Planning resta read-only. In futura execution usare:
```bash
MC_TASK_ID=TASK-124 ./tools/agent/mc-agent.sh supabase status-redacted
MC_TASK_ID=TASK-124 ./tools/agent/mc-agent.sh supabase verify-schema --profile linked
MC_TASK_ID=TASK-124 ./tools/agent/mc-agent.sh supabase verify-rls --profile linked
MC_TASK_ID=TASK-124 ./tools/agent/mc-agent.sh supabase verify-grants --profile linked
MC_TASK_ID=TASK-124 ./tools/agent/mc-agent.sh supabase contract sync-schema --task TASK-124 --read-only
MC_TASK_ID=TASK-124 ./tools/agent/mc-agent.sh supabase residue-check --prefix TASK124_ --profile linked
MC_TASK_ID=TASK-124 ./tools/agent/mc-agent.sh supabase cleanup --task TASK-124 --prefix TASK124_ --profile linked --dry-run
```
`cleanup --execute` e' vietato senza dry-run precedente, `cleanup_plan_id` corrispondente e `MC_ALLOW_CLEANUP=1`. Nessun cleanup globale, nessun `auth.users`, nessun truncate/reset.

### Comandi live/speed/offline canonici
Se vengono toccati runtime sync, outbox, remote adapter, decision engine, recovery o incremental pull:
```bash
MC_ALLOW_LIVE=1 MC_TASK_ID=TASK-124 ./tools/agent/mc-agent.sh live offline-reconnect-sync --task TASK-124 --prefix TASK124_OFFLINE_LIVE_
MC_ALLOW_LIVE=1 MC_TASK_ID=TASK-124 ./tools/agent/mc-agent.sh live mutation-near-realtime --task TASK-124 --prefix TASK124_RT_
MC_ALLOW_LIVE=1 MC_TASK_ID=TASK-124 ./tools/agent/mc-agent.sh live runtime-parity --task TASK-124 --prefix TASK124_RT_ --profile linked
MC_ALLOW_LIVE=1 MC_TASK_ID=TASK-124 ./tools/agent/mc-agent.sh live task123-single-propagation --task TASK-124 --prefix TASK124_SPEED_
MC_ALLOW_LIVE=1 MC_TASK_ID=TASK-124 ./tools/agent/mc-agent.sh live task123-noop --task TASK-124 --prefix TASK124_SPEED_
MC_ALLOW_LIVE=1 MC_TASK_ID=TASK-124 ./tools/agent/mc-agent.sh live task123-burst-10 --task TASK-124 --prefix TASK124_SPEED_
```
Se il comando TASK-124 offline/reconnect non produce abbastanza evidence per tutti gli scenari AC-124-16...22, execution deve estendere il harness con JSON per scenario/direction/timing/pending/drift/fullPullUsed/syncEventsCoverage invece di creare script esterni non tracciati.

### Scanner TASK-124 da creare/routare
Aggiungere `tools/agent/lib/task124_scans.py`, fixture `tools/agent/fixtures/task124_scanners/...`, e routing in `mc-agent.sh` per:
```bash
MC_TASK_ID=TASK-124 ./tools/agent/mc-agent.sh scan no-root-supabase-legacy --task TASK-124
MC_TASK_ID=TASK-124 ./tools/agent/mc-agent.sh scan no-automatic-manual-dependency --task TASK-124
MC_TASK_ID=TASK-124 ./tools/agent/mc-agent.sh scan transport-thin-only --task TASK-124
MC_TASK_ID=TASK-124 ./tools/agent/mc-agent.sh scan remote-adapter-single-domain --task TASK-124
MC_TASK_ID=TASK-124 ./tools/agent/mc-agent.sh scan no-full-pull-normal-path --task TASK-124
MC_TASK_ID=TASK-124 ./tools/agent/mc-agent.sh scan no-hidden-manual-sync --task TASK-124
MC_TASK_ID=TASK-124 ./tools/agent/mc-agent.sh scan no-stale-pbxproj-reference --task TASK-124
MC_TASK_ID=TASK-124 ./tools/agent/mc-agent.sh scan no-mainactor-heavy-sync --task TASK-124
MC_TASK_ID=TASK-124 ./tools/agent/mc-agent.sh scan no-service-role-client --task TASK-124
MC_TASK_ID=TASK-124 ./tools/agent/mc-agent.sh scan no-rls-bypass --task TASK-124
MC_TASK_ID=TASK-124 ./tools/agent/mc-agent.sh scan source-format --task TASK-124
MC_TASK_ID=TASK-124 ./tools/agent/mc-agent.sh scan dead-code-residue --task TASK-124
```
Routing esistente per TASK-120/121/122 non basta: TASK-124 deve avere scanner propri o allowlist motivata. Se un vecchio scanner viene riusato, il report deve dichiarare `REUSED_FROM_TASK_XXX_WITH_REASON`.

## Evidence package obbligatorio
La futura execution deve produrre almeno:
- `docs/TASKS/EVIDENCE/TASK-124/README.md` aggiornato con indice report;
- `docs/TASKS/EVIDENCE/TASK-124/agent-runs/*.json`, `*.md`, `*.log` generati da `mc-agent`;
- `automation-discovery.md/json`: output `help-json` e `list commands-json`;
- `harness-routing.md/json`: comandi TASK-124 disponibili, mancanti, creati o migliorati;
- `file-inventory.json/md`: LOC, target membership, call-sites, classification KEEP/DELETE/RENAME/SPLIT/BLOCKED;
- `pbxproj-target-membership.json/md`;
- `offline-reconnect-matrix.json/md` se runtime scope touched;
- `scanner-self-tests.json/md` con fixture RED/GREEN;
- `security-redaction-scan.json/md`;
- `cleanup-plan.json` e `residue-check.json/md` solo se live data usati;
- `final-handoff.md` con verdict REVIEW/CHANGES_REQUIRED/BLOCKED e limiti residui.

Ogni report deve usare tassonomia coerente: `PASS`, `FAIL`, `BLOCKED_EXTERNAL`, `MISCONFIGURED`, `UNSAFE_OPERATION_REFUSED`, `NOT_RUN`, `PASS_WITH_NOTES`. `DONE` non e' ammesso in execution handoff; al massimo `ACTIVE / REVIEW`.

## Tassonomia stati e regole di promozione
- `PASS`: comando/gate completato con evidence sufficiente e nessun blocker.
- `FAIL`: bug/regressione/violazione architetturale riproducibile nel codice o runtime. Va corretto nello stesso task se in scope.
- `BLOCKED_EXTERNAL`: prerequisito esterno mancante: device non pronto, sessione non autenticata, Supabase non linked, permesso macOS Accessibility, comportamento background/locked non testabile. Non e' PASS.
- `MISCONFIGURED`: comando/harness incompleto o invocato male. Va corretto o documentato prima di proseguire.
- `UNSAFE_OPERATION_REFUSED`: safety gate ha rifiutato prefix, cleanup, live write o operazione distruttiva. Non bypassare.
- `NOT_RUN`: gate non eseguito. Ammesso solo con motivazione e scope untouched.
- `PASS_WITH_NOTES`: ammesso solo per limiti tooling/non-critical con fallback evidence sufficiente; non per AC critici offline/reconnect, service_role/RLS, hidden manual sync, full-pull normal path o duplicati.

Promozione a `ACTIVE / REVIEW` ammessa solo se: required gates PASS, eventuali PASS_WITH_NOTES sono non-critical e motivati, tutti i FAIL in-scope sono fixati, BLOCKED_EXTERNAL sono veri prerequisiti esterni, evidence index aggiornato, MASTER-PLAN aggiornato, nessun claim 100%/DONE.

## Test data, prefix e safety live
Prefissi ammessi TASK-124:
- `TASK124_ARCH_` per dati architettura/smoke non-live;
- `TASK124_OFFLINE_` per offline/reconnect;
- `TASK124_RT_` per near-realtime/parity;
- `TASK124_SPEED_` per regressione TASK-123 speed;
- `TASK124_CLEANUP_` solo per cleanup test.

Ogni live write deve usare dati sintetici scoped e redatti. Ogni cleanup deve essere dry-run first, poi execute solo con `MC_ALLOW_CLEANUP=1` e `cleanup_plan_id` corrispondente. Ogni live gate deve usare `MC_ALLOW_LIVE=1`; senza autorizzazione il risultato corretto e' `UNSAFE_OPERATION_REFUSED` o `BLOCKED_EXTERNAL`, non workaround manuale.

## Harness improvements obbligatori se mancanti
Se durante planning/execution manca un comando canonical per TASK-124, creare o migliorare il harness prima di procedere:
- aggiungere routing in `mc-agent.sh`;
- aggiornare `help-json`/`commands-json`;
- generare report JSON/Markdown/log con schema 1.1;
- usare redaction centralizzata;
- restituire exit code 0 PASS, 1 FAIL, 2 BLOCKED_EXTERNAL, 3 MISCONFIGURED, 4 UNSAFE_OPERATION_REFUSED;
- evitare output rumoroso: summary e next action devono essere chiari;
- aggiungere fixture RED/GREEN per scanner statici;
- documentare comandi one-line in evidence README.

## UX operatore/agent
TASK-124 riguarda strumenti interni oltre al codice app. La UX CLI deve essere prevedibile:
- ogni comando deve stampare summary breve e next action utile;
- ogni failure deve dire cosa correggere e quale comando rieseguire;
- ogni blocker deve distinguere device/auth/Supabase/permission/config;
- ogni report deve contenere path artifact redatti;
- README evidence deve permettere a Cursor/Codex/Claude di riprendere senza ricostruire manualmente comandi.

## Offline / reconnect contract
TASK-124 non deve reinventare la sync offline e non deve introdurre una grande nuova feature. Deve pero' verificare che la purificazione architetturale non rompa il contratto offline-first gia' introdotto nelle task precedenti.

Questa matrice e' obbligatoria se la futura execution tocca almeno uno tra orchestrator, outbox, decision engine, incremental pull, recovery o remote adapter:
1. iOS offline -> modifica prodotto catalogo -> reconnect -> push automatico -> Android riceve.
2. iOS offline -> modifica ProductPrice purchase/retail -> reconnect -> push automatico -> Android riceve.
3. Android offline -> modifica equivalente -> reconnect -> iOS riceve via sync_events/incremental pull.
4. iOS offline con 10 modifiche consecutive -> reconnect -> coalescing/outbox drain -> zero duplicati.
5. iOS offline -> app restart -> reconnect -> pending ancora presenti e drenati.
6. Remote changes while iOS offline -> reconnect -> iOS pull incrementale senza full pull normale.
7. Network flapping durante drain -> retry sicuro, no partial ack corrotto, no pending stuck.
8. Logout/account switch con pending offline -> non pushare sul proprietario sbagliato; bloccare con Review/Recovery.
9. Drift finale iOS = Android = Supabase nel prefisso test scoped.
10. Nessuna sync manuale nascosta per completare questi test.
11. iOS offline -> crea/modifica History/session o generated sheet -> reconnect -> push automatico -> Android/Supabase ricevono se il dominio e' supportato dalla sync automatica.
12. Android offline -> crea/modifica History/session -> reconnect -> iOS riceve via sync_events/incremental pull se il dominio e' supportato.

Stato planning: REQUIRED_CONDITIONAL. Se la futura execution non tocca runtime sync/outbox/incremental/recovery/remote adapter, deve documentare `NOT_REQUIRED_SCOPE_UNTOUCHED` con file diff evidence. Se li tocca, ogni scenario richiede evidence machine-readable o blocco esplicito.

### Fix mandate post-offline / reconnect
Se durante TASK-124 execution uno scenario offline/reconnect fallisce o mostra inefficienza reale, Codex non deve limitarsi a documentare il problema. Deve correggere nello stesso task, salvo blocker esterno reale.

Problemi da correggere direttamente nel perimetro TASK-124:
- pending/outbox non drenati dopo reconnect;
- sync che richiede CTA manuale per completare il post-offline;
- duplicati logici dopo retry/reconnect;
- full pull normale invece di incremental pull;
- perdita di pending dopo app restart;
- retry/backoff troppo lento o troppo aggressivo;
- network flapping che lascia stato incoerente;
- account mismatch non fail-closed;
- MainActor/UI freeze durante drain post-offline;
- regressione speed rispetto a TASK-123.

Solo questi casi possono diventare `BLOCKED`:
- schema/RLS/grant Supabase richiede migration separata;
- mancano sessioni/account/device necessari;
- comportamento iOS background/locked non testabile senza device/permessi esterni.

## Scanner matrix futura
| Scanner | Purpose | Fixture requirement |
| --- | --- | --- |
| `no-root-supabase-legacy` | block root sync mega-service/compat wrappers | RED root fake service, GREEN current root auth/config |
| `no-automatic-manual-dependency` | block automatic imports/calls into `Sync/Manual` | RED automatic file importing Manual, GREEN protocol-only allowed map |
| `transport-thin-only` | keep `SupabaseTransportClient` transport-only | RED domain query in transport, GREEN 117 LOC style transport |
| `remote-adapter-single-domain` | prevent mixed-domain remote adapters | RED productPrice adapter updating product + manual push, GREEN split/justified allowlist |
| `no-full-pull-normal-path` | block full pull on local mutation/foreground normal | RED fullRecovery in automatic run, GREEN explicit recovery only |
| `no-hidden-manual-sync` | block manual coordinator execution from automatic path | RED automatic calls manual coordinator, GREEN Options explicit only |
| `no-stale-pbxproj-reference` | stale/deleted/test fixture target membership | RED deleted file ref, GREEN synchronized or existing refs |
| `no-mainactor-heavy-sync` | block heavy mutative sync under MainActor | RED MainActor network/pull loop, GREEN actor/service off-main |
| `no-service-role-client` | block service_role in client/runtime/evidence | RED service role anon config, GREEN existing config guard |
| `no-rls-bypass` | block client bypass/admin cleanup | RED bypass/admin client runtime, GREEN authenticated RLS path |
| `source-format` | no flattened/minified Swift | RED giant line, GREEN normal Swift |
| `dead-code-residue` | catch unreferenced compatibility wrappers | RED unused wrapper, GREEN referenced/removed |

## Android comparison table
| Dimensione | Android riferimento | iOS corrente | TASK-124 target |
| --- | --- | --- | --- |
| Trigger | app foreground/background/network/realtime/local changes via coordinators | `SyncOrchestrator` foreground/auth/local mutation/realtime/safety loop | equivalent triggers, documented call graph |
| Outbox/pending | repository pending refs/outbox and sync_event_outbox | `LocalOutboxStore`, `PendingChangeCoalescer`, automatic activity/outbox services | no stuck pending, clear owner |
| Incremental pull | sync_events drain + fallback catch-up | `SyncEventIncrementalPullService` + domain apply services | no normal full pull, starvation guard retained |
| Debounce | `CatalogAutoSyncCoordinator`/`HistorySessionPushCoordinator` debounce, foreground tuned by TASK-123 | orchestrator submit/defer + engine single-flight | explicit debounce/defer/cancel evidence |
| Single-flight | coordinator skip when busy | `AutomaticSyncSingleFlight` | scanner/test proof |
| Foreground/background | app lifecycle starts/stops drains/watchers | scene phase starts/stops watcher/safety loop and cancels foreground check | documented and tested |
| Recovery/manual flow | separate bootstrap/manual/repository recovery behavior | `Sync/Manual` Review and `Sync/Recovery` full pull | isolated outside automatic normal path |
| Domain boundaries | repository + remote data sources/coordinators | Remote adapters + automatic services + recovery/manual folders | split mixed remote adapters or justify |

## Rischi regressione
- Renaming composition variables can produce noisy diffs or missed injection sites.
- Splitting ProductPrice/SyncEvent adapters can regress protocol conformance or manual Review flows.
- Removing compatibility wrappers can break tests/harness if pbx or call sites are incomplete.
- Overzealous Manual cleanup could remove real data-safety recovery/review features.
- Scanner too broad can false-positive on localized manual strings or explicit Options Review UI.
- TASK-123 speed can regress if automatic runtime, debounce, or incremental pull boundaries are touched.

## Rollback plan
- Keep changes slice-based and commit-ready; revert only TASK-124 files from the failing slice.
- If remote split fails build/tests, restore original adapter file and keep scanner in report as BLOCKED planning evidence.
- If naming cleanup causes broad churn, revert naming slice and keep as follow-up candidate.
- No Supabase data/schema changes are allowed; if live scoped data is used later, cleanup must be dry-run planned and prefix-scoped.

## Acceptance criteria
- AC-124-01: `SupabaseTransportClient` remains transport-only.
- AC-124-02: No old root mega-service runtime exists or is target-membered.
- AC-124-03: Automatic normal path has no nominal/runtime dependency on Manual path.
- AC-124-04: ProductPrice remote responsibility is split or justified with call-site/domain evidence.
- AC-124-05: SyncEvent remote responsibility is split or justified with call-site/domain evidence.
- AC-124-06: Every `Sync/Manual` file is classified KEEP/DELETE/RENAME/SPLIT/BLOCKED with evidence.
- AC-124-07: No stale pbxproj reference and no test-only fixture in app target.
- AC-124-08: No full pull normal path for each local write.
- AC-124-09: No hidden manual sync to pass runtime tests.
- AC-124-10: No service_role client and no RLS bypass.
- AC-124-11: iOS Debug and Release build pass.
- AC-124-12: iOS sync tests and automatic architecture tests pass.
- AC-124-13: TASK-123 speed regression is run if runtime sync is touched.
- AC-124-14: Android assemble/test targeted only if Android or cross-platform harness is touched.
- AC-124-15: Supabase cleanup/residue is scoped dry-run only if future execution uses live data.
- AC-124-16: Local writes offline restano persistenti e tracciate in outbox/pending.
- AC-124-17: Reconnect avvia automatic drain senza CTA manuale.
- AC-124-18: Drain post-offline e' idempotente: zero duplicati logici.
- AC-124-19: Remote changes accumulati mentre iOS e' offline vengono applicati via incremental pull/sync_events.
- AC-124-20: App restart offline/reconnect non perde pending.
- AC-124-21: Network flapping non lascia pending/outbox stuck.
- AC-124-22: Account mismatch con pending offline e' fail-closed, non push errato.
- AC-124-23: `mc-agent help-json` e `list commands-json` includono comandi TASK-124 o documentano chiaramente quelli riusati.
- AC-124-24: Ogni scanner TASK-124 ha fixture RED/GREEN e report machine-readable.
- AC-124-25: Nessun fallback manuale sostituisce un comando canonico senza evidence di blocker/misconfigurazione e proposta di harness improvement.
- AC-124-26: Evidence package contiene JSON/Markdown/log redatti, index/README aggiornato e final handoff.
- AC-124-27: Live/offline data usa solo prefissi TASK124_* scoped, cleanup dry-run first e residue-check finale se live data usati.
- AC-124-28: Stati PASS/FAIL/BLOCKED/NOT_RUN/PASS_WITH_NOTES sono applicati coerentemente; nessun `PASS_WITH_NOTES` per AC critici.

## Prompt consigliato per futura EXECUTION
```text
Repo principale: /Users/minxiang/Desktop/iOSMerchandiseControl
Repo Android riferimento: /Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView
Repo Supabase: /Users/minxiang/Desktop/MerchandiseControlSupabase

Esegui TASK-124 solo se il file task e MASTER-PLAN sono ACTIVE / EXECUTION e hanno handoff valido verso Codex.
Prima di modificare codice leggi docs/MASTER-PLAN.md, docs/TASKS/TASK-124-ios-sync-final-architecture-purification.md, evidence README, poi file codice rilevanti.
Non ridefinire il piano. Implementa per slice minime:
1. canonical/head/raw/API preflight;
2. inventory/call-site/pbx evidence;
3. scanner TASK-124 con fixture RED/GREEN;
4. naming cleanup scoped;
5. automatic path no-manual/no-full-pull/no-mainactor-heavy proof;
6. split o motivated-keep di ProductPriceRemoteSupabaseAdapter e SyncEventRemoteSupabaseAdapter;
7. Manual/Recovery classification cleanup solo con call-site evidence;
8. pbxproj cleanup;
9. offline/reconnect/post-offline matrix se tocchi orchestrator/outbox/decision engine/incremental pull/recovery/remote adapter;
10. se uno scenario offline/reconnect fallisce o mostra inefficienza reale, correggi nello stesso task salvo blocker esterno ammesso;
11. build/test/scanner/TASK-123 speed regression se runtime touched;
12. update Execution + Handoff post-execution, then set phase REVIEW.

Vietati: Swift/Kotlin/SQL fuori scope, nuove dipendenze, schema/RLS/grant/RPC changes, service_role client, bypass RLS, hidden manual sync, DONE/100% claims.
```

## Prompt EXECUTION rafforzato post-review
```text
Repo principale: /Users/minxiang/Desktop/iOSMerchandiseControl
Repo Android riferimento: /Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView
Repo Supabase: /Users/minxiang/Desktop/MerchandiseControlSupabase

Avvia TASK-124 solo dopo che MASTER-PLAN e TASK-124 sono stati promossi esplicitamente ad ACTIVE / EXECUTION. Non dichiarare DONE. Handoff finale massimo: ACTIVE / REVIEW.

Ordine obbligatorio:
1. MC_TASK_ID=TASK-124 ./tools/agent/mc-agent.sh help-json
2. MC_TASK_ID=TASK-124 ./tools/agent/mc-agent.sh list commands-json
3. MC_TASK_ID=TASK-124 ./tools/agent/mc-agent.sh preflight --task TASK-124
4. MC_TASK_ID=TASK-124 ./tools/agent/mc-agent.sh git head-consistency --task TASK-124
5. Genera automation-discovery e harness-routing evidence.
6. Se mancano comandi/scanner TASK-124, crea/migliora il harness prima del refactor Swift: task124_scans.py, fixture RED/GREEN, routing mc-agent, help-json/commands-json, report schema 1.1.
7. Solo dopo scanner self-tests GREEN: refactor Swift a slice minime.
8. Usa comandi canonical mc-agent per build/test/smoke/supabase/live/cleanup. Fallback manuale solo se mc-agent e' BLOCKED/MISCONFIGURED o non copre il caso, con evidence e TODO harness.
9. Se tocchi orchestrator/outbox/decision/incremental/recovery/remote, esegui offline/reconnect matrix; se fallisce e il problema e' in scope, correggi nello stesso task.
10. Se tocchi runtime sync, riesegui regressione TASK-123 speed subset o matrice completa secondo rischio.
11. Se usi live data, usa solo prefix TASK124_*, dry-run cleanup first, execute solo con MC_ALLOW_CLEANUP=1 e cleanup_plan_id, poi residue-check.
12. Aggiorna evidence README, final-handoff, MASTER-PLAN. Sposta a REVIEW solo se required gates sono PASS o blocchi esterni sono veri e documentati.

Vietati: service_role client, bypass RLS, schema/RLS/grant/RPC changes, cleanup globale, sync manuale nascosta, full pull normal path, workaround manuali non tracciati, claim 100%/DONE.
```

## Planning note finale
Nota storica: le sezioni di planning sopra restano conservate come baseline del lavoro autorizzato. La closure finale e' documentata in `Review/fix finale — 2026-05-25 17:52 -0400` e nelle evidence TASK-124; non estende il DONE a device fisici, background/locked o long-offline real-device.
