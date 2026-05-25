# TASK-123: iOS/Android Simulator AutoSync Speed Acceptance

## Informazioni generali
- **Task ID**: TASK-123
- **Titolo**: iOS/Android Simulator AutoSync Speed Acceptance
- **File task**: `docs/TASKS/TASK-123-ios-android-simulator-autosync-speed-acceptance.md`
- **Evidence dir**: `docs/TASKS/EVIDENCE/TASK-123/`
- **Stato**: DONE
- **Fase attuale**: REVIEW PASS — STRICT SPEED ACCEPTANCE PASSED
- **Responsabile attuale**: USER / Accepted review closure
- **Data creazione**: 2026-05-24
- **Ultimo aggiornamento**: 2026-05-25 09:35 -0400
- **Ultimo agente che ha operato**: CODEX / Reviewer
- **Readiness**: REVIEW_PASS_STRICT_ACCEPTANCE_PASSED. User requested final review/closure; Codex verified canonical heads, evidence coherence, harness routing, code scope, cleanup/privacy constraints and final gates in the requested simulator same-account live/dev scope. TASK-123 is closed only for simulator iOS 26.4 <-> Android Emulator <-> Supabase live/dev same-account autosync speed. No production-global claim.
- **Tipo task**: runtime/performance acceptance cross-platform simulator; fix mirati solo se emergono bug reali.
- **User override registrato**: l'utente ha richiesto l'avvio diretto di TASK-123 in EXECUTION e ha autorizzato live testing scoped su Supabase live/dev, senza cleanup globale, senza service_role client, senza bypass RLS e senza dati reali non prefissati. Alle 2026-05-24 21:52 -0400 l'utente ha autorizzato anche write/delete sul database Supabase remoto per i test; Codex limita comunque l'uso a righe `TASK123_*`, con dry-run prima del cleanup.

## Relazione con TASK-122
TASK-122 resta `ACTIVE / REVIEW`, non `DONE`, non 100% claim. TASK-123 usa TASK-122 come baseline architetturale locale gia' review-ready:
- SupabaseTransportClient thin transport.
- Remote/Recovery adapter owner reali della logica domain/query/mapping.
- Scanner hard PASS.
- Debug/Release build PASS.
- automatic architecture/domain, broad sync e manual sync regression PASS.
- Architecture efficiency PASS.
- Runtime efficiency PASS_WITH_NOTES.
- Production readiness BLOCKED_EXTERNAL per live/device/offline/cross-platform.

TASK-123 copre il successivo perimetro runtime: simulator iOS <-> Android same-account autosync speed.

## Obiettivo
Validare e, se necessario, correggere la auto-sync reale tra:
- iOS Simulator.
- Android Emulator.
- Supabase live/dev.
- stesso account gia' autenticato.

Focus:
- velocita' propagazione auto-sync iOS -> Android.
- velocita' propagazione auto-sync Android -> iOS.
- nessun uso di sync manuale per completare il test.
- nessun device fisico Android.
- nessuna nuova policy conflitti/merge.

## Target performance
- warm auto-sync p50 <= 3.0s.
- warm auto-sync p95 <= 5.0s.
- hard timeout singola propagazione <= 15s.
- no-op sync <= 2.0s se misurabile.
- zero duplicati logici.
- zero pending/outbox stuck.
- zero drift finale tra iOS, Android e Supabase per dati `TASK123_*`.

## Stato iniziale iOS
Da screenshot utente, iOS Options mostra:
- Cloud account connected.
- Local and cloud data found.
- Sync blocked until Review.
- Automatic sync active but no changes.

Prima della misurazione auto-sync, Codex deve risolvere o automatizzare in modo sicuro il gate "Local and cloud data found / Review" usando il flow Review esistente. Vietato cancellare dati reali.

## Riferimento Android usato
Repo runtime/riferimento: `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView`.

Uso ammesso:
- target runtime per emulator acceptance.
- riferimento funzionale.

Uso vietato:
- copiare Kotlin in Swift.
- usare Android come autorizzazione a cambiare policy conflitti.
- usare device fisico Android per questa task.

## Riferimento Supabase usato
Backend: `/Users/minxiang/Desktop/MerchandiseControlSupabase`.

Uso ammesso:
- live/dev scoped testing con dati `TASK123_*`.
- schema/RLS/grants/status read-only.
- cleanup solo righe `TASK123_*`, con dry-run prima.
- admin/postgres solo lato backend/CLI se RLS impedisce cleanup authenticated e solo dopo evidence.

