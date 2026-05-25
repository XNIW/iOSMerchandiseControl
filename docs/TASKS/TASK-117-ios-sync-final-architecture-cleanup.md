# TASK-117: iOS Sync Final Architecture Cleanup

## Informazioni generali
- **Task ID**: TASK-117
- **Titolo**: iOS Sync Final Architecture Cleanup - remove legacy automatic runtime and dead code
- **File task**: `docs/TASKS/TASK-117-ios-sync-final-architecture-cleanup.md`
- **Stato**: DONE
- **Fase attuale**: CLOSED_BY_USER_OVERRIDE_AFTER_SYNC_RESTRUCTURING
- **Responsabile attuale**: USER / Accepted closure
- **Data creazione**: 2026-05-23
- **Ultimo aggiornamento**: 2026-05-25 10:11 -0400
- **Ultimo agente che ha operato**: CODEX / Tracking closure
- **Readiness**: CLOSED_DONE_BY_USER_OVERRIDE_AFTER_SYNC_RESTRUCTURING. External live/device blockers accepted as non-blocking after later TASK-123 simulator same-account autosync acceptance; no production-global claim.
- **Motivo transizione**: User override explicit end-to-end execution authorization.

## Vincoli del turno
- Execution autorizzata da user override esplicito.
- Nessun claim `DONE`, `production ready` o `architecture perfect`.
- Android e' solo riferimento funzionale; i gate Android live richiedono serial/device esterno.
- Supabase e' backend condiviso; mutation live solo task-scoped e safety-gated.
- TASK-116 resta `ACTIVE / REVIEW`, non DONE.
- TASK-115 resta `BLOCKED / SUPERSEDED_BY_TASK-116`.

## Obiettivo
Completare davvero l'architettura sync iOS finale rimuovendo il runtime automatico legacy/misto lasciato da TASK-115/TASK-116. La sync automatica normale deve essere posseduta da `SyncOrchestrator` piu' servizi domain reali sotto `iOSMerchandiseControl/Sync`, senza dipendere da `SupabaseManualSyncViewModel`, `SupabaseManualSyncCompatibilityAdapter`, `SupabaseManualSyncReleaseFactory`, o tipi/protocolli `SupabaseManualSync*` nel path automatico.

## P0 HEAD consistency
Risultato planning corrente: `HEAD_CONSISTENCY_PASS`.

| Source | Value |
|---|---|
| `git rev-parse HEAD` | `e14b433613ab59beb5a9796a00f285b4d8a15e5b` |
| `git rev-parse origin/main` | `e14b433613ab59beb5a9796a00f285b4d8a15e5b` |
| `git ls-remote origin main` | `e14b433613ab59beb5a9796a00f285b4d8a15e5b` |
| GitHub API `commits/main` | `e14b433613ab59beb5a9796a00f285b4d8a15e5b` |
| GitHub rendered `commits/main` latest | `e14b433` |

Se in una revisione futura una fonte non coincide, lo stato task deve diventare `ACTIVE / PLANNING-BLOCKED_HEAD_MISMATCH`, aggiungendo `HEAD_CONSISTENCY_RECHECK_REQUIRED` prima di qualunque execution.

## Diagnosi repo-grounded
- `ContentView.swift` istanzia ancora `SupabaseManualSyncForegroundRootHost`, passa `SupabaseManualSyncViewModel` a `OptionsView` e compone `SyncOrchestrator` con `SupabaseManualSyncCompatibilityAdapter` + `SupabaseManualSyncReleaseFactory`.
- `OptionsView.swift` usa ancora `SupabaseManualSyncViewModel` per la card pubblica automatic sync e per la card manuale DEBUG.
- `SyncOrchestrator.swift` dipende ancora da `SyncOrchestratorLegacySyncAdapter`, `manualAdapter`, `legacyManualSyncViewModel` e `SupabaseManualSyncSemiAutomaticTriggerSource`.
- `SyncAutomaticRuntimeProviders.swift` espone ancora contratti automatici con `ManualPushPlan`, `SupabaseManualPushResult`, `ProductPriceManualPushResult`, `SupabaseManualSyncActivityRegistration*`, `SupabaseManualSyncHistorySessionSummary` e `SupabaseSyncEventIncrementalApplySummary`.
- I file `SupabaseSyncEventIncrementalApplyService.swift`, `SupabasePullApplyService.swift`, `SupabaseProductPriceApplyService.swift` e `HistorySessionSyncService.swift` non vanno pre-classificati come domain finali: restano `UNKNOWN_REQUIRES_AUDIT` finche' execution non prova call graph, test e ruolo reale.

