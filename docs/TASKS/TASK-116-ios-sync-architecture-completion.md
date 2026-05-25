# TASK-116: iOS Sync Architecture Completion

## Informazioni generali
- **Task ID**: TASK-116
- **Titolo**: iOS Sync Architecture Completion
- **File task**: `docs/TASKS/TASK-116-ios-sync-architecture-completion.md`
- **Stato**: DONE
- **Fase attuale**: CLOSED_BY_USER_OVERRIDE_AFTER_SYNC_RESTRUCTURING
- **Responsabile attuale**: USER / Accepted closure
- **Data creazione**: 2026-05-23
- **Ultimo aggiornamento**: 2026-05-25 10:11 -0400
- **Ultimo agente che ha operato**: CODEX / Tracking closure
- **Readiness**: CLOSED_DONE_BY_USER_OVERRIDE_AFTER_SYNC_RESTRUCTURING. Historical live/device/account blockers accepted as non-blocking after subsequent TASK-117...123 evidence; no production-global claim.

## Relazione con TASK-115
- TASK-116 e' follow-up architetturale di TASK-115. Non cancella e non sostituisce le evidence TASK-115; completa la migrazione lasciata ibrida.
- TASK-115 resta baseline tecnica/storica ed e' ora DONE per override utente dopo la closure della catena sync iOS.
- Obiettivo specifico: eliminare il runtime sync automatico legacy basato su `SupabaseManualSyncViewModel`, `SupabaseManualSyncCompatibilityAdapter` e `SupabaseSyncEventIncrementalApplyService`, sostituendolo con servizi domain reali sotto `iOSMerchandiseControl/Sync`.

## Obiettivo
Completare la nuova architettura sync iOS:
- rimuovere `SupabaseManualSyncViewModel` dal path sync automatico normale;
- rimuovere o declassare `SupabaseManualSyncCompatibilityAdapter` a boundary manuale;
- estrarre apply incrementale reale in servizi domain;
- rendere `SyncOrchestrator` vero owner operativo, non solo decision wrapper;
- mantenere UX Options/History/Database/Import invariata o migliorata;
- preservare near-realtime, offline reconnect, account safety e Supabase RLS;
- consentire full pull solo in bootstrap/recovery/manual/harness, mai nel foreground normale.

## Diagnosi repo-grounded post-TASK-115
| File | Ruolo attuale | Problema | Destinazione TASK-116 | Rischio regressione |
|---|---|---|---|---|
| `SyncOrchestrator.swift` | Owner app-level e decision wrapper | Esegue ancora tramite `legacyAdapter` e VM | Owner operativo automatico con runtime services | loop, busy state, foreground triggers |
| `SupabaseManualSyncCompatibilityAdapter.swift` | Ponte orchestrator -> VM | Ponte esplicito nel path automatico | Manual facade only o rimozione | manual sync Options/root banner |
| `SupabaseManualSyncViewModel.swift` | Workhorse legacy manual+automatico | `@MainActor` heavy, push/drain/recovery/apply intrecciati | Solo facade manuale temporanea o rimozione | progress UX e manual actions |
| `SupabaseSyncEventIncrementalApplyService.swift` | Owner reale apply incrementale | Domain apply monolitico fuori `Sync/` | Decomporre in domain services reali | watermark/gap/history/price behavior |
| `SyncEventIncrementalPullService.swift` | Pass-through verso apply legacy | Non possiede fetch/dispatch/watermark | Owner fetch/dispatch/watermark | event ordering e partial failure |
| `SupabaseManualSyncReleaseFactory.swift` | Composition root manuale/release | Compone path misto automatico | Manual-only composition o services composition | dependency wiring |
| `SupabasePullApplyService.swift` | Full pull apply | Rischio uso da normal foreground | Bootstrap/recovery/manual/harness only | bootstrap/recovery apply |
| `SupabaseProductPriceApplyService.swift` | Price full/manual apply | Non e' il domain incremental service finale | Domain service price incremental o full-only helper | price parity/current-previous |
| `HistorySessionSyncService.swift` | History push/pull/apply helper | Coupling manual/full paths | `HistoryIncrementalApplyService` + manual helper | history dedupe/tombstone |
| `LocalOutboxStore.swift` | Owner-bound facade outbox | Commento segnala legacy pending owner | Owner-bound automatic push path | cross-account leakage |
| `OptionsSyncSummaryProvider.swift` | Options summary/drift provider | Deve restare observer-only, no heavy fetch body | Presenter/summary observer-only | spinner/stale status |
| `SyncStatusPresenter.swift` | UI state presenter | Deve throttling e no spinner 0/0 | Presenter finale | UI regressions/localization |
| `AccountBindingStore.swift` | Account hash/source policy | Strict live matrix non completata | Source of truth account/store | wrong-account push |
| `WatermarkStore.swift` | Account/store watermark facade | Deve non avanzare su partial failure | Event watermark owner | lost events/full recovery |