Uso vietato:
- service_role nel client.
- bypass RLS.
- cancellazione `auth.users`.
- cleanup globale.
- migration/schema/RLS/grant/RPC change salvo blocker reale e autorizzazione separata documentata.

## Dataset scoped
Usare solo:
- supplier: `TASK123_SPEED_SUPPLIER_*`.
- category: `TASK123_SPEED_CATEGORY_*`.
- product barcode: `TASK123_SPEED_BARCODE_*`.
- product name: `TASK123_SPEED_PRODUCT_*`.
- history/session: `TASK123_SPEED_SESSION_*`.
- sync events/outbox: `TASK123_SPEED_*`.
- prefissi alternativi ammessi dal brief: `TASK123_AUTOSYNC_*`.

## Scenari minimi
1. Catalog product create.
2. Catalog product update.
3. ProductPrice purchase update.
4. ProductPrice retail update.
5. History/session create/update se gia' supported da automatic sync.
6. No-op second sync.
7. Burst small changes: 10 prodotti/modifiche consecutive.
8. Recovery from app restart: iOS restart poi Android change; Android restart poi iOS change.
9. Pending/outbox drain: nessun evento stuck.
10. Drift check finale: iOS count = Android count = Supabase count nel perimetro `TASK123_*`.

## Matrice velocita'
Minimo:
- 20 iterazioni iOS -> Android warm.
- 20 iterazioni Android -> iOS warm.
- 5 iterazioni cold-ish dopo app restart iOS.
- 5 iterazioni cold-ish dopo app restart Android.
- 3 no-op sync checks per lato.

Output:
- p50, p90, p95, max.
- failure count.
- timeout count.
- duplicate count.
- pending/outbox stuck count.
- drift finale.

## Acceptance
- p50 <= 3.0s per warm iOS -> Android.
- p50 <= 3.0s per warm Android -> iOS.
- p95 <= 5.0s per warm bidirezionale.
- max <= 15s salvo primo cold start documentato.
- timeout count = 0.
- duplicate count = 0.
- drift finale = 0.
- pending/outbox stuck = 0.

## Fix ammessi
Solo fix mirati se i test runtime/performance rivelano bug reali:
- trigger automatico immediato dopo local write/outbox enqueue.
- debounce/coalescing breve ma non lento.
- single-flight corretto.
- cancellazione sicura task vecchi.
- refresh target dopo sync_events nuovi.
- riduzione polling interval entro limiti batteria/runtime ragionevoli.
- evitare MainActor/UI freeze iOS.
- evitare WorkManager lento per foreground Android se esiste gia' runtime foreground.
- garantire che Options/Home osservino lo stato senza bloccare sync.

## Fix vietati
- nuova policy conflitti/merge.
- full pull normale per ogni modifica.
- sync manuale nascosta per falsare risultati.
- bypass RLS.
- service_role client.
- cancellazione dati reali.
- mega-service nuovo.
- refactor cosmetici o architetturali non necessari.

## Execution
### Stato iniziale
- 2026-05-24 21:39 -0400: TASK-123 aperta in ACTIVE / EXECUTION su richiesta utente.
- GitHub/local/origin main verificati coerenti su `8116de9d7900abc9dddb2a7a6c6311b65b772358` prima della creazione tracking locale TASK-123.
- GitHub raw `docs/MASTER-PLAN.md` consultato e coerente con local pre-TASK-123: TASK-122 ancora ACTIVE / REVIEW.
- 2026-05-24 21:59 -0400: execution bloccata prima della matrice runtime per `BLOCKED_EXTERNAL_AUTH_SESSION`: iOS Simulator non ha sessione Supabase valida.

### Piano minimo Codex
1. Creare tracking TASK-123 e evidence directory senza toccare codice runtime.
2. Eseguire preflight/head/config/harness discovery.
3. Rilanciare guardie architetturali TASK-122 richieste.
4. Eseguire build/test base iOS, Android e Supabase read-only.
5. Preparare simulator/emulator/auth/session e risolvere il gate Review iOS senza cancellare dati reali.
6. Misurare matrice autosync con dati `TASK123_*`.
7. Applicare solo fix mirati se failure reali e ripetere matrice.
8. Cleanup scoped dry-run + cleanup `TASK123_*`.
9. Compilare evidence finali e handoff a Claude.