## Target architecture
```text
SwiftUI Views
-> SyncStatusPresenter / OptionsSyncSummaryProvider for UI-only observation
-> SyncOrchestrator as only automatic owner
-> SyncDecisionEngine
-> SyncStateStore
-> AccountBindingStore / LocalStoreIdentity / WatermarkStore
-> LocalOutboxStore / PendingChangeCoalescer
-> SyncEventOutboxRecorder / SyncEventOutboxDrainer
-> CatalogPushService / ProductPricePushService / HistorySessionPushService
-> SyncEventIncrementalPullService
-> SyncEventIncrementalDomainApplyService
-> CatalogIncrementalApplyService
-> ProductPriceIncrementalApplyService
-> HistoryIncrementalApplyService
-> BootstrapPullService / FullRecoveryService / DriftReconciliationService
```

Regole finali:
- `ContentView.swift` non istanzia e non passa `SupabaseManualSyncViewModel`, `SupabaseManualSyncCompatibilityAdapter`, `SupabaseManualSyncReleaseFactory` o `SupabaseManualSyncForegroundRootHost`.
- `OptionsView.swift` e' observer-only: usa `SyncStatusPresenter` / `OptionsSyncSummaryProvider` cache e isola eventuale azione manuale esplicita.
- `SyncOrchestrator` automatic path non usa tipi, protocolli, DTO o result `SupabaseManualSync*`.
- Manual sync vive solo sotto `Sync/Manual` o `ManualSync`, mai nel path automatico normale.
- Full pull e' consentito solo per bootstrap, recovery, manual sync esplicita o harness.
- Un solo owner puo' gestire safety loop, reconnect, realtime signal e local mutation triggers.

## Acceptance criteria
- **CA-117-01**: `ContentView.swift` non istanzia `SupabaseManualSyncViewModel`, `SupabaseManualSyncCompatibilityAdapter` o `SupabaseManualSyncReleaseFactory`.
- **CA-117-02**: `ContentView.swift` non contiene `SupabaseManualSyncForegroundRootHost`; root host rinominato e ridotto a owner app-level pulito o spostato fuori View se possibile.
- **CA-117-03**: `OptionsView.swift` e' observer-only: non decide sync automatica e non avvia foreground/realtime/reconnect.
- **CA-117-04**: `SyncOrchestrator.swift` non contiene `legacyAdapter`, `legacyManualSyncViewModel`, `SupabaseManualSyncCompatibilityAdapter`, `SupabaseManualSyncViewModel`.
- **CA-117-05**: `SyncOrchestrator` riceve solo runtime/domain services/protocols nuovi, non tipi `SupabaseManualSync*`.
- **CA-117-06**: `SyncAutomaticRuntime.swift` non usa protocolli, DTO, result o trigger `SupabaseManualSync*`.
- **CA-117-07**: `SyncAutomaticRuntimeProviders.swift` non espone `ManualPushPlan`, `SupabaseManualPushResult`, `ProductPriceManualPushResult`, `SupabaseManualSyncActivityRegistration*`, `SupabaseManualSyncHistorySessionSummary`, o `SupabaseSyncEventIncrementalApplySummary` nel contratto automatico.
- **CA-117-08**: La manual sync esplicita, se mantenuta, sta in un modulo/boundary separato `Sync/Manual` o `ManualSync`, e non e' referenziata dal path automatico normale.
- **CA-117-09**: `SupabaseManualSyncCompatibilityAdapter.swift` e' eliminato o manual-only con grep/gate che ne vieta l'uso da automatic runtime.
- **CA-117-10**: `SupabaseSyncEventIncrementalApplyService.swift` e' eliminato o resta solo compat wrapper non usato dal path automatico normale.
- **CA-117-11**: `SyncEventIncrementalPullService` possiede fetch/dispatch/watermark e non passa da wrapper legacy.
- **CA-117-12**: Catalog/ProductPrice/History incremental apply sono servizi reali con test di idempotenza, dirty skip, tombstone, orphan handling, no watermark advance on failure.
- **CA-117-13**: Outbox push automatico e' owner-bound e non passa da VM legacy.
- **CA-117-14**: Full pull e' impossibile da foreground/timer/realtime/local mutation; consentito solo bootstrap/recovery/manual/harness.
- **CA-117-15**: Nessun doppio owner: un solo safety loop/reconnect/realtime signal path.
- **CA-117-16**: UI Options/root banner mantiene comportamento utente, localizzazioni IT/EN/ES/ZH e niente spinner 0/0.
- **CA-117-17**: Nessun codice vecchio inutile resta nel target Release senza classificazione.
- **CA-117-18**: Build Debug/Release PASS in execution.
- **CA-117-19**: XCTest sync/import/database/history/options regressions PASS in execution.
- **CA-117-20**: no-legacy-runtime-path strict PASS con scan fisico su sorgenti reali, non solo naming.
- **CA-117-21**: no-full-pull-normal-path strict PASS.
- **CA-117-22**: Physical iPhone / Android live / account matrix restano BLOCKED solo se device/fixture non disponibili, mai PASS_WITH_NOTES.