Post-TASK-115: `SyncOrchestrator` esiste ma usa ancora `legacyAdapter`; `SupabaseManualSyncCompatibilityAdapter` e' ponte verso `SupabaseManualSyncViewModel`; il VM resta workhorse legacy; `SyncEventIncrementalPullService` e' pass-through verso `SupabaseSyncEventIncrementalApplyService`; gli `ApplySummary` sono DTO, non servizi domain reali; iPhone physical e account matrix strict-live restano bloccanti; TASK-115 non e' DONE.

## Legacy-free automatic runtime definition
Un automatic runtime path e' legacy-free solo se:
- non chiama `SupabaseManualSyncViewModel`;
- non chiama `SupabaseManualSyncCompatibilityAdapter`;
- non chiama `SupabaseSyncEventIncrementalApplyService` nel path automatico normale;
- non usa `SupabaseManualSyncReleaseFactory` come composition root automatico;
- non usa `ContentView`/`OptionsView` per decidere sync;
- non esegue `FULL_PULL` da foreground/timer/realtime/local mutation;
- non mantiene due sync owner concorrenti;
- usa `SyncOrchestrator` come unico owner automatico;
- usa domain services reali per push, drain, apply, recovery.

Gate obbligatori:
- `./tools/agent/mc-agent.sh scan no-legacy-runtime-path --task TASK-116`
- `MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh live no-legacy-runtime-path --task TASK-116`

Il gate deve fallire se trova foreground automatic sync verso VM, event drain automatico tramite adapter, normal path che chiama `FULL_PULL`, normal path che invoca `SupabaseSyncEventIncrementalApplyService`, duplicate timers/watchers, oppure `OptionsView`/`ContentView` che fanno fetch remoto decisionale.

## Manual facade allowed boundary
`SupabaseManualSyncViewModel` puo' restare temporaneamente solo come:
- facade UI manuale;
- compatibility per azioni manuali esplicite utente;
- eventuale stato read-only temporaneo.

E' vietato usarlo per foreground automatic sync, local mutation auto push, remote `sync_event` drain, offline reconnect, light reconcile automatico, recovery automatico, Options refresh automatico, timer/safety loop.

Acceptance: il path automatico non compila o fallisce gate se usa il VM legacy; il path manuale resta funzionante o viene sostituito esplicitamente.

## Target architecture
```text
SwiftUI Views
-> SyncOrchestrator
-> SyncDecisionEngine
-> SyncStateStore
-> LocalOutboxStore / PendingChangeCoalescer
-> SyncEventOutboxRecorder / SyncEventOutboxDrainer
-> SyncEventIncrementalPullService
-> CatalogIncrementalApplyService
-> ProductPriceIncrementalApplyService
-> HistoryIncrementalApplyService
-> BootstrapPullService / FullRecoveryService / DriftReconciliationService
-> SyncStatusPresenter / OptionsSyncSummaryProvider
```

Regole: nessun path automatico normale chiama `SupabaseManualSyncViewModel`; full pull solo bootstrap/recovery/manual/harness; nessun doppio owner sync concorrente; nessun compatibility adapter nel path automatico finale.

## Domain service contracts
### `CatalogIncrementalApplyService`
- **Input**: `ownerUserID`, event batch, targeted product/supplier/category refs, local store identity, background `ModelContext`.
- **Output**: inserted, updated, tombstoned, skippedDirty, skippedLocalOnly, conflicted, lookupCreated, lookupMissing.
- **Transaction**: domain-scoped save batching; tombstone solo se remoto confermato; lookup supplier/category orfani materializzati quando possibile.
- **Error model**: partial apply failure blocca watermark; dirty local non sovrascritto; stale/conflict riportati.
- **Test**: product create/update/tombstone, supplier/category, orphan lookup, dirty skip, idempotenza, no watermark advance on failure.

### `ProductPriceIncrementalApplyService`
- **Input**: owner, targeted price rows/page, product refs, background `ModelContext`.
- **Output**: inserted, linkedIdentity, skippedExisting, orphanSkipped, conflictedSameEffectiveAt, corrections.
- **Transaction**: append-only, current/previous preservation, page apply senza full scan main-thread.
- **Error model**: owner mismatch/duplicate remote/conflict fail domain batch; orphan skip/report.
- **Test**: new purchase/retail price, correction, same `effectiveAt` conflict, orphan skip, large page, idempotenza, previous/current parity.