### File previsti inizialmente
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-123-ios-android-simulator-autosync-speed-acceptance.md`
- `docs/TASKS/EVIDENCE/TASK-123/README.md`
- `docs/TASKS/EVIDENCE/TASK-123/agent-runs/`

### Esecuzione parziale
- Tracking TASK-123 creato.
- MASTER-PLAN aggiornato lasciando TASK-122 in REVIEW/non DONE.
- Head consistency PASS: local HEAD, origin/main e GitHub origin main coerenti su `8116de9d7900abc9dddb2a7a6c6311b65b772358`.
- Preflight PASS.
- Config validate PASS.
- Harness discovery acquisita.
- Architecture guard rerun: PASS per `source-format`, `swift-source-shape`, `sync-inventory`, `remote-transport-thin`, `adapter-delegation-depth`, `domain-method-ownership`, `manual-debug-boundary`, `transport-protocol-conformance`, `composition-import-boundary`, `remote-query-ownership`, `debug-seed-boundary`, `dto-mapper-duplication`, `sensitive`, `evidence`, `report validate-json`; `sync-architecture`, `xcode-membership`, `dead-code` PASS con routing TASK-122 legacy; `supabase-query-map` PASS con sintassi `--task TASK-123 --strict --read-only`.
- iOS Debug build PASS.
- iOS Release build PASS.
- iOS sync tests PASS.
- iOS automatic-domain tests PASS.
- iOS automatic-architecture tests PASS.
- Android `assembleDebug` PASS.
- Android broad `testDebugUnitTest` FAIL: 470 tests, 151 failed, 2 skipped, root failure class observed as ByteBuddy/attach; not attributed to TASK-123 because no Kotlin changes were made.
- Android sync targeted tests PASS.
- Supabase status-redacted PASS.
- Supabase RLS verify PASS.
- Supabase grants verify BLOCKED_EXTERNAL: project link/local DB readiness required by harness.
- Supabase schema verify BLOCKED_EXTERNAL: harness hang/duplicate process terminated and recorded.
- iOS app installed/launched on simulator `AC6FBFC3-A97F-412C-BEC0-F88B9956107B`.
- Android app installed on emulator `emulator-5554`.
- Android auth preflight PASS with `MC_ANDROID_DEVICE_SERIAL=emulator-5554`.
- iOS auth preflight BLOCKED_EXTERNAL: `AUTH_SESSION_NOT_READY`, no fallback session candidate.
- iOS Options visible state confirms signed-out (`login`/`sign in required` in current Chinese UI) and 4 pending local changes.

### Esecuzione dopo login iOS
- 2026-05-24 22:27 -0400 circa: dopo login utente su iOS Simulator, iOS auth preflight PASS e Android auth preflight PASS con account owner redatto coerente.
- Gate iOS Options "Local and cloud data found / Review" risolto con il flow Review esistente, scegliendo merge/same-account in modo non distruttivo.
- Primo live smoke `TASK123_SPEED_` ha evidenziato blocco harness per prefisso TASK-123; fixato whitelist TASK123 su iOS/Android harness.
- Secondo live smoke ha evidenziato starvation iOS incremental pull: gli eventi Android nuovi non venivano applicati perche' il watermark restava bloccato su una vecchia pagina con gap unrecoverable. Fix mirato applicato e test aggiunto.
- Smoke post-fix iOS pull PASS: iOS riceve Android via `EVENT_INCREMENTAL` senza full pull.
- Android foreground auto-push risultava lento sul batch catalog/history per debounce seriale 2.0s; ridotto a 500ms con test unitari.
- 5 live mutation-near-realtime post-tuning PASS:
  - iOS -> Android receiver p50 0.962s, p95 1.015s, max 1.028s.
  - Android -> iOS receiver p50 0.409s, p95 0.444s, max 0.452s.
  - Batch multi-mutation iOS total p50 4.555s, p95 4.892s.
  - Batch multi-mutation Android total p50 13.619s, p95 17.714s, max 18.724s.
- Strict full acceptance non dichiarata: questi sono 5 smoke/cold-ish post-tuning, non 20+20 warm isolati; batch totals includono piu' write seriali.
- Supabase cleanup dry-run + execute + residue PASS per `TASK123_SPEED_`; residue broad `TASK123_` PASS/0.
- Android local cleanup execute + broad dry-run `TASK123_` PASS/0 dopo fix harness cleanup.
- iOS runtime store query read-only `TASK123_` PASS/0 per supplier/category/product/product price/history/pending/outbox.

### Continuazione 2026-05-25 00:27 -0400
- Fase 0 canonical alignment rieseguita: iOS local `main` = `origin/main` = `cd31c09e9b97356f6c8ac9c6fca586dab39fd3d9`; Android local `main` = `origin/main` = `1307d64deee483822494eabec2b221727ccdbd65`.
- GitHub raw iOS verificato per MASTER-PLAN/TASK-123; GitHub raw Android verificato sui file reali `CatalogAutoSyncCoordinator.kt`, `HistorySessionPushCoordinator.kt` e relativi test: solo `500L`, nessun doppio `2_000L` nei file TASK-123.
- Fase 1 duplicazioni: controllati `AccountBindingStore`, `SyncDecisionInputProvider`, `SyncEventIncrementalDomainApplyService`, Android debounce/test; nessun doppione operativo trovato. `RealtimeRefreshCoordinator.DEBOUNCE_MS = 2_000L` resta fuori dal fix foreground push TASK-123 e non e' stato modificato senza misura che lo identifichi come collo di bottiglia.
- Harness dedicato aggiunto:
  - iOS `test123IOSSingleCatalogCreatePropagation`: singola create catalog, timing `TASK123_IOS_SINGLE_PROPAGATION`.
  - Android `test123AndroidSingleCatalogCreatePropagation`: singola create catalog foreground auto-push, timing `TASK123_ANDROID_SINGLE_PROPAGATION`.
  - `mc-agent live task123-single-propagation`: loop warm bidirezionale, JSON per iterazione con campi `localSaveMs`, `localOutboxEnqueueMs`, `sourceAutoPushStartDelayMs`, `remotePushMs`, `syncEventAvailableMs`, `targetRealtimeDetectedMs`, `targetFetchMs`, `targetApplyMs`, `totalPropagationMs`.
- Check eseguiti:
  - `bash -n tools/agent/lib/supabase.sh tools/agent/lib/ios.sh tools/agent/lib/android.sh tools/agent/mc-agent.sh`: PASS.
  - iOS targeted sync tests: PASS, evidence `agent-runs/20260525T042302Z-ios-test-sync-task-TASK-123-p88645.json`.
  - Android `:app:assembleDebug :app:assembleDebugAndroidTest`: first run FAIL per import mancante nel nuovo androidTest, fix minimo applicato; rerun PASS.
  - `git diff --check`: PASS su iOS repo e Android repo.
- Live validation ridotta `MC_TASK123_SINGLE_ITERATIONS=1 live task123-single-propagation --task TASK-123 --prefix TASK123_SINGLE_`: BLOCKED_EXTERNAL prima di creare dati. Root cause: iOS auth preflight fallisce con `AUTH_SESSION_NOT_READY`, fallback `candidateCount=0`, `simulatorFallbackSessionPresent=false`; evidence `agent-runs/20260525T042558Z-live-task123-single-propagation-task-TASK-123-prefix-TASK123_SINGLE_-p90139.json`.
- Dati creati nel run bloccato: 0. Cleanup non necessario per `TASK123_SINGLE_` da quel run.

## Fix
- iOS `OptionsView.swift`: il flow Review confermato applica il binding account locale tramite `AccountSyncChoiceBindingApplier`.
- iOS `AccountBindingStore.swift`: aggiunto applier dedicato per persistere/cancellare in modo testabile il binding da scelta Review.
- iOS `SyncDecisionInputProvider.swift`: binding same-account confermato senza baseline non forza bootstrap/recovery come se fosse local data anonimo.
- iOS `SyncEventIncrementalDomainApplyService.swift`: su gap unrecoverable salva comunque `watermarkAfter` per evitare starvation su pagine vecchie.
- iOS/Android TASK-103/114 harness: prefisso `TASK123_` ammesso per live acceptance.
- iOS harness: emissione timing TASK-123 per batch iOS.
- `tools/agent/lib/supabase.sh`: parsing timing iOS e breakdown JSON per `mutation-near-realtime`.
- Android `CatalogAutoSyncCoordinator.kt` e `HistorySessionPushCoordinator.kt`: debounce foreground auto-push ridotto a 500ms.
- Android test/harness: test debounce TASK-123 e cleanup locale `TASK123_` con evidence instrumentation status.
- iOS/Android TASK-123 single propagation harness: aggiunti step single catalog create e comando live dedicato `task123-single-propagation`; nessuna nuova dipendenza, nessun cambio schema/RLS/API pubblica.
- Android androidTest import fix: aggiunto import `CatalogAutoSyncCoordinator` richiesto dal nuovo timing single.

## Handoff post-execution
### FINAL REVIEW CLOSURE — 2026-05-25 09:35 -0400
Final review found no runtime correctness, security, RLS, cleanup or performance blocker in the TASK-123 acceptance scope. A small tracking/harness documentation fix was applied: TASK-123 live commands are now discoverable in `help-json` / `commands-json`, and historical handoffs below are explicitly marked as superseded.

Verdict: DONE / REVIEW PASS — STRICT SPEED ACCEPTANCE PASSED, limited to simulator iOS 26.4 <-> Android Emulator <-> Supabase live/dev, same account, autosync speed.

Not claimed: production-global 100%, real device, long background/locked screen, long offline, complex conflict policy, multi-user/account policy.

### READY_FOR_REVIEW_STRICT_ACCEPTANCE — 2026-05-25 02:50 -0400
TASK-123 execution completed in the requested simulator same-account autosync speed scope. The task is handed to Claude/User review, not marked DONE.

Final evidence:
- `docs/TASKS/EVIDENCE/TASK-123/autosync-20x20-warm-matrix.md/json`: 20+20 warm PASS.
- `docs/TASKS/EVIDENCE/TASK-123/autosync-single-propagation-ios-to-android.md/json`: iOS->Android 20/20 PASS, p50 911ms, p95 954ms, max 1027ms.
- `docs/TASKS/EVIDENCE/TASK-123/autosync-single-propagation-android-to-ios.md/json`: Android->iOS 20/20 PASS, p50 408ms, p95 445ms, max 448ms.
- `docs/TASKS/EVIDENCE/TASK-123/autosync-cold-restart-matrix.md/json`: cold-ish 5+5 PASS.
- `docs/TASKS/EVIDENCE/TASK-123/autosync-noop-matrix.md/json`: no-op 3+3 PASS, max <= 2s measured.
- `docs/TASKS/EVIDENCE/TASK-123/autosync-burst-10-matrix.md/json`: burst-10 PASS, scoped duplicates 0.
- `docs/TASKS/EVIDENCE/TASK-123/autosync-batch-multiwrite-summary.md/json`: legacy batch multi-write PASS, kept separate from single propagation.
- `docs/TASKS/EVIDENCE/TASK-123/cleanup-residue.md/json`: Supabase, Android local and iOS local scoped residue PASS/0.
- `docs/TASKS/EVIDENCE/TASK-123/final-acceptance-matrix.md/json`: strict TASK-123 speed acceptance ELIGIBLE.

Fixes applied in this continuation:
- Android test fixture scope now includes TASK123 single supplier/category/barcodes.
- iOS matrix runner removes the per-step `.xcresult` before each repeated `test-without-building`, avoiding iteration-2 bundle collisions.
- Live single harness foregrounds Android before each iOS->Android receive leg after Android instrumentation.
- Added cold-ish restart, no-op and burst-10 live harness commands.
- Burst duplicate detection uses scoped remote product count per direction instead of global target product delta.
- Performed scoped Supabase cleanup dry-run + execute, Android local cleanup execute, and iOS local scoped cleanup.

Final checks:
- iOS Debug build PASS: `agent-runs/20260525T064501Z-ios-build-debug-task-TASK-123-p52700.json`.
- iOS Release build PASS: `agent-runs/20260525T064518Z-ios-build-release-task-TASK-123-p53330.json`.
- iOS targeted sync tests PASS: `agent-runs/20260525T064632Z-ios-test-sync-task-TASK-123-p54319.json`.
- Android assembleDebug + assembleDebugAndroidTest PASS.
- Android targeted sync/debounce unit tests PASS.
- TASK-122 architecture guard `sync-efficiency-acceptance` PASS: `docs/TASKS/EVIDENCE/TASK-122/agent-runs/20260525T064927Z-scan-sync-efficiency-acceptance-task-TASK-122-strict-p55454.json`.
- JSON validation PASS.
- `git diff --check` PASS for iOS and Android repos.

NEXT_ACTION:
- Claude/User review TASK-123 evidence and decide closure. Codex must not mark DONE directly.

### SUPERSEDED_HISTORY — BLOCKED_EXTERNAL_AUTH_SESSION — 2026-05-25 00:27 -0400
Superseded by `READY_FOR_REVIEW_STRICT_ACCEPTANCE` and final review closure above; kept as historical execution record only.

TASK-123 cannot proceed to 20+20 warm matrix, cold-ish restart, no-op or burst-10 while the iOS Simulator app-auth session is absent.

Evidence:
- `docs/TASKS/EVIDENCE/TASK-123/agent-runs/20260525T042302Z-ios-test-sync-task-TASK-123-p88645.json`: iOS targeted sync tests PASS after harness changes.
- Android `:app:assembleDebug :app:assembleDebugAndroidTest`: PASS after import fix.
- `docs/TASKS/EVIDENCE/TASK-123/agent-runs/20260525T042558Z-live-task123-single-propagation-task-TASK-123-prefix-TASK123_SINGLE_-p90139.json`: reduced live single-propagation validation BLOCKED before writes with `AUTH_SESSION_NOT_READY`, `candidateCount=0`.

NEXT_ACTION:
1. User signs in again on iOS Simulator `iPhone 17 Pro / iOS 26.5` with the same account used by Android emulator `emulator-5554`.
2. Codex reruns `MC_ALLOW_LIVE=1 MC_ANDROID_DEVICE_SERIAL=emulator-5554 MC_TASK123_SINGLE_ITERATIONS=1 ./tools/agent/mc-agent.sh live task123-single-propagation --task TASK-123 --prefix TASK123_SINGLE_`.
3. If the reduced run PASSes, Codex reruns with default 20 iterations and continues cold-ish, no-op, burst-10, batch, cleanup and final acceptance. If a measured iteration fails, Codex follows MEASURE -> IDENTIFY BOTTLENECK -> FIX MINIMO -> TEST -> RERUN MATRIX.

### SUPERSEDED_HISTORY — ACTIVE_EXECUTION_PARTIAL — 2026-05-24 23:22 -0400
Superseded by `READY_FOR_REVIEW_STRICT_ACCEPTANCE` and final review closure above; kept as historical execution record only.

TASK-123 is no longer blocked by auth/session. The same-account simulator/emulator autosync path works and cleanup is clean, but strict speed acceptance is not complete.

Evidence:
- `docs/TASKS/EVIDENCE/TASK-123/simulator-auth-readiness.md/json`: iOS and Android auth PASS.
- `docs/TASKS/EVIDENCE/TASK-123/ios-options-review-gate.md/json`: Review gate PASS.
- `docs/TASKS/EVIDENCE/TASK-123/autosync-speed-summary.md/json`: 5 post-tuning live smoke PASS with receiver p95 <= 1.015s iOS->Android and <= 0.444s Android->iOS.
- `docs/TASKS/EVIDENCE/TASK-123/fix-log.md`: complete fix list.
- `docs/TASKS/EVIDENCE/TASK-123/cleanup-residue.md/json`: final scoped residue 0.
- Historical note: at this point `final-acceptance-matrix.md/json` still said not final acceptance; this was later superseded by the 02:50 strict acceptance evidence and final review closure above.

NEXT_ACTION:
- Add or run a dedicated in-process TASK-123 warm latency harness and complete 20 isolated warm iterations per direction, cold-ish restart checks, no-op checks, burst-10 changes and final drift check before moving to REVIEW or claiming 100% PASS.
- `docs/TASKS/EVIDENCE/TASK-123/ios-options-initial.png`: Options UI captured during signed-out state.
- `docs/TASKS/EVIDENCE/TASK-123/simulator-auth-readiness.md`: readiness summary.
- `docs/TASKS/EVIDENCE/TASK-123/final-handoff.md`: blocked handoff summary.

NEXT_ACTION:
1. User completes login on iOS Simulator `AC6FBFC3-A97F-412C-BEC0-F88B9956107B` with the same test account used by Android emulator.
2. User avoids deleting real data; leave pending local data untouched unless explicitly scoped/prefixed.
3. Codex reruns `ios auth-preflight --live --task TASK-123`.
4. If iOS shows "Local and cloud data found / Review" after login, Codex uses the existing Review flow safely before measuring.
5. Resume from Phase 4, then run the full autosync speed matrix.

## Handoff post-fix
_Da compilare solo se la task entra in FIX._