## Status semantics
- `PASS`: gate eseguito e riuscito con evidence.
- `FAIL`: gate eseguito e fallito per app, harness, schema o test.
- `BLOCKED`: prerequisito esterno mancante.
- `NOT_RUN`: non eseguito, non conta mai come PASS.
- `PASS_WITH_NOTES`: solo non-critical.

`PASS_WITH_NOTES` e' vietato per HEAD consistency, no-legacy-runtime-path, no-full-pull-normal-path, account matrix, physical iPhone, near-realtime, offline reconnect, cleanup/residue, sensitive scan, Debug/Release builds e iOS sync tests.

## Review / Execution / Done gates
- TASK-117 puo' andare a planning review solo dopo markdown completeness, HEAD consistency PASS o blocker esplicito, automation plan, command-gap backlog, evidence README e MASTER-PLAN alignment.
- TASK-117 non puo' andare a execution senza nuovo prompt utente esplicito.
- TASK-117 non puo' essere DONE se qualunque critical CA e' `NOT_RUN`, `FAIL` o `PASS_WITH_NOTES`, salvo accettazione utente esplicita per blocker esterni.

## Handoff planning
TASK-117 ACTIVE / PLANNING, not READY_FOR_EXECUTION until planning review.

## Execution (Codex)

### Execution start - 2026-05-23 17:03:53 -0400

User override esplicito ricevuto: il planning TASK-117 e' approvato dall'utente e Codex e' autorizzato a promuovere il task da `ACTIVE / PLANNING` a `ACTIVE / EXECUTION`.

#### P0 HEAD/local/GitHub consistency

Esito: `PASS`.

| Check | Esito |
|---|---|
| `git status --short` | Solo tracking/evidence TASK-117 documentale gia' presente come baseline approvata: `docs/MASTER-PLAN.md`, `docs/TASKS/TASK-117-ios-sync-final-architecture-cleanup.md`, `docs/TASKS/EVIDENCE/TASK-117/` |
| Modifiche runtime non committate | Nessuna (`git diff --name-only -- iOSMerchandiseControl ...` vuoto) |
| `git branch --show-current` | `main` |
| `git rev-parse HEAD` | `e14b433613ab59beb5a9796a00f285b4d8a15e5b` |
| `git rev-parse origin/main` | `e14b433613ab59beb5a9796a00f285b4d8a15e5b` |
| `git ls-remote origin main` | `e14b433613ab59beb5a9796a00f285b4d8a15e5b` |
| `git ls-remote https://github.com/XNIW/iOSMerchandiseControl.git main` | `e14b433613ab59beb5a9796a00f285b4d8a15e5b` |
| GitHub API `commits/main` | `e14b433613ab59beb5a9796a00f285b4d8a15e5b` |
| GitHub rendered `commits/main` via `curl` HTML embedded data | latest rendered commit `e14b433613ab59beb5a9796a00f285b4d8a15e5b`, short `e14b433`, message `Task 116 D` |