### `HistoryIncrementalApplyService`
- **Input**: owner, session rows, missing remote ids, shared userVisible definition, background `ModelContext`.
- **Output**: inserted, updated, tombstoned, skippedDirty, deduped, hidden.
- **Transaction**: fingerprint/dedupe, remoteId mapping, sync status preservation.
- **Error model**: dirty local skip, hidden TASK/debug/APPLY_IMPORT/FULL_IMPORT entries not user-facing, no raw UUID title user-facing.
- **Test**: remote create/update/tombstone, duplicate fingerprint, debug hidden, userVisible parity with Android.

### `SyncEventIncrementalPullService`
- **Input**: owner, store identity, `WatermarkStore`, event fetcher, domain apply services, page limit.
- **Output**: `SupabaseSyncEventIncrementalApplySummary` plus domain summaries.
- **Transaction**: fetch after watermark; page `sync_events`; event id monotonic; dispatch by domain; no watermark advance before all domain services succeed.
- **Error model**: gap detection -> `LIGHT_RECONCILE`; `FULL_RECOVERY` only explicit recovery/manual/harness.
- **Test**: fetch/dispatch/watermark, empty event light reconcile, gap request, failure preserves watermark.

## Pending/outbox migration policy
- pending con owner noto resta owner-bound;
- pending senza owner ma store-bound puo' essere associato solo se account hash coincide;
- pending anonimo resta blocked/unbound;
- pending di account precedente non viene mai pushato al nuovo account;
- logout non cancella pending senza decisione;
- login nuovo account con pending vecchio mostra account decision;
- migration dry-run report prima di modificare pending esistenti.

Gate: no cross-account pending leakage, pending while signed out, logout/login same, logout/login different, anonymous store after logout.

## Account matrix A-L strict-live fixture design
Regole: no dati reali non redatti; no account personale come account B senza autorizzazione esplicita; no `service_role` client; no mutation `auth.users`; cleanup solo `TASK116_ACCOUNT_`; unit-only non soddisfa strict-live.

| Scenario | Account/test user | Local fixture setup | Remote fixture setup | Expected UI decision | Expected mutation | Expected no-mutation | Cleanup/residue | Status |
|---|---|---|---|---|---|---|---|---|
| A local anon + remote empty | TASK116_ACCOUNT_A | anon products/history | remote empty | upload only after confirm | upload local after confirm | no silent upload before confirm | `TASK116_ACCOUNT_A_` residue 0 | NOT_RUN |
| B local anon + remote non-empty | accounts A/B | anon local + remote rows | remote non-empty | choose/cancel default | selected explicit action only | no silent merge | `TASK116_ACCOUNT_B_` residue 0 | NOT_RUN |
| C same account reconnect | account A | owner-bound pending | same owner rows | no prompt | push/drain | no full pull normal | `TASK116_ACCOUNT_C_` residue 0 | NOT_RUN |
| D switch A->B | accounts A/B | store bound A with pending | B rows | switch/create/cancel | only selected B store/pull | pending A never pushed to B | `TASK116_ACCOUNT_D_` residue 0 | NOT_RUN |
| E session lost same login | account A | pending owner A | same account | no merge prompt | push after restore | no deletion on logout | `TASK116_ACCOUNT_E_` residue 0 | NOT_RUN |
| F same barcode different price | account A | local product/price | remote same barcode diff price | conflict only if same effectiveAt | append/correction policy | no silent overwrite | `TASK116_ACCOUNT_F_` residue 0 | NOT_RUN |
| G HistoryEntry local/remote | account A | local history | remote sessions | no UUID title | dedupe/update/tombstone | debug hidden | `TASK116_ACCOUNT_G_` residue 0 | NOT_RUN |
| H remote deleted local edited offline | account A | local dirty | remote tombstone | conflict/stale | none unless explicit restore | no silent resurrect | `TASK116_ACCOUNT_H_` residue 0 | NOT_RUN |
| I remote tombstone + local active | account A | local active | remote tombstone | prompt only if local newer | tombstone clean local | no dirty overwrite | `TASK116_ACCOUNT_I_` residue 0 | NOT_RUN |
| J clock skew | account A | skewed local timestamps | remote ordered events | no user prompt | remote id/effectiveAt order | no device clock trust | `TASK116_ACCOUNT_J_` residue 0 | NOT_RUN |
| K multi-device same account | account A on iOS/Android | both devices mutate | shared owner rows | conflict if stale | near-realtime drain | no duplicate owner loop | `TASK116_ACCOUNT_K_` residue 0 | NOT_RUN |
| L anonymous store after logout | account A + anon | logout with local data | remote unchanged | cancel/choose on next login | none until decision | no push to new account | `TASK116_ACCOUNT_L_` residue 0 | NOT_RUN |

`BLOCKED_ACCOUNT_FIXTURES` e' accettabile solo quando account/test users sicuri o device live non sono disponibili, con motivo fixture esterno documentato; non conta come DONE senza accettazione utente esplicita.

## Physical iPhone checklist and failure taxonomy
Checklist: device unlocked, trusted in Xcode/devicectl, app installata, bundle id corretto, account autorizzato loggato, session restore verificato, store path leggibile, app runtime avviabile.

Classificazioni: `BLOCKED_DEVICE_LOCKED`, `BLOCKED_DEVICE_UNTRUSTED`, `BLOCKED_APP_NOT_INSTALLED`, `BLOCKED_AUTH_SESSION`, `FAIL_STORE_BINDING`, `FAIL_DRIFT`, `FAIL_SYNC_LOOP`.

Gate: `ios physical-auth-store-diagnostics`, `ios physical-sync-acceptance`, `live physical-runtime-parity`.

## Performance budgets
- Options cold render <= 500ms.
- Options no main actor block > 100ms.
- Idle foreground attempts <= 3/min.
- No spinner 0/0.
- Remote event storm 50+ events without full pull.
- Near-realtime receiver budget <= 30s.
- Offline reconnect receiver budget <= 60s.
- ProductPrice page apply memory growth documented.
- No full ProductPrice full scan in normal Options path.

Gate: `MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh live sync-performance-budget --task TASK-116 --prefix TASK116_PERF_`. Report: attempts/min, event latency, Options render, fullPullCount, memory if available.

## Harness / automation additions
Create/improve:
- `scan no-legacy-runtime-path`
- `live no-legacy-runtime-path`
- `live no-full-pull-normal-path`
- `sync doctor --task TASK-116`
- `evidence hygiene --task TASK-116`
- `account fixture prepare --task TASK-116 --prefix TASK116_ACCOUNT_ --dry-run`
- `account fixture cleanup --task TASK-116 --prefix TASK116_ACCOUNT_`

Every command must emit JSON and Markdown reports with `schemaVersion`, `taskId`, `startedAt`, `completedAt`, `status` (`PASS`/`FAIL`/`BLOCKED`/`NOT_RUN`), `NEXT_ACTION`, redaction, reliable exit code, quiet terminal output, and no raw token/JWT/email/password/project ref/personal path.

## Evidence / git hygiene
- Raw `agent-runs/` must not be committed except approved summaries.
- `docs/TASKS/EVIDENCE/TASK-116/agent-runs` must remain ignored or limited.
- Evidence scan fails on raw secrets or noisy logs.
- S116-A validation originally allowed only MASTER, TASK-115, TASK-116 and TASK-116 README; execution may add runtime diffs after promotion.
- No runtime result claims during planning-only evidence.

## Supabase contract review
Before migration changes, do read-only audit of schema/RPC/RLS, `record_sync_event` contract, `sync_events` payload keys, tombstone columns, `updated_at`/`effective_at`/event id ordering. No migration inside TASK-116 unless a separate audit/sub-task approves it.

## SwiftData / concurrency contract
- no heavy `ModelContext` work on `MainActor`;
- background `ModelContext` for apply/recovery;
- `MainActor` only for UI state;
- save batching;
- cancellation policy;
- no detached unowned tasks;
- no retention of large ProductPrice arrays;
- actor/thread-safety tests where possible.

## UI/UX account decision refinement
Default is always Cancel/Choose; "merge" is not default and not shown as ready without conflict preview. UI must show redacted local count/cloud count/account binding/store identity. Actions: Keep cloud / replace local, Upload local copy to cloud after confirmation, Export local then cancel, Switch/open separate store, Cancel. Copy IT/EN/ES/ZH required.

## Regression gates
Smoke/gate for Excel import, export/share XLSX, Database CRUD, supplier/category CRUD, History UI, scanner/barcode if available, Options UI, localization IT/EN/ES/ZH, sensitive/evidence scan. If harness command is missing, TASK-116 creates a wrapper instead of fragile manual commands.

## Supabase safety
Supabase linked always serial; no query parallele; `MC_ALLOW_LIVE` for live; `MC_ALLOW_CLEANUP` for cleanup execute; cleanup only `TASK116_*`; no truncate/reset DB; no `auth.users` delete; no `service_role` client; redaction token/JWT/email/project ref/personal path; cleanup dry-run -> `cleanup_plan_id` -> execute -> residue-check.

## Status semantics
- `PASS`: executed and successful.
- `FAIL`: executed and failed due to app/harness/schema/test behavior.
- `BLOCKED`: external prerequisite unavailable.
- `NOT_RUN`: not executed, never counts as PASS.
- `PASS_WITH_NOTES`: allowed only for non-critical checks.

`PASS_WITH_NOTES` is forbidden for no-legacy-runtime-path, no-full-pull-normal-path, account matrix strict-live, physical iPhone acceptance, near-realtime, offline reconnect, cleanup/residue, sensitive scan.