I file minimi richiesti sono stati confrontati con `git show HEAD:<path>`, GitHub raw `main` e GitHub blob rendered page. Per tutti: hash SHA-256 `HEAD` == `raw`; pagina rendered HTTP `200`.

#### Dirty baseline classification

Le modifiche locali preesistenti sono documentali TASK-117:
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-117-ios-sync-final-architecture-cleanup.md`
- `docs/TASKS/EVIDENCE/TASK-117/*`

Classificazione: `DOCUMENTAL_TASK117_APPROVED_BASELINE`.

Nessun file Swift/Kotlin/SQL/runtime risultava modificato prima dell'execution.

#### Piano minimo prima della patch runtime

1. Promuovere tracking/evidence a `ACTIVE / EXECUTION` mantenendo TASK-116 in `ACTIVE / REVIEW` e TASK-115 in `BLOCKED / SUPERSEDED_BY_TASK-116`.
2. Eseguire i baseline harness canonici e documentarne risultato/report.
3. Fare audit call graph reale su root host, Options, orchestrator, runtime/providers, incremental pull/apply, outbox e manual sync boundary.
4. Implementare solo le slice necessarie a rimuovere il coupling automatico da `SupabaseManualSync*`, aggiungendo/migliorando harness e test prima dei cambi runtime quando il comportamento cambia.
5. Verificare Debug/Release, sync tests, strict scans, smoke/live gates dove disponibili; riportare blocker esterni come `BLOCKED`, non `PASS`.

#### File runtime candidati da modificare dopo audit

- `iOSMerchandiseControl/ContentView.swift`
- `iOSMerchandiseControl/OptionsView.swift`
- `iOSMerchandiseControl/Sync/SyncOrchestrator.swift`
- `iOSMerchandiseControl/Sync/SyncAutomaticRuntime.swift`
- `iOSMerchandiseControl/Sync/SyncAutomaticRuntimeProviders.swift`
- `iOSMerchandiseControl/Sync/*`
- eventuali file `ManualSync`/`Sync/Manual` necessari a isolare il boundary manuale
- `tools/agent/*` e `iOSMerchandiseControlTests/*` per harness/test richiesti

Nessuna modifica runtime e' stata applicata in questa sezione.

### Execution completion/blocker handoff - 2026-05-23 17:48:36 -0400

#### Modifiche fatte
- `ContentView.swift`: sostituito il root host automatico legacy con `AppSyncRootHost`; rimosso passaggio di VM/factory/adapter manuali dal path root.
- `OptionsView.swift`: card pubblica sync resa observer-only su auth/baseline/pending + `SyncStatusPresenter`; rimosso blocco DEBUG manual sync non referenziato.
- `SyncOrchestrator.swift`: rimosse dipendenze da adapter/VM/protocolli `SupabaseManualSync*`; unico owner automatico per foreground, local mutation, realtime signal, reconnect e safety loop.
- `SyncAutomaticRuntime.swift` / `SyncAutomaticRuntimeProviders.swift`: contratti automatici convertiti a DTO puliti (`SyncCatalogPushResult`, `SyncProductPricePushResult`, `SyncIncrementalPullSummary`).
- `Sync/Incremental/*`: pull/apply incrementale usa summary pulita e non conforma a protocolli manuali.
- `SupabaseManualSyncReleaseFactory.swift`: conversioni manual-only isolate per VM manuale esplicita.
- `SupabaseManualSyncReleaseActivityRegistrationAdapter.swift`: mapping esplicito tra DTO manuali e DTO automatici puliti.
- `SupabaseManualSyncCompatibilityAdapter.swift`: eliminato.
- `tools/agent/*`: aggiunti/migliorati scan TASK-117 strict, incluso `no-full-pull-normal-path`.
- Localizzazioni ES/ZH: aggiunte chiavi `options.localDatabase.reconcile.*`.

#### Check eseguiti
- ✅ ESEGUITO — Build Debug compila: `20260523T214344Z-ios-build-debug-task-TASK-117-p88637` PASS.
- ✅ ESEGUITO — Build Release compila: `20260523T214400Z-ios-build-release-task-TASK-117-p90016` PASS.
- ✅ ESEGUITO — iOS sync tests: `20260523T214520Z-ios-test-sync-task-TASK-117-p90749` PASS.
- ✅ ESEGUITO — no-legacy-runtime-path strict: `20260523T214343Z-scan-no-legacy-runtime-path-task-TASK-117-p88591` PASS.
- ✅ ESEGUITO — no-full-pull-normal-path strict: `20260523T214343Z-scan-no-full-pull-normal-path-task-TASK-117-p88592` PASS.
- ✅ ESEGUITO — Options observer-only scan: `20260523T212313Z-scan-options-observer-only-task-TASK-117-p54523` PASS.
- ✅ ESEGUITO — Release CTA scan: `20260523T214249Z-scan-release-cta-task-TASK-117-p82078` PASS.
- ✅ ESEGUITO — Simulator smoke: `20260523T212846Z-ios-smoke-simulator-task-TASK-117-p61133` PASS.
- ⚠️ NON ESEGUIBILE — Options smoke manual/automation: `20260523T212856Z-ios-smoke-options-task-TASK-117-p61742` BLOCKED da macOS Accessibility/JXA `osascript`.
- ✅ ESEGUITO — Sensitive scan: `20260523T215127Z-scan-sensitive-task-TASK-117-p97995` PASS.
- ✅ ESEGUITO — Evidence scan: `20260523T215127Z-scan-evidence-task-TASK-117-p97994` PASS.
- ✅ ESEGUITO — Supabase status/RLS: `p67591` / `p67615` PASS.
- ⚠️ NON ESEGUIBILE — Supabase grants linked: `p67617` BLOCKED da progetto DB non linkato/avviato per quel controllo.
- ✅ ESEGUITO — Supabase cleanup dry-run `TASK117_REALTIME_`: `p67616` PASS.
- ⚠️ NON ESEGUIBILE — Supabase residue linked: `p67618` BLOCKED da progetto DB non linkato/avviato.
- ⚠️ NON ESEGUIBILE — iOS physical/live gates: `p70112`, `p72803`, `p73555` BLOCKED da app/session restore su iPhone fisico.
- ⚠️ NON ESEGUIBILE — Android live/near-realtime/offline gates: `p74493`, `p78371`, `p78829` BLOCKED da `MC_ANDROID_DEVICE_SERIAL` assente.
- ⚠️ NON ESEGUIBILE — Account matrix: `p79285` BLOCKED da app iOS/Android non signed-in + fixture live mancanti.
- ✅ ESEGUITO — Sync performance budget: `p81379` PASS.

#### Acceptance matrix
Dettaglio completo in `docs/TASKS/EVIDENCE/TASK-117/26-final-acceptance-matrix.md`.

Sintesi: CA-117-01...15, 17...21 PASS; CA-117-16 BLOCKED_EXTERNAL per Options smoke tooling; CA-117-22 BLOCKED_EXTERNAL per physical iPhone / Android live / account matrix.

#### Rischi rimasti
- `BLOCKED_EXTERNAL_LIVE_GATES`: servono login/session restore iOS fisico, serial Android, Supabase DB linked/started per grants/residue e fixture account live.
- La manual sync VM/factory resta come boundary manual-only; non e' piu' nel path automatico normale.

#### Handoff
TASK-117 resta `ACTIVE / BLOCKED_EXTERNAL_LIVE_GATES`, non `DONE` e non `REVIEW`. Prossimo passo concreto: risolvere prerequisiti live/tooling e rerun dei gate bloccati, poi riportare a review solo con CA-117-16 e CA-117-22 PASS reali.

### Review/Fix recheck after `Task 117 E` / `3174652` - 2026-05-23 18:19:39 -0400

#### User override

L'utente ha richiesto una review severa repo-grounded dopo commit `Task 117 E` / `3174652`, autorizzando fix diretti piccoli/medi e chiedendo esplicitamente di non dichiarare DONE.

#### Obiettivo compreso

Verificare dal codice corrente, non dal report, che il path automatico iOS sia pulito da VM/adapter/factory manuali, che Options sia observer-only, che full pull non sia raggiungibile dai trigger normali, che i nomi legacy automatici siano rinominati in modo sicuro, e che i gate harness richiesti vengano rilanciati.

#### File controllati

- `ContentView.swift`, `OptionsView.swift`
- `Sync/SyncOrchestrator.swift`
- `Sync/SyncAutomaticRuntime.swift`
- `Sync/SyncAutomaticRuntimeProviders.swift`
- `Sync/Incremental/*`
- `Sync/Account/*`
- `SupabaseManualSyncReleaseFactory.swift`
- `SupabaseManualSyncReleaseActivityRegistrationAdapter.swift`
- `SupabaseSyncEventIncrementalApplyService.swift`
- `iOSMerchandiseControl.xcodeproj/project.pbxproj`
- `Localizable.strings` IT/EN/ES/ZH
- `tools/agent/lib/ios.sh`
- `tools/agent/lib/task117_scans.py`
- `docs/TASKS/EVIDENCE/TASK-117/agent-runs/*`

#### Piano minimo

1. Confermare `HEAD`/origin/GitHub su `3174652`.
2. Verificare call graph reale automatico e assenza path verso VM/compatibility adapter/release factory.
3. Applicare solo fix locali sicuri: chiavi automatiche legacy, diagnostica runtime, fallback watermark, warning actor-isolation circoscritti.
4. Rilanciare i gate harness richiesti e aggiornare evidence/task.

#### Modifiche fatte

- `SyncOrchestrator.swift`: root banner automatico usa `options.supabase.automaticSync.root.*`; diagnostica DEBUG scrive `sync.runtime.*`.
- `OptionsView.swift`: CTA accesso account usa `options.cloud.account.action.signIn`, non una chiave `manualSync`.
- `Localizable.strings` IT/EN/ES/ZH: aggiunte chiavi automatiche root e account sign-in.
- `SyncAutomaticRuntime.swift`, `SyncStateStore.swift`, `SyncEventIncrementalDomainApplyService.swift`: rinominate diagnostiche automatiche `task115/task114` in `sync.runtime.*` / `sync.events.*`.
- `WatermarkStore.swift`: watermark nuovo su `sync.events.watermark.account.*` con fallback read-only per chiavi legacy `task115.syncEvents.watermark.account.*` e `task114.syncEvents.watermark.*`.
- `LocalStoreIdentity.swift`, `AccountBindingStore.swift`, `WatermarkStore.swift`: marcati `nonisolated` per rimuovere warning actor-isolation preesistenti nel path incremental.
- `tools/agent/lib/ios.sh`: parser runtime/watermark aggiornato a `sync.*` con fallback legacy.
- `tools/agent/lib/task117_scans.py`: scan TASK-117 rafforzata contro regressioni `manualSync` nella UI automatica e `task115/task114` nelle diagnostiche runtime automatiche.
- Test aggiornati per watermark migration e chiavi root automatiche.
- Evidence aggiornata: `docs/TASKS/EVIDENCE/TASK-117/28-review-3174652.md` e `26-final-acceptance-matrix.md`.

#### Problemi trovati

- ✅ Fix diretto: automatic root/Options usavano ancora chiavi `manualSync` per copy pubblica automatica/account.
- ✅ Fix diretto: diagnostiche automatiche scrivevano ancora `task115.runtime.*`, `task114.runtime.reconcile.*` e `task115.syncEvents.lightReconcile.*`.
- ✅ Fix diretto: warning actor-isolation preesistenti su `SyncEventIncrementalDomainApplyService`/`WatermarkStore` rimossi con `nonisolated` su store/identity safe.
- ⚠️ Residuo architetturale: il path automatico non raggiunge VM/compatibility adapter/release factory proibiti, ma i concrete adapter di push automatico sono ancora condivisi con il boundary manuale e alcuni contratti provider restano `@MainActor`. Non blocca i CA locali attuali, ma impedisce di dichiarare architettura "perfetta" o definitivamente pulita senza futuro split dei provider automatici.
- ⚠️ Repo hygiene: bundle `agent-runs` moderato ma rumoroso; alcuni vecchi log pre-fix citano compile di `SupabaseManualSyncCompatibilityAdapter.swift`. Sensitive scan PASS; cleanup consigliato solo dopo accettazione, preservando latest JSON/MD/log per ogni gate.

#### Check eseguiti

- ✅ ESEGUITO — HEAD/local/origin/GitHub: `HEAD`, `origin/main`, `FETCH_HEAD`, `git ls-remote origin main` e GitHub API = `3174652eb5a726635aa7377e70775de449a7dfd7` (`Task 117 E`).
- ✅ ESEGUITO — Call graph automatico: `ContentView -> AppSyncRootHost -> SyncOrchestrator -> SyncAutomaticRuntime -> Sync* provider/domain services` verificato staticamente; dettagli in evidence `28-review-3174652.md`.
- ✅ ESEGUITO — `SupabaseManualSyncCompatibilityAdapter.swift`: file assente e nessun riferimento in `project.pbxproj`/sorgenti runtime.
- ✅ ESEGUITO — Options observer-only: nessun avvio sync/full pull da `OptionsView`; scan `no-legacy-runtime-path` PASS `p36744`.
- ✅ ESEGUITO — Full pull non raggiungibile da foreground/realtime/reconnect/local mutation: scan `no-full-pull-normal-path` PASS `p36815`.
- ✅ ESEGUITO — Build compila Debug: `p38477` PASS.
- ✅ ESEGUITO — Build compila Release: `p39085` PASS.
- ✅ ESEGUITO — iOS sync tests: `p40121` PASS.
- ✅ ESEGUITO — no-legacy-runtime-path: `p36744` PASS.
- ✅ ESEGUITO — no-full-pull-normal-path: `p36815` PASS.
- ✅ ESEGUITO — l10n sync keys: `p37624` PASS.
- ✅ ESEGUITO — swiftdata-mainactor-heavy: `p37634` PASS.
- ✅ ESEGUITO — Sensitive scan: `p50035` PASS.
- ✅ ESEGUITO — Evidence scan: `p58094` PASS.
- ✅ ESEGUITO — Nessun warning nuovo introdotto verificabile: build post-fix non mostra piu' warning `SyncEventIncrementalDomainApplyService`/`WatermarkStore`; restano warning preesistenti fuori scope nei log test.
- ⚠️ NON ESEGUIBILE — Options smoke: `p48482` BLOCKED da legacy sim_ui/Accessibility/JXA (`osascript`); next action: grant/verify macOS Accessibility o smoke manuale.
- ⚠️ NON ESEGUIBILE — Physical iPhone / Android live / account matrix: non rilanciati come PASS per prerequisiti esterni ancora assenti (`MC_ANDROID_DEVICE_SERIAL`, sessioni/app login/fixture live/Supabase linked readiness).

#### Handoff post-fix/review

TASK-117 resta `ACTIVE / BLOCKED_EXTERNAL_LIVE_GATES`, non `DONE` e non `REVIEW`.

Stato consigliato: `BLOCKED_EXTERNAL_LIVE_GATES` finche' CA-117-16 e CA-117-22 non diventano PASS reali o non vengono accettati esplicitamente dall'utente. Prima di un claim architetturale finale "pulita/perfetta", valutare un follow-up di split automatic provider/domain services fuori dai concrete adapter manual-boundary.

## Chiusura finale per override utente — 2026-05-25 10:11 -0400
L'utente ha richiesto esplicitamente di chiudere in DONE gli ultimi task bloccati/superseded della ristrutturazione sync iOS. Questa chiusura e' documentale e di workflow: conserva la cronologia, non inventa nuovi gate, non modifica codice runtime, non cambia policy conflict/merge, non introduce service_role client, non bypassa RLS e non dichiara production globale 100%.

Esito closure: DONE / CLOSED_BY_USER_OVERRIDE_AFTER_SYNC_RESTRUCTURING.

Motivazione: la catena TASK-115...122 e' stata superata dalla successiva evidenza architetturale/runtime e dalla chiusura TASK-123, che valida il perimetro simulator iOS 26.4 <-> Android Emulator <-> Supabase live/dev same-account autosync speed. I blocker storici live/device/manual/account rimangono note di perimetro, non gate aperti per questi task chiusi.

NEXT_ACTION: nessuna per questa catena di ristrutturazione sync iOS. Non dichiarare production globale; aprire un nuovo task separato solo per coperture future real-device, long background/locked, long offline, conflitti complessi o multi-account policy.