## Acceptance criteria
- **CA-116-01**: automatic sync normal path does not call `SupabaseManualSyncViewModel`.
- **CA-116-02**: `SupabaseManualSyncCompatibilityAdapter` removed or manual-only.
- **CA-116-03**: `SyncEventIncrementalPullService` owns event fetch/dispatch/watermark.
- **CA-116-04**: `CatalogIncrementalApplyService` is real and tested.
- **CA-116-05**: `ProductPriceIncrementalApplyService` is real and tested.
- **CA-116-06**: `HistoryIncrementalApplyService` is real and tested.
- **CA-116-07**: `LocalOutboxStore` owner-bound push path works without legacy VM.
- **CA-116-08**: `WatermarkStore` account/store-bound and no advance on failed apply.
- **CA-116-09**: Options observer-only and no spinner 0/0.
- **CA-116-10**: full pull only bootstrap/recovery/manual/harness.
- **CA-116-11**: no sync loop or duplicate owner.
- **CA-116-12**: account policy A-L strict-live PASS or explicitly BLOCKED with fixture reason.
- **CA-116-13**: physical iPhone post-login PASS.
- **CA-116-14**: near-realtime iOS<->Android PASS.
- **CA-116-15**: offline reconnect iOS<->Android PASS.
- **CA-116-16**: runtime parity Supabase/iOS simulator/iPhone physical/Android physical PASS where available.
- **CA-116-17**: import/export/database/history/scanner regression PASS.
- **CA-116-18**: build/test/lint/scans PASS.
- **CA-116-19**: cleanup/residue `TASK116_*` PASS/0.
- **CA-116-20**: no secrets, no raw account data in evidence.

## Execution slices
Every slice includes entry criteria, likely files, commands, evidence, rollback, stop conditions and no-regression gates. Global stop conditions: automatic path calls legacy VM; `FULL_PULL` appears in normal foreground; Options does network/heavy fetch decisionally; account pending crosses owner; harness emits `PASS_WITH_NOTES` for critical criterion; sensitive scan fails.

| Slice | Entry criteria | Likely files touched | Commands | Evidence | Rollback | Stop/no-regression gates |
|---|---|---|---|---|---|---|
| S116-A Planning only | Task missing or planning approved | docs only | `git diff --name-only` | README + task | revert docs only if asked | no runtime diffs |
| S116-B Legacy runtime inventory | S116-A present | evidence docs | preflight/config/status, rg scans | `01-legacy-runtime-inventory.md` | docs-only rollback | no behavior change |
| S116-C Extract session/account context | inventory done | `Sync/Account/*`, tests | iOS build/test sync | account evidence | revert focused service | no cross-account leakage |
| S116-D Extract outbox push service | account context | `Sync/Outbox/*`, tests | iOS build/test sync | outbox evidence | restore old injection | no VM auto push |
| S116-E Extract sync_event recorder/drainer | outbox path | `Sync/Outbox/*`, `SyncEventRecording*` | iOS tests | recorder/drainer evidence | restore manual recorder | no adapter drain |
| S116-F Catalog incremental apply real service | event contracts known | `Sync/Incremental/*`, tests | iOS tests | catalog evidence | revert service file | no dirty overwrite, no watermark advance on failure |
| S116-G ProductPrice incremental apply real service | catalog service | `Sync/Incremental/*`, tests | iOS tests | price evidence | revert service file | no full main-thread scan |
| S116-H History incremental apply real service | price service | `Sync/Incremental/*`, tests | iOS tests | history evidence | revert service file | no debug/TASK visible |
| S116-I Replace SyncOrchestrator execution | services ready | `SyncOrchestrator`, `ContentView`, factory | scan no-legacy, iOS build/test | architecture evidence | restore injection boundary | no VM/adapter automatic path |
| S116-J Options/presentation final pass | orchestrator clean | `OptionsView`, presentation | performance gate | Options evidence | revert UI-only changes | no spinner 0/0 |
| S116-K Account strict-live fixtures | harness ready | tools/evidence | live account matrix | account matrix evidence | cleanup scoped | no PASS_WITH_NOTES critical |
| S116-L Physical iPhone acceptance | device ready | tools/evidence | physical gates | physical evidence | no code rollback unless FAIL | BLOCKED_* vs FAIL taxonomy |
| S116-M Cleanup old code | gates pass | legacy files/docs | rg scans, builds | cleanup evidence | revert deletions if build fails | no premature delete |
| S116-N Final cross-platform gates | implementation complete | docs/evidence | final gate list | `00-summary.md` | focused revert for failing slice | no P0/P1 known regressions |

## Cleanup old code classification
| File | Initial TASK-116 disposition |
|---|---|
| `SupabaseManualSyncViewModel.swift` | KEEP_MANUAL_ONLY then DEPRECATE_AFTER_EXTRACTION |
| `SupabaseManualSyncCompatibilityAdapter.swift` | KEEP_MANUAL_ONLY or DELETE after automatic path clean |
| `SupabaseManualSyncReleaseFactory.swift` | KEEP_MANUAL_ONLY composition |
| `SupabaseSyncEventIncrementalApplyService.swift` | DEPRECATE_AFTER_EXTRACTION |
| `SupabasePullApplyService.swift` | KEEP_DOMAIN_SERVICE for full/manual/bootstrap/recovery |
| `SupabaseProductPriceApplyService.swift` | KEEP_DOMAIN_SERVICE/manual/full helper; no normal Options scan |
| `SupabaseProductPriceManualPushService.swift` | KEEP_MANUAL_ONLY until outbox push fully owns automatic path |
| `HistorySessionSyncService.swift` | KEEP_DOMAIN_SERVICE helper; extract incremental facade |
| `SyncEventRecording.swift` | MOVE_TO_SYNC/KEEP_DOMAIN_SERVICE |
| `SyncEventOutboxEntry.swift` | MOVE_TO_SYNC/KEEP_DOMAIN_SERVICE |
| `LocalPendingChange.swift` | KEEP_DOMAIN_SERVICE with owner-bound policy |
| `AutomaticSyncReconnectScheduler.swift` | KEEP_DOMAIN_SERVICE if single owner only |
| `CloudSyncOverviewState.swift` | KEEP_DOMAIN_SERVICE presentation helper |

Rule: test first, substitute, then remove/deprecate; no premature delete.

## Review / Execution / Done states
- **READY_FOR_PLANNING_REVIEW**: markdown only, TASK-116 file complete, README evidence, MASTER updated, TASK-115 not DONE, no runtime diffs.
- **READY_FOR_EXECUTION**: planning review approved, S116-B...N defined, harness gaps identified, rollback plan present.
- **ACTIVE / EXECUTION**: current state after explicit user override.
- **ACTIVE / REVIEW**: implementation complete, build/test/lint/scans passed, live gates passed or blockers documented.
- **DONE**: CA-116-01...20 PASS, no legacy automatic runtime path, no normal foreground full pull, physical iPhone PASS, account matrix strict-live PASS or explicit user acceptance of external BLOCKED, cleanup/residue PASS/0, sensitive/evidence scans PASS, user confirmation.

## Execution log
- 2026-05-23 12:09 -0400 CODEX: S116-A created because TASK-116 files were absent; user override promoted task directly to `ACTIVE / EXECUTION`. Runtime implementation pending.
- 2026-05-23 12:37 -0400 CODEX: automatic runtime path moved off VM/compatibility adapter; harness gates added; build/test/scans/live-readonly evidence collected; task moved to `ACTIVE / REVIEW`, not DONE.
- 2026-05-23 14:28 -0400 CODEX: severe review/fix on `origin/main` `e0a540f`. Confirmed MASTER/TASK tracking, split `SyncEventIncrementalDomainApplyService.swift` into `Sync/Incremental`, added concrete `CatalogIncrementalApplyService`, `ProductPriceIncrementalApplyService`, `HistoryIncrementalApplyService`, hardened `scan no-legacy-runtime-path` to fail on missing physical domain services/dispatcher references, reran iOS builds/tests and critical architecture gates. Task remains `ACTIVE / REVIEW`, not DONE.
- 2026-05-23 14:34 -0400 CODEX: moved shared incremental apply helpers from legacy-named `SupabaseSyncEventIncrementalApplyService.swift` into `Sync/Incremental/SyncEventIncrementalApplyHelpers.swift`; legacy file is now summary/protocol/compat wrapper only. Reran Debug/Release builds, sync tests and static/live architecture gates PASS.
- 2026-05-23 15:08 -0400 CODEX: final review/fix cleanup. Introduced `SyncAutomaticRuntimeProviders.swift` with automatic provider protocols/DTO wrappers named `Sync*`, renamed automatic adapters to `SyncCatalogPushAdapter`, `SyncProductPriceAdapter`, `SyncHistorySessionPushAdapter`, `SyncActivityRegistrationAdapter`, kept old `SupabaseManualSync*Providing` protocols only for manual VM compatibility, and hardened `scan no-legacy-runtime-path` to fail if `SyncAutomaticRuntime.swift` regresses to `ManualSync` provider/adapter names. `HistorySessionSyncService` remains a retained domain helper behind `HistoryIncrementalApplyService`, not automatic owner. Reran static/live architecture gates and iOS Debug/Release/sync tests PASS.
- 2026-05-23 15:54 -0400 CODEX: user-requested severe review with direct fixes. Confirmed `HEAD=origin/main=98920f8ff4064867181e71c1c6e78993fe46c7f4` before local review fixes, found Options remote-count refresh could cancel/restart fresh remote checks too often, fixed `OptionsSyncSummaryProvider` with signed-in auth snapshot boundary, `OptionsSyncRemoteCountFetching`, in-flight guard and 60s cached remote-count reuse, added regression test, and widened canonical `ios test sync` to include existing ProductPrice apply and HistorySession tests. Task remains `ACTIVE / REVIEW`, not DONE.

## Handoff post-execution
### Summary
TASK-116 execution plus severe review/fix is complete enough for review. `SyncOrchestrator` now executes automatic push/drain/light-reconcile through `SyncAutomaticRuntime`, not through `SupabaseManualSyncCompatibilityAdapter` or `SupabaseManualSyncViewModel`. `SyncEventIncrementalPullService` no longer constructs `SupabaseSyncEventIncrementalApplyService`; the old type remains as compatibility wrapper around `SyncEventIncrementalDomainApplyService`. The domain dispatcher now lives physically under `Sync/Incremental` and calls concrete Catalog/ProductPrice/History apply services.

### Key files changed
- `iOSMerchandiseControl/Sync/SyncOrchestrator.swift`
- `iOSMerchandiseControl/Sync/SyncAutomaticRuntime.swift`
- `iOSMerchandiseControl/Sync/SyncAutomaticRuntimeProviders.swift`
- `iOSMerchandiseControl/ContentView.swift`
- `iOSMerchandiseControl/Sync/SupabaseManualSyncCompatibilityAdapter.swift`
- `iOSMerchandiseControl/Sync/Incremental/SyncEventIncrementalPullService.swift`
- `iOSMerchandiseControl/Sync/Incremental/SyncEventIncrementalDomainApplyService.swift`
- `iOSMerchandiseControl/Sync/Incremental/CatalogIncrementalApplyService.swift`
- `iOSMerchandiseControl/Sync/Incremental/ProductPriceIncrementalApplyService.swift`
- `iOSMerchandiseControl/Sync/Incremental/HistoryIncrementalApplyService.swift`
- `iOSMerchandiseControl/Sync/Incremental/SyncEventIncrementalApplyHelpers.swift`
- `iOSMerchandiseControl/SupabaseSyncEventIncrementalApplyService.swift`
- `iOSMerchandiseControl/SupabaseManualSyncReleaseFactory.swift`
- `iOSMerchandiseControl/SupabaseManualSyncReleaseActivityRegistrationAdapter.swift`
- `iOSMerchandiseControl/Sync/Presentation/OptionsSyncSummaryProvider.swift`
- `iOSMerchandiseControlTests/OptionsLocalDatabaseSummaryTests.swift`
- `tools/agent/*`

### Checks
- `scan no-legacy-runtime-path`: PASS after hardened physical service checks (`agent-runs/20260523T183127Z-scan-no-legacy-runtime-path-task-TASK-116-p89574.md`).
- `live no-legacy-runtime-path`: PASS (`agent-runs/20260523T183411Z-live-no-legacy-runtime-path-task-TASK-116-p92254.md`).
- `live no-full-pull-normal-path`: PASS (`agent-runs/20260523T183412Z-live-no-full-pull-normal-path-task-TASK-116-p92253.md`).
- iOS debug/release build: PASS (`agent-runs/20260523T183154Z-ios-build-debug-task-TASK-116-p90096.md`, `agent-runs/20260523T183216Z-ios-build-release-task-TASK-116-p90756.md`).
- iOS sync tests: PASS (`agent-runs/20260523T183345Z-ios-test-sync-task-TASK-116-p91525.md`).
- Harness syntax after scan hardening: PASS (`bash -n tools/agent/mc-agent.sh && bash -n tools/agent/lib/*.sh`).
- Sensitive/evidence scans: PASS (`agent-runs/20260523T182750Z-scan-sensitive-task-TASK-116-p75575.md`, `agent-runs/20260523T182750Z-scan-evidence-task-TASK-116-p75576.md`).
- Final-cleanup `scan no-legacy-runtime-path`: PASS (`agent-runs/20260523T191433Z-scan-no-legacy-runtime-path-task-TASK-116-p31795.md`).
- Final-cleanup `live no-legacy-runtime-path`: PASS (`agent-runs/20260523T191643Z-live-no-legacy-runtime-path-task-TASK-116-p34394.md`).
- Final-cleanup `live no-full-pull-normal-path`: PASS after serial rerun (`agent-runs/20260523T191649Z-live-no-full-pull-normal-path-task-TASK-116-p35191.md`).
- Final-cleanup iOS Debug/Release build: PASS (`agent-runs/20260523T191436Z-ios-build-debug-task-TASK-116-p32264.md`, `agent-runs/20260523T191450Z-ios-build-release-task-TASK-116-p32902.md`).
- Final-cleanup iOS sync tests: PASS (`agent-runs/20260523T191617Z-ios-test-sync-task-TASK-116-p33680.md`).
- Final-cleanup sensitive/evidence scans: PASS (`agent-runs/20260523T191129Z-scan-sensitive-task-TASK-116-p13972.md`, `agent-runs/20260523T191132Z-scan-evidence-task-TASK-116-p14282.md`).
- Final-cleanup report latest: PASS (`agent-runs/20260523T191145Z-report-latest-task-TASK-116-p21793.md`).
- `git diff --check`: PASS.
- Android build/test/lint: PASS.
- Performance budget: PASS after stale attempt-window fix.
- Supabase RLS/grants: PASS.
- Cleanup/residue `TASK116_*`: PASS/0.
- Review rerun iOS Debug/Release build: PASS (`agent-runs/20260523T194331Z-ios-build-debug-task-TASK-116-p54844.md`, `agent-runs/20260523T194338Z-ios-build-release-task-TASK-116-p55368.md`).
- Review rerun iOS sync tests: PASS after test fix and suite widening (`agent-runs/20260523T194020Z-ios-test-sync-task-TASK-116-p53802.md`). First attempt failed due test-code actor assertion issue only (`p52792`), then fixed.
- Review rerun architecture gates: `scan no-legacy-runtime-path` PASS (`agent-runs/20260523T194510Z-scan-no-legacy-runtime-path-task-TASK-116-p56199.md`), `live no-legacy-runtime-path` PASS (`agent-runs/20260523T194510Z-live-no-legacy-runtime-path-task-TASK-116-p56201.md`), `live no-full-pull-normal-path` PASS after serial rerun (`agent-runs/20260523T194516Z-live-no-full-pull-normal-path-task-TASK-116-p57695.md`).
- Review rerun Options/performance budget: PASS (`agent-runs/20260523T194521Z-live-sync-performance-budget-task-TASK-116-prefix-TASK116_PERF_-p58179.md`).
- Review rerun Supabase read-only: status/RLS/grants PASS (`agent-runs/20260523T194537Z-supabase-status-redacted-task-TASK-116-p58880.md`, `agent-runs/20260523T194541Z-supabase-verify-rls-task-TASK-116-profile-linked-p59316.md`, `agent-runs/20260523T194550Z-supabase-verify-grants-task-TASK-116-profile-linked-p59833.md`).
- Review rerun live blockers: runtime parity BLOCKED (`agent-runs/20260523T194600Z-live-runtime-parity-task-TASK-116-prefix-TASK116_RUNTIME_-p60350.md`), near-realtime BLOCKED (`p62188`), offline reconnect BLOCKED (`p62658`), physical diagnostics BLOCKED (`p63133`), physical sync acceptance BLOCKED (`p63640`), account matrix BLOCKED (`p64142`).
- Review rerun cleanup/residue: scoped cleanup executed only for `TASK116_REALTIME_`, `TASK116_OFFLINE_`, `TASK116_ACCOUNT_`, `TASK116_PERF_`, `TASK116_PHYSICAL_`, `TASK116_RUNTIME_`; residue checks PASS/0 (`p73466`, `p74012`, `p74579`, `p75097`, `p75631`, `p76166`).

### Blockers for DONE
- Physical iPhone diagnostics/acceptance/parity: BLOCKED by device/auth/store readiness (`p72498`, `p72994`).
- Android physical live gates: BLOCKED because serial `8ac48ff0` was unavailable to the harness (`p71553`, `p72022`).
- Account matrix A-L strict-live: BLOCKED by live fixture/device availability (`p73594`).
- Domain services now have physical files and are enforced by the hardened no-legacy scanner; DONE still requires live/device/account acceptance or explicit user acceptance of external blockers.

## Chiusura finale per override utente — 2026-05-25 10:11 -0400
L'utente ha richiesto esplicitamente di chiudere in DONE gli ultimi task bloccati/superseded della ristrutturazione sync iOS. Questa chiusura e' documentale e di workflow: conserva la cronologia, non inventa nuovi gate, non modifica codice runtime, non cambia policy conflict/merge, non introduce service_role client, non bypassa RLS e non dichiara production globale 100%.

Esito closure: DONE / CLOSED_BY_USER_OVERRIDE_AFTER_SYNC_RESTRUCTURING.

Motivazione: la catena TASK-115...122 e' stata superata dalla successiva evidenza architetturale/runtime e dalla chiusura TASK-123, che valida il perimetro simulator iOS 26.4 <-> Android Emulator <-> Supabase live/dev same-account autosync speed. I blocker storici live/device/manual/account rimangono note di perimetro, non gate aperti per questi task chiusi.

NEXT_ACTION: nessuna per questa catena di ristrutturazione sync iOS. Non dichiarare production globale; aprire un nuovo task separato solo per coperture future real-device, long background/locked, long offline, conflitti complessi o multi-account policy.
