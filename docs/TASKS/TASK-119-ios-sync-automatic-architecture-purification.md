# TASK-119: iOS Sync Automatic Architecture Purification and Dead-Code Cleanup

## Informazioni generali
- **Task ID**: TASK-119
- **Titolo**: iOS Sync Automatic Architecture Purification and Dead-Code Cleanup
- **File task**: `docs/TASKS/TASK-119-ios-sync-automatic-architecture-purification.md`
- **Evidence dir**: `docs/TASKS/EVIDENCE/TASK-119/`
- **Stato**: ACTIVE
- **Fase attuale**: REVIEW — EXECUTION_COMPLETE_LOCAL_GATES_PASS / HANDOFF_TO_CLAUDE
- **Responsabile attuale**: CLAUDE / Reviewer
- **Data creazione**: 2026-05-24
- **Ultimo aggiornamento**: 2026-05-24
- **Ultimo agente che ha operato**: CODEX / Executor
- **Readiness**: LOCAL_REVIEW_READY. HEAD/tracking mismatch resolved, TASK-119 harness/baseline pushed, progressive Swift refactor completed locally, critical local gates PASS. Not DONE; live gates were not run because no explicit live approval was requested for this refactor.
- **Tipo task**: cleanup/refactor architetturale, non feature task.
- **User override registrato**: l'utente ha chiesto esplicitamente a Codex di creare tracking PLANNING nonostante `AGENTS.md` definisca Codex come executor/fixer. Override limitato a markdown/tracking/evidence README; nessuna modifica Swift/Kotlin/SQL, nessun build/test runtime, nessun live Supabase, nessun cleanup.

## Obiettivo
Completare la purificazione finale dell'architettura sync automatica iOS post-TASK-118, rendendo il path automatico domain-first, leggibile, non-UI dove possibile, isolato dal boundary manuale, verificabile con harness TASK-119 e privo di codice legacy/stale solo dopo audit referenziale.

TASK-119 non aggiunge una nuova feature utente: prepara e governa un refactor/cleanup architetturale con acceptance criteria, harness, evidence e safety gate sufficienti per evitare regressioni funzionali.

## Stato corrente post-TASK-118
- Snapshot storico noto TASK-118: `3bcb58f9bb921e92b31f2c89de622ffbd6d11694` (`Task 118`).
- Verifica planning locale 2026-05-24: `HEAD`, `origin/main`, `git ls-remote origin refs/heads/main` e GitHub API `branches/main` risultano su `3bcb58f9bb921e92b31f2c89de622ffbd6d11694`.
- Il commit TASK-118 e' solo snapshot storico. La verita' operativa futura non deve essere hardcoded e deve essere verificata dinamicamente con:

```bash
./tools/agent/mc-agent.sh git head-consistency --task TASK-119
./tools/agent/mc-agent.sh preflight --require-head-consistency --task TASK-119
```

- TASK-118 resta `ACTIVE / REVIEW`, non DONE.
- TASK-117 resta non DONE.
- TASK-116 resta non DONE.
- Le evidence TASK-118 aiutano il planning, ma TASK-119 non deve assumere che restino valide se `HEAD` cambia.
- Nota importante: `docs/TASKS/EVIDENCE/TASK-118/01-execution-audit.md` risulta storico/pre-Swift rispetto al commit TASK-118 finale; usarlo solo come contesto, non come fonte corrente di verita'.

## Problema da risolvere
TASK-118 ha portato il runtime automatico verso un path domain-first e ha corretto contaminazioni gravi con il boundary manuale. Rimangono pero' rischi architetturali:

- `AutomaticPushServices.swift` e' ancora un file monolitico multi-dominio.
- Runtime automatico, orchestrator e factory restano fortemente `@MainActor`/UI-adjacent.
- Manual sync e automatic sync condividono ancora helper, remote service e outbox in modo non sempre evidente.
- Alcuni file sono troppo grandi per review affidabile (`OptionsView.swift`, `SupabaseInventoryService.swift`, `SupabaseManualSyncViewModel.swift`).
- `HistorySessionSyncService` e' usato da automatic, manual, incremental e UI/history path: non e' eliminabile senza split e reference scan.
- Gli scan TASK-118 sono ancora innestati in `task117_scans.py`, creando ownership confusa per TASK-119.
- I test TASK-118 includono behaviour test utili, ma anche static string absence test; TASK-119 deve aggiungere prove architetturali e comportamentali piu' forti.

Il refactor non puo' passare come rename/move-only: deve provare net simplification con before/after architecture maps, ownership reduction e dependency/boundary checks.

## Architettura attuale osservata
Mappa post-TASK-118 osservata in planning:

```text
iOS root / presentation
  ContentView.swift
    -> crea SyncOrchestrator
    -> passa SyncStateStore e runtime factory
    -> mantiene HistorySessionSyncService per HistoryView
  iOSMerchandiseControlApp.swift
    -> crea SupabaseInventoryService, sync event recorder/watcher
  OptionsView.swift
    -> osserva SyncStateStore
    -> contiene molta UI sync/presentation nello stesso file

Sync/
  SyncOrchestrator.swift (@MainActor ObservableObject)
    -> decision input provider
    -> state store
    -> automatic runtime
    -> foreground/reconnect/safety loop UI-adjacent
  SyncAutomaticRuntime.swift (@MainActor)
    -> run/cancel/busy state
    -> factory crea servizi automatici
    -> activeTask placeholder flag
  SyncAutomaticRuntimeProviders.swift
    -> protocolli, plans, results multi-dominio
  AutomaticPushServices.swift
    -> catalog push
    -> product price push
    -> history session push
    -> automatic outbox writer
    -> activity registration
  SyncDecisionEngine.swift
    -> decision pure-ish
  SyncDecisionInputProvider.swift (actor)
    -> ModelContainer + fresh ModelContext
  SyncState.swift / SyncStateStore.swift
    -> state presentation/runtime outcome
  Incremental/*
    -> pull/apply per catalog/product price/history/sync events
  Outbox/*
    -> local outbox facade/coalescing/drain/recorder
  Recovery/*
    -> bootstrap/full recovery/drift services
  Presentation/*
    -> OptionsSyncSummaryProvider, SyncStatusPresenter

Manual / legacy-adjacent root files
  SupabaseManual*
  *ManualPush*
  *Adapter*
  *Outbox*
  SupabaseManualSyncViewModel.swift
  SupabaseManualSyncReleaseFactory.swift

Remote / shared services
  SupabaseInventoryService.swift
    -> automatic remote writes
    -> manual remote writes/previews/debug helpers
    -> history/incremental remote conformances
  HistorySessionSyncService.swift
    -> shared history payload/remote/apply/push helper
```

Observed facts from planning inspection:
- `AutomaticPushServices.swift`: 986 lines and multiple domains.
- `SyncAutomaticRuntime.swift`: `@MainActor`, 266 lines, uses `activeTask` as busy placeholder.
- `SyncOrchestrator.swift`: `@MainActor ObservableObject`, 482 lines, mixes UI scheduling and automatic orchestration.
- `OptionsView.swift`: 1041 lines, observer of real `SyncStateStore` but still presentation-heavy.
- `SupabaseInventoryService.swift`: 1861 lines, mixed manual/automatic/debug remote methods.
- `HistorySessionSyncService.swift`: 680 lines, shared across automatic, manual, incremental and history UI paths.
- `tools/agent/lib/task117_scans.py`: 770 lines, still contains TASK-118 semantics.
- `tools/agent/mcp/server.mjs`: thin wrapper pattern exists, but allowlist is TASK-118/TASK-115 oriented.

## Architettura target
Target desiderato per futura execution:

```text
iOSMerchandiseControl/Sync/
  Automatic/
    Core/
      AutomaticSyncEngine.swift
      AutomaticSyncRuntimeFacade.swift
      AutomaticSyncSingleFlight.swift
      AutomaticSyncCancellationPolicy.swift
    Decision/
      SyncDecisionInputProvider.swift
      SyncDecisionEngine.swift
      SyncTrigger.swift
    Catalog/
      CatalogPushPlanner.swift
      CatalogPushService.swift
      CatalogPushPayloads.swift
      CatalogRemoteWriting.swift
    ProductPrice/
      ProductPricePushPlanner.swift
      ProductPricePushService.swift
      ProductPricePushPayloads.swift
      ProductPriceRemoteWriting.swift
    History/
      HistorySessionAutomaticPushService.swift
      HistorySessionPushPlanner.swift
      HistorySessionRemoteWriting.swift
    Outbox/
      AutomaticSyncEventOutboxWriter.swift
      SyncActivityRegistrationService.swift
    Pull/
      CatalogIncrementalApplyService.swift
      ProductPriceIncrementalApplyService.swift
      HistoryIncrementalApplyService.swift
      SyncEventIncrementalPullService.swift
      WatermarkStore.swift
    Presentation/
      SyncStatusPresenter.swift
      OptionsSyncSummaryProvider.swift
  Manual/
    SupabaseManual*
    *ManualPush*
    manual-only adapters/conversions/factories/view models
  Shared/
    pure value types only
    shared DTOs only if not manual/result leakage
  Recovery/
    explicit bootstrap/full recovery services
  Account/
    account binding/switch policy
```

Target rules:
- Automatic core owns single-flight, cancellation and retry semantics.
- Non-UI work moves off `@MainActor` where feasible.
- SwiftUI/root/Options receive only presentation facades/state.
- Automatic services use `ModelContainer` + fresh `ModelContext` for background SwiftData work.
- Manual sync remains supported only as explicit isolated boundary if retained.
- Shared contains only pure value types/contracts that do not leak manual DTO/result semantics into automatic.
- Supabase contract validation is read-only. TASK-119 must not invent tables, columns, RLS policies, grants, RPCs, migrations or schema changes.

## Boundary automatic/manual rules
| Rule | Requirement |
| --- | --- |
| Automatic runtime imports | No nominal references to `SupabaseManual*`, `ManualPush*`, manual DTO/result types, compatibility adapters or manual-only factories. |
| Manual sync support | Allowed only through explicit `Sync/Manual/` boundary or documented manual-only root files until moved. |
| Shared code | Only pure values/contracts, no manual result leakage into automatic plans/results. |
| Remote contracts | Automatic remote writing protocols belong near automatic domains; `SupabaseInventoryService` can conform via extensions only if methods are schema-real and read/write semantics are explicit. |
| Outbox | Automatic outbox writer/service must not depend on manual conversion helpers. Shared outbox store is allowed only behind narrow documented API. |
| SwiftData | Automatic background work uses `ModelContainer` and fresh `ModelContext`; UI `ModelContext` is presentation-only. |
| MainActor | `@MainActor` is allowed for SwiftUI/presentation facades, not for automatic core scheduling/storage/network work unless documented with reviewer approval. |
| Bootstrap/full recovery | No normal automatic foreground path can trigger bootstrap/full recovery without explicit recovery/account context. |
| Options/root | Observer-only: no manual sync trigger, no automatic orchestration ownership, no hardcoded idle/progress. |
| History | `HistorySessionSyncService` is unknown/shared until split proves domain roles; not a deletion candidate without reference scan and tests. |

### Automatic boundary contamination risks
| Risk | Current observation | Required future proof |
| --- | --- | --- |
| Automatic references manual services | TASK-118 removed obvious root/runtime manual push wiring, but scans are TASK-118/TASK-117 named. | `scan manual-boundary --task TASK-119 --strict` PASS. |
| Shared `SupabaseInventoryService` mixes automatic/manual | Same actor exposes automatic, manual, debug and history/incremental methods. | Remote contract split or documented conformance boundaries. |
| `HistorySessionSyncService` spans automatic/manual/incremental | Used by automatic push, manual factory, incremental apply and History UI. | Split or justify; tests prove no manual leak into automatic. |
| Outbox compatibility facade | `LocalOutboxStore` documents compatibility with existing sync-event outbox table and legacy manual adapters. | Automatic outbox writer independent from manual conversion helpers. |
| MainActor automatic core | Runtime/orchestrator/factory are `@MainActor`; activity registration has MainActor task. | Non-UI engine tests and documented remaining presentation-only MainActor usage. |
| Static scans too string-based | TASK-118 has valuable behaviour tests but also absence-of-string checks. | TASK-119 architecture tests plus behaviour tests for engine/single-flight/cancel/retry. |
| Xcode membership after moves | Project uses filesystem synchronized root group; stale exceptions/build scripts still need audit. | `scan xcode-membership --task TASK-119 --strict` after every move/delete. |

## File audit table
Classification values: keep, move, split, delete candidate, unknown.

| File / area | Classification | Current role | TASK-119 planning decision |
| --- | --- | --- | --- |
| `iOSMerchandiseControl/ContentView.swift` | keep / trim | Root composition, creates orchestrator/runtime, passes state. | Keep root observer/wiring only; audit that it does not instantiate manual services for automatic. |
| `iOSMerchandiseControl/iOSMerchandiseControlApp.swift` | keep / trim | App dependency root for Supabase services and event recorder/watcher. | Keep app-level dependencies; no manual push service in automatic path. |
| `iOSMerchandiseControl/OptionsView.swift` | split / move presentation | Large Options UI; observes `SyncStateStore` and summary provider. | Keep Options observer-only; move sync UI helpers/providers to `Sync/Automatic/Presentation/` where feasible. |
| `iOSMerchandiseControl/Sync/SyncAutomaticRuntime.swift` | split | Runtime facade/factory, MainActor, busy flag, run result. | Split into engine/facade/single-flight/cancellation policy; move non-UI work off MainActor. |
| `iOSMerchandiseControl/Sync/SyncAutomaticRuntimeProviders.swift` | split | Protocols/plans/results for many automatic domains. | Split plans/results/protocols into domain folders or `Shared` pure values. |
| `iOSMerchandiseControl/Sync/AutomaticPushServices.swift` | split | Catalog/product-price/history/outbox/activity services in one god file. | Mandatory split or reviewer-approved justification; preferred split into Catalog/ProductPrice/History/Outbox. |
| `iOSMerchandiseControl/Sync/SyncOrchestrator.swift` | split | `@MainActor` UI scheduling, safety loop, decisions, runtime calls. | Split UI facade/scheduler from automatic engine; root remains observer/controller only. |
| `iOSMerchandiseControl/Sync/SyncDecisionEngine.swift` | move / keep | Pure decision types and engine. | Move to `Sync/Automatic/Decision/`; keep pure and manual-free. |
| `iOSMerchandiseControl/Sync/SyncDecisionInputProvider.swift` | move / keep | Actor reads account/reachability/pending/baseline via fresh context. | Move to `Sync/Automatic/Decision/`; preserve `ModelContainer` + fresh context. |
| `iOSMerchandiseControl/Sync/SyncTrigger.swift` | move / keep | Automatic trigger value. | Move to `Sync/Automatic/Decision/` or `Core/` as pure value. |
| `iOSMerchandiseControl/Sync/SyncState.swift` | move / keep | Runtime/presentation state value. | Keep if pure; likely `Automatic/Presentation` or `Shared` depending dependencies. |
| `iOSMerchandiseControl/Sync/SyncStateStore.swift` | move / keep | MainActor ObservableObject state store. | Keep presentation/state boundary; document MainActor as UI-facing only. |
| `iOSMerchandiseControl/Sync/Presentation/*` | move / keep | Sync presentation for Options/status. | Move under `Sync/Automatic/Presentation/`; no orchestration ownership. |
| `iOSMerchandiseControl/Sync/Incremental/*` | move / keep | Incremental pull/apply domain services. | Move automatic pull services under `Sync/Automatic/Pull/`; keep summaries pure. |
| `iOSMerchandiseControl/Sync/Outbox/*` | keep / move / audit | Local outbox store/coalescer/drainer/recorder. | Move automatic-owned writer pieces to `Automatic/Outbox`; shared store only if pure/narrow. |
| `iOSMerchandiseControl/Sync/Recovery/*` | keep / audit | Bootstrap/full recovery/drift services. | Keep explicit recovery boundary; ensure normal automatic path cannot invoke without explicit context. |
| `iOSMerchandiseControl/Sync/Account/*` | keep | Account binding/switch policy. | Keep under `Sync/Account/`; verify automatic decision uses it through pure contracts. |
| `iOSMerchandiseControl/SupabaseInventoryService.swift` | split / move contracts | Large actor with automatic, manual, debug, inventory and history contracts. | Do not delete; extract automatic remote writing protocols/extensions where feasible; validate against existing schema only. |
| `iOSMerchandiseControl/HistorySessionSyncService.swift` | unknown / split | Shared history remote/apply/push helper. | Not a deletion candidate; audit role and split automatic history push from manual/shared helpers. |
| `iOSMerchandiseControl/SupabaseManual*` | move | Manual sync services/coordinator/view models/factories. | Move/isolate under `Sync/Manual/` if manual flow remains supported. |
| `iOSMerchandiseControl/*ManualPush*` | move | Manual push services/debug/preflight. | Manual-only boundary; no automatic imports. |
| `iOSMerchandiseControl/*Adapter*` | move / audit | Manual/compat adapters, release factory adapters. | Move to `Sync/Manual/` or delete only after reference scan. |
| `iOSMerchandiseControl/*Compatibility*` | delete candidate / absent | No matching files found in planning scan. | Document absent; if reappears, prove references and Xcode membership before delete. |
| `iOSMerchandiseControl/*Outbox*` | keep / audit | Legacy/manual and sync-event outbox helpers. | Separate automatic writer from manual conversions; retain shared storage only if tested. |
| `iOSMerchandiseControl/SupabaseManualSyncViewModel.swift` | move / split | Very large manual sync view model. | Manual-only; split only if retained manual boundary needs maintainability. |
| `iOSMerchandiseControl/SupabaseManualSyncReleaseFactory.swift` | move / split | Manual release factory and adapter construction. | Manual-only; ensure automatic runtime never imports/instantiates it. |
| `iOSMerchandiseControl/SupabaseManualSyncOutboxProducerConversions.swift` | move / audit | Manual result to outbox conversion helpers. | Manual-only; automatic path must not reference. |
| `iOSMerchandiseControl/SupabaseProductPriceManualPushService.swift` | move | Manual product price push. | Manual-only boundary. |
| `iOSMerchandiseControl/ProductPriceManualPushDebugViewModel.swift` | move / unknown | Debug/manual product price UI model. | Manual/debug only; delete only if unsupported and unreferenced. |
| `iOSMerchandiseControl/SupabaseSyncEventIncrementalApplyService.swift` | keep / audit | Compatibility wrapper over incremental apply. | Audit whether stale compatibility wrapper remains needed. |
| `iOSMerchandiseControl/InventorySyncService.swift` | unknown | Older inventory sync service. | Reference scan before keep/delete; ensure not normal automatic owner. |
| `iOSMerchandiseControlTests/*Sync*` | keep / expand | Broad sync regression tests. | Keep; add TASK-119 architecture/manual-boundary regressions. |
| `iOSMerchandiseControlTests/Task118AutomaticDomainTests.swift` | keep / expand | TASK-118 automatic-domain tests. | Keep as baseline; add TASK-119 tests for history/outbox/engine/single-flight/cancel/retry. |
| `tools/agent/mc-agent.sh` | keep / extend | Canonical harness entrypoint. | Add TASK-119 commands before Swift refactor; do not bypass with manual shell. |
| `tools/agent/lib/ios.sh` | keep / extend | iOS build/test/smoke wrappers. | Add `ios test automatic-architecture --task TASK-119`. |
| `tools/agent/lib/task117_scans.py` | keep historical / stop growing | Historical TASK-117/TASK-118 scan implementation. | Do not hide TASK-119 semantics here; split/rename ownership. |
| `tools/agent/lib/sync_architecture_scans.py` | create in future execution | Shared sync architecture scans. | Preferred home for reusable architecture scans. |
| `tools/agent/lib/task119_scans.py` | create in future execution | TASK-119-specific checks. | Preferred home for task-specific checks. |
| `tools/agent/mcp/server.mjs` | keep / extend | Thin allowlisted MCP wrapper over `mc-agent.sh`. | Add TASK-119 allowlist entries; keep argv/fixed cwd/timeout; no live/cleanup env mutation. |
| `iOSMerchandiseControl.xcodeproj/project.pbxproj` | keep / audit | Xcode project with synchronized root group. | Audit membership/exceptions after moves/deletes; no stale membership. |

## Dead-code/stale-file candidate table
No deletion is authorized in PLANNING. Every delete candidate requires reference scan, Xcode membership audit, build/test plan and reviewer acceptance.

| Candidate | Current evidence | Future decision rule |
| --- | --- | --- |
| Original `AutomaticPushServices.swift` after split | God file multi-domain today. | Delete only after all domain services moved, references updated, builds/tests pass. |
| `*Compatibility*` files | No matching files found in planning file scan. | If present in future, reference scan and Xcode membership audit before delete. |
| `SupabaseSyncEventIncrementalApplyService.swift` | Appears compatibility-adjacent. | Keep unless scan proves no references and replacement path is tested. |
| `InventorySyncService.swift` | Legacy/older sync naming. | Unknown until reference/call graph scan. |
| Manual conversion/outbox helpers | Manual flow may remain supported. | Not delete candidates unless manual flow is explicitly retired or helpers are unreferenced. |
| `HistorySessionSyncService.swift` | Used by multiple paths. | Not delete candidate; split roles first. |
| `ProductPriceManualPushDebugViewModel.swift` | Debug/manual naming. | Delete only if debug/manual support decision says unsupported and no references. |
| TASK-117/TASK-118 scan semantics in `task117_scans.py` | Scanner name now confusing. | Do not delete immediately; migrate TASK-119 checks to new files and keep historical compatibility. |
| Stale Xcode synchronized exceptions | Project uses filesystem synchronized root group. | `scan xcode-membership` must prove no stale exceptions/build phase/script references after moves/deletes. |

## Refactor execution slices
Future execution must proceed in small, reviewable slices:

1. Dynamic HEAD/preflight/config/evidence baseline.
2. Add/fix TASK-119 harness scans and MCP allowlist.
3. Add failing architecture/static tests before large moves.
4. Move target directory structure with behavior-preserving commits.
5. Extract automatic engine/facade/single-flight/cancel/retry.
6. Split catalog/product-price/history/outbox/pull services.
7. Isolate manual sync under `Sync/Manual`.
8. Delete only proven-unused files after reference scan and Xcode membership audit.
9. Run Debug/Release build, automatic-domain tests, sync tests, automatic-architecture tests.
10. Run Options smoke or document `BLOCKED_EXTERNAL` plus fallback.
11. Run sensitive/evidence/JSON validation.
12. Run live matrix only with explicit user approval.
13. Run cleanup/residue only if synthetic live data was created.
14. Handoff to Review; never mark DONE inside Execution.

## Acceptance criteria CA-119-01...CA-119-40
- **CA-119-01**: automatic runtime has zero nominal references to manual sync services/DTO/results/adapters.
- **CA-119-02**: manual sync files are isolated in manual boundary or clearly documented as supported manual-only.
- **CA-119-03**: `AutomaticPushServices.swift` is split into cohesive domain files or justified with reviewer-approved reason.
- **CA-119-04**: automatic core runtime is moved off `@MainActor` where non-UI work is involved, with a UI facade only for SwiftUI.
- **CA-119-05**: single-flight/cancel/retry semantics are owned by automatic engine, not fake placeholder task flags.
- **CA-119-06**: all automatic SwiftData operations use `ModelContainer` + fresh context, not UI context.
- **CA-119-07**: catalog/product-price/history/outbox services have independent unit tests.
- **CA-119-08**: no full pull/bootstrap normal path outside explicit account/recovery context.
- **CA-119-09**: Options/root are observer-only and show real state.
- **CA-119-10**: no stale compatibility files remain in Xcode project membership.
- **CA-119-11**: dead-code deletion candidates are backed by reference scan and build/test plan.
- **CA-119-12**: Debug and Release builds PASS in future execution.
- **CA-119-13**: `ios test automatic-domain` PASS in future execution.
- **CA-119-14**: `ios test sync` PASS in future execution.
- **CA-119-15**: Options smoke primary PASS or BLOCKED_EXTERNAL with fallback evidence.
- **CA-119-16**: live matrix only runs with explicit `MC_ALLOW_LIVE=1`; otherwise remains BLOCKED_EXTERNAL or UNSAFE_OPERATION_REFUSED, not fake PASS.
- **CA-119-17**: evidence scan, sensitive scan, JSON validation PASS.
- **CA-119-18**: `git diff --check` PASS.
- **CA-119-19**: no regression in manual sync if manual sync remains a supported explicit flow.
- **CA-119-20**: final review can say APPROVED only if architecture is simpler than TASK-118, not just renamed.
- **CA-119-21**: HEAD is verified dynamically through git head-consistency; no hardcoded commit is treated as current truth.
- **CA-119-22**: status taxonomy is documented and used consistently in all reports.
- **CA-119-23**: all existing canonical mc-agent commands are used instead of manual command reconstruction.
- **CA-119-24**: missing TASK-119 scan/test harness commands are created before large Swift refactor.
- **CA-119-25**: MCP wrapper remains allowlisted, argv-based, cwd-fixed, timeout-bound, and does not set live/cleanup env flags.
- **CA-119-26**: TASK-119 evidence path guard rejects reports outside `docs/TASKS/EVIDENCE/TASK-119/`.
- **CA-119-27**: scanner ownership is clarified; TASK-119 semantics are not hidden inside confusing TASK-117/TASK-118-only names.
- **CA-119-28**: cleanup/residue protocol is documented with dry-run, cleanup_plan_id, execute gate, residue check, and forbidden operations.
- **CA-119-29**: `AutomaticPushServices.swift` is split or every retained responsibility is justified with reviewer approval.
- **CA-119-30**: automatic core non-UI work is removed from `@MainActor`, or each remaining `@MainActor` use is documented as presentation-only.
- **CA-119-31**: all SwiftData sync services use `ModelContainer` + fresh context for background work, not UI `ModelContext`.
- **CA-119-32**: single-flight/cancel/retry semantics are covered by tests, not only by placeholder `activeTask`.
- **CA-119-33**: manual sync remains supported only through explicit manual boundary and has regression tests if retained.
- **CA-119-34**: Xcode project membership and filesystem-synchronized exceptions are audited after every move/delete.
- **CA-119-35**: Supabase remote contracts are validated against existing schema/service methods; no invented tables/columns/migrations.
- **CA-119-36**: Options/root remain observer-only and read real sync state.
- **CA-119-37**: no normal automatic path can trigger bootstrap/full recovery without explicit recovery/account context.
- **CA-119-38**: no new sensitive data appears in evidence, logs, diagnostics, screenshots or JSON reports.
- **CA-119-39**: final Review includes a before/after architecture map proving net simplification, not only file renames.
- **CA-119-40**: DONE requires Review approval plus all non-external gates PASS, and live/device blockers either PASS or explicit user acceptance.

## Test matrix
Planning only: none of these commands were run for TASK-119 during task creation.

| Gate | Canonical future command | Required status |
| --- | --- | --- |
| HEAD consistency | `./tools/agent/mc-agent.sh git head-consistency --task TASK-119` | PASS before execution. |
| Preflight | `./tools/agent/mc-agent.sh preflight --require-head-consistency --task TASK-119` | PASS before execution. |
| Config validate | `./tools/agent/mc-agent.sh config validate --task TASK-119` | PASS before execution. |
| Existing strict sync boundary scan | `./tools/agent/mc-agent.sh scan sync-boundaries --task TASK-119 --strict` | PASS or improve harness first. |
| Existing no full pull scan | `./tools/agent/mc-agent.sh scan no-full-pull-normal-path --task TASK-119 --strict` | PASS or improve harness first. |
| New architecture scan | `./tools/agent/mc-agent.sh scan sync-architecture --task TASK-119 --strict` | Must exist before Swift moves. |
| New manual boundary scan | `./tools/agent/mc-agent.sh scan manual-boundary --task TASK-119 --strict` | Must exist before Swift moves. |
| New dead-code scan | `./tools/agent/mc-agent.sh scan dead-code --task TASK-119 --strict` | Must report only; never delete. |
| New Xcode membership scan | `./tools/agent/mc-agent.sh scan xcode-membership --task TASK-119 --strict` | PASS after every move/delete. |
| Debug build | `./tools/agent/mc-agent.sh ios build debug --task TASK-119` | PASS in future execution. |
| Release build | `./tools/agent/mc-agent.sh ios build release --task TASK-119` | PASS in future execution. |
| Automatic domain tests | `./tools/agent/mc-agent.sh ios test automatic-domain --task TASK-119` | PASS in future execution. |
| Broad sync tests | `./tools/agent/mc-agent.sh ios test sync --task TASK-119` | PASS in future execution. |
| Automatic architecture tests | `./tools/agent/mc-agent.sh ios test automatic-architecture --task TASK-119` | Must be created and PASS. |
| Options smoke | `./tools/agent/mc-agent.sh ios smoke options --task TASK-119` | PASS preferred; BLOCKED_EXTERNAL with fallback allowed for review, not automatic DONE. |
| Supabase status redacted | `./tools/agent/mc-agent.sh supabase status-redacted --task TASK-119` | PASS or BLOCKED_EXTERNAL depending local tooling; read-only. |
| Sensitive scan | `./tools/agent/mc-agent.sh scan sensitive --task TASK-119` | PASS. |
| Evidence scan | `./tools/agent/mc-agent.sh scan evidence --task TASK-119` | PASS. |
| JSON validation | `./tools/agent/mc-agent.sh report validate-json --task TASK-119 --path docs/TASKS/EVIDENCE/TASK-119/agent-runs` | PASS. |
| Diff whitespace | `git diff --check` | PASS. |
| Live reconcile | `MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh live reconcile-counts --task TASK-119 --prefix TASK119_RECON_` | Run only with explicit approval. |
| Live matrix | `MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh live sync-matrix --task TASK-119 --prefix TASK119_FINAL_` | Run only with explicit approval. |

## Regression risk matrix
| Risk | Impact | Required mitigation |
| --- | --- | --- |
| Automatic/manual boundary regression | Automatic path reimports manual services or DTOs. | `scan manual-boundary`, source review, unit tests. |
| MainActor extraction changes scheduling | Race/cancel/retry behaviour changes. | Engine unit tests for single-flight/cancel/retry and orchestrator integration tests. |
| SwiftData context misuse | Background crash or UI context leak. | Static scan and tests proving fresh `ModelContext(modelContainer)`. |
| Catalog/product-price push split | Remote writes or pending ack semantics regress. | Independent service tests plus automatic-domain suite. |
| History split | History sessions stop syncing or manual history flow breaks. | History automatic tests and retained manual regression tests. |
| Outbox split | Events not recorded/drained or manual conversions reused accidentally. | Outbox unit tests and boundary scan. |
| Options/root simplification | User sees stale/hardcoded state. | Options smoke plus state store/presenter tests. |
| Xcode membership drift | Moved files not built or stale paths linger. | `scan xcode-membership`, Debug/Release builds. |
| Dead-code deletion false positive | Supported manual/debug flow removed. | Reference counts, project membership, tests, reviewer approval. |
| Harness misconfiguration | Evidence appears outside task path or fake PASS. | Status taxonomy, JSON validation, evidence path guard. |
| Live/cleanup safety | Live data mutation or unsafe cleanup. | `MC_ALLOW_LIVE`, `MC_ALLOW_CLEANUP`, scoped `TASK119_` prefixes, cleanup plan id. |
| Supabase schema assumptions | Code assumes nonexistent table/column/RPC. | Read-only contract validation against existing schema/service methods only. |

## Evidence requirements
Existing TASK-119 evidence at planning creation: none, because TASK-119 is still planning.

Expected future evidence root:

```text
docs/TASKS/EVIDENCE/TASK-119/agent-runs/
```

Every future command must write:
- `.md` human-readable report.
- `.json` schema `1.1` machine-readable report.
- `.log` redacted raw log.

Required fields/artifacts:
- `NEXT_ACTION`
- task id = `TASK-119`
- git SHA
- dirty state
- safety level
- result status
- command name/slug
- evidence path under `docs/TASKS/EVIDENCE/TASK-119/agent-runs/`

Evidence outside `docs/TASKS/EVIDENCE/TASK-119/` is `MISCONFIGURED`.

### Redaction requirements
Reports/logs/screenshots/JSON must redact:
- Supabase anon/service keys.
- JWT/token/password.
- Email addresses.
- Project ref.
- Local user home paths.
- Device IDs/serials.
- Raw `config.env` values.
- OAuth callback data.
- SQL/query payloads that expose personal data.
- Real customer data.

No report may contain unredacted `config.env`, OAuth callback data, JWT, service role, email, or real customer data.

### Status taxonomy
| Status | Meaning |
| --- | --- |
| PASS | Command ran, exit code 0, evidence `.md/.json/.log` exists, output redacted. |
| FAIL | Command ran, detected a real problem, exit code non-zero. |
| BLOCKED_EXTERNAL | External prerequisite missing, e.g. device locked, auth missing, Accessibility/JXA unavailable, live not allowed. |
| NOT_RUN | Intentionally not executed in this phase; cannot count as PASS. |
| PASS_WITH_NOTES | Allowed only when the note is non-blocking and explicitly accepted in Review/Done policy. |
| MISCONFIGURED | Wrong task id, wrong evidence path, missing config, malformed report, invalid env. |
| UNSAFE_OPERATION_REFUSED | Live/cleanup/destructive action refused by safety gate. |

Rules:
- A task cannot move to REVIEW with unexpected `FAIL`, `MISCONFIGURED`, or `UNSAFE_OPERATION_REFUSED`.
- A task cannot move to DONE with `BLOCKED_EXTERNAL` unless the user explicitly accepts the residual blocker.
- `NOT_RUN` never counts as PASS.
- `PASS_WITH_NOTES` requires explicit acceptance in review/done policy.

## Done policy
TASK-119 must not be marked READY_FOR_EXECUTION until the complete task file contains:
- file-by-file audit table;
- target architecture tree;
- deletion candidate table;
- harness integration matrix;
- status taxonomy;
- evidence/redaction rules;
- cleanup/live safety gates;
- test matrix;
- regression risk matrix;
- done policy.

TASK-119 cannot move to REVIEW with unexpected `FAIL`, `MISCONFIGURED`, or `UNSAFE_OPERATION_REFUSED`.

TASK-119 cannot move to DONE unless:
- Review approval exists.
- All non-external gates are PASS.
- Live/device blockers are PASS or explicitly accepted by the user as residual risk.
- Before/after architecture maps prove net simplification.
- Manual sync regression coverage exists if manual sync remains supported.
- No Swift/Kotlin/SQL/schema changes are untracked by evidence.

## Harness / Automation Integration — TASK-119
TASK-119 must use the existing `./tools/agent/mc-agent.sh` harness whenever a canonical command exists. Cursor/Codex/Claude must not reconstruct long manual shell commands when `mc-agent` already provides a wrapper.

Planning-only phase must not run build/test/live/cleanup commands. Future Execution must use:

```bash
./tools/agent/mc-agent.sh git head-consistency --task TASK-119
./tools/agent/mc-agent.sh preflight --require-head-consistency --task TASK-119
./tools/agent/mc-agent.sh config validate --task TASK-119

./tools/agent/mc-agent.sh scan sync-boundaries --task TASK-119 --strict
./tools/agent/mc-agent.sh scan no-full-pull-normal-path --task TASK-119 --strict

./tools/agent/mc-agent.sh ios build debug --task TASK-119
./tools/agent/mc-agent.sh ios build release --task TASK-119
./tools/agent/mc-agent.sh ios test automatic-domain --task TASK-119
./tools/agent/mc-agent.sh ios test sync --task TASK-119
./tools/agent/mc-agent.sh ios smoke options --task TASK-119

./tools/agent/mc-agent.sh supabase status-redacted --task TASK-119
./tools/agent/mc-agent.sh scan sensitive --task TASK-119
./tools/agent/mc-agent.sh scan evidence --task TASK-119
./tools/agent/mc-agent.sh report validate-json --task TASK-119 --path docs/TASKS/EVIDENCE/TASK-119/agent-runs
```

If any command does not yet support `--task TASK-119`, future Execution must improve the harness first instead of bypassing it manually.

### New or improved TASK-119 harness commands required before Swift refactor
Future Execution must add or improve these commands before large Swift moves/deletions:

```bash
./tools/agent/mc-agent.sh scan sync-architecture --task TASK-119 --strict
./tools/agent/mc-agent.sh scan manual-boundary --task TASK-119 --strict
./tools/agent/mc-agent.sh scan dead-code --task TASK-119 --strict
./tools/agent/mc-agent.sh scan xcode-membership --task TASK-119 --strict
./tools/agent/mc-agent.sh ios test automatic-architecture --task TASK-119
```

Required behavior:
- `scan sync-architecture` verifies target folder/domain structure and rejects new god files.
- `scan manual-boundary` rejects automatic runtime references to `SupabaseManual*`, `ManualPush*`, manual DTO/result types, compatibility adapters, or manual-only factories.
- `scan dead-code` reports delete candidates with reference counts and Xcode membership status; it must not delete.
- `scan xcode-membership` verifies moved/deleted files are not stale in `project.pbxproj`, build phases, filesystem-synchronized exceptions, tests, or scripts.
- `ios test automatic-architecture` runs only TASK-119 architecture/unit tests and remains separate from broad `ios test sync`.

New TASK-119 scans must be operator/agent-friendly:
- print stable `SUMMARY`, `RESULT`, `REPORT_MD`, `REPORT_JSON`, `NEXT_ACTION`;
- on `FAIL`, identify file/symbol/reason/fix hint;
- on `BLOCKED_EXTERNAL`, identify the missing external prerequisite;
- avoid noisy full dumps unless linked as artifacts;
- produce stable JSON schema `1.1`.

### Scanner ownership rule
Do not keep growing `task117_scans.py` with TASK-119 semantics unless it is renamed or split.

Preferred future structure:
- `tools/agent/lib/sync_architecture_scans.py` for shared sync architecture scans.
- `tools/agent/lib/task119_scans.py` only for TASK-119-specific checks.
- `task117_scans.py` may remain only for historical TASK-117/TASK-118 compatibility.

### MCP safety
MCP wrapper must remain:
- thin allowlisted adapter over `mc-agent.sh`;
- fixed cwd;
- argv-based;
- timeout-bound;
- no arbitrary shell strings;
- no duplicated scan logic;
- no `MC_ALLOW_LIVE` or `MC_ALLOW_CLEANUP` env flag mutation.

### Cleanup / residue safety
Planning phase must not run cleanup.

Future cleanup is allowed only for synthetic TASK-119 prefixes and only through canonical harness:

```bash
./tools/agent/mc-agent.sh supabase cleanup --task TASK-119 --prefix TASK119_DRYRUN_ --dry-run
MC_ALLOW_CLEANUP=1 ./tools/agent/mc-agent.sh supabase cleanup --task TASK-119 --prefix TASK119_DRYRUN_ --execute --cleanup-plan-id <id>
./tools/agent/mc-agent.sh supabase residue-check --task TASK-119 --prefix TASK119_DRYRUN_ --profile linked
```

Rules:
- Cleanup execute requires prior dry-run `cleanup_plan_id`.
- Prefix must start with `TASK119_`.
- Global cleanup, `%`, wildcard-only prefix, `auth.users`, truncate/reset DB, service-role client and RLS bypass are forbidden.
- Residue count must be 0 for synthetic prefixes before DONE if live/cleanup created test rows.
- If no live data was created, record cleanup as `NOT_RUN / not required`, not PASS.

### Live gates
Planning phase must not run live gates.

Future live gates require explicit user approval:

```bash
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh live reconcile-counts --task TASK-119 --prefix TASK119_RECON_
MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh live sync-matrix --task TASK-119 --prefix TASK119_FINAL_
```

If `MC_ALLOW_LIVE=1` is absent, result must be `BLOCKED_EXTERNAL` or `UNSAFE_OPERATION_REFUSED`, not FAIL and not PASS.

### Options smoke fallback policy
- Primary `ios smoke options` PASS is preferred.
- XcodeBuildMCP fallback may be supporting evidence.
- Fallback does not reclassify the primary harness gate as PASS when Accessibility/JXA is unavailable.
- Such a case remains `BLOCKED_EXTERNAL` unless explicitly accepted.

## Final Planning Hardening Addendum — Review Notes
TASK-119 remains `ACTIVE / PLANNING — HARDENED`, not `READY_FOR_EXECUTION`, until the complete TASK-119 file contains:
- file-by-file audit table;
- target architecture tree;
- deletion candidate table;
- harness integration matrix;
- status taxonomy;
- evidence/redaction rules;
- cleanup/live safety gates;
- test matrix;
- regression risk matrix;
- done policy.

With the hardening content integrated, the plan is approvable for PLANNING HARDENED only. It is not READY_FOR_EXECUTION and absolutely not DONE.

The most important review constraints:
- TASK-119 is not "just clean Swift files"; it requires architecture target, harness, scans, MCP safety, evidence, taxonomy, redaction and live/cleanup gates.
- File moves/renames do not satisfy CA-119 without reduced ownership confusion and before/after architecture proof.
- Manual sync remains supported only as explicit isolated boundary; if retained, future execution must prove manual regression coverage.
- Supabase contract validation remains read-only unless a separate migration/schema task is opened.

## Traceability matrix CA-119-01...CA-119-40 → comando/test/scan → expected evidence
| CA | Future command/test/scan | Expected evidence |
| --- | --- | --- |
| CA-119-01 | `scan manual-boundary --task TASK-119 --strict` | `.md/.json/.log` with zero automatic manual references. |
| CA-119-02 | `scan manual-boundary`, source review | Report listing manual files isolated/documented. |
| CA-119-03 | `scan sync-architecture --strict`, build | Architecture report proving split or approved justification. |
| CA-119-04 | `scan sync-architecture`, automatic architecture tests | Report of MainActor boundaries and test artifacts. |
| CA-119-05 | `ios test automatic-architecture --task TASK-119` | Tests for single-flight/cancel/retry PASS. |
| CA-119-06 | `scan sync-architecture --strict` | SwiftData context usage report. |
| CA-119-07 | `ios test automatic-architecture`, `ios test automatic-domain` | Unit test reports for catalog/product-price/history/outbox. |
| CA-119-08 | `scan no-full-pull-normal-path --strict` | PASS report proving no normal bootstrap/full recovery path. |
| CA-119-09 | `ios smoke options`, presentation tests | PASS or BLOCKED_EXTERNAL plus fallback evidence. |
| CA-119-10 | `scan xcode-membership --strict` | Report with no stale compatibility membership. |
| CA-119-11 | `scan dead-code --strict` | Reference counts + build/test plan artifacts. |
| CA-119-12 | `ios build debug`, `ios build release` | Debug/Release `.md/.json/.log` PASS. |
| CA-119-13 | `ios test automatic-domain` | Test report PASS. |
| CA-119-14 | `ios test sync` | Broad sync regression report PASS. |
| CA-119-15 | `ios smoke options` | Primary PASS or BLOCKED_EXTERNAL with fallback artifact. |
| CA-119-16 | live commands with/without `MC_ALLOW_LIVE=1` | PASS with approval or safety refused/BLOCKED report. |
| CA-119-17 | `scan evidence`, `scan sensitive`, `report validate-json` | Hygiene/redaction/schema reports PASS. |
| CA-119-18 | `git diff --check` | Whitespace check output PASS. |
| CA-119-19 | manual regression tests if retained | `ios test sync`/manual-specific test report PASS. |
| CA-119-20 | Review checklist + architecture maps | Final review evidence proving simpler architecture. |
| CA-119-21 | `git head-consistency --task TASK-119` | HEAD/GitHub/origin report with SHA and dirty state. |
| CA-119-22 | `report validate-json` + report schema review | Status taxonomy fields in JSON reports. |
| CA-119-23 | command matrix review | Evidence commands all use `mc-agent` wrappers. |
| CA-119-24 | harness self-test + new command reports | TASK-119 scans/tests exist before Swift refactor. |
| CA-119-25 | MCP self-test/source audit | Allowlist/argv/cwd/timeout/no live cleanup env mutation report. |
| CA-119-26 | path guard test/report validation | Reports outside TASK-119 evidence rejected as MISCONFIGURED. |
| CA-119-27 | scanner ownership source audit | New scan files or renamed split, no TASK-119 semantics hidden in task117-only names. |
| CA-119-28 | cleanup dry-run/refusal/residue reports | Cleanup plan id, prefix guard, residue check evidence. |
| CA-119-29 | `scan sync-architecture` | Split/justification report for `AutomaticPushServices.swift`. |
| CA-119-30 | `scan sync-architecture` + tests | Non-UI MainActor removals or presentation-only justification. |
| CA-119-31 | `scan sync-architecture` | ModelContainer/fresh context report. |
| CA-119-32 | `ios test automatic-architecture` | Single-flight/cancel/retry tests PASS. |
| CA-119-33 | manual regression tests + `scan manual-boundary` | Manual boundary regression PASS if manual retained. |
| CA-119-34 | `scan xcode-membership --strict` | Membership/exceptions report PASS. |
| CA-119-35 | Supabase read-only contract validation | Read-only status/schema/service-method report, no migrations. |
| CA-119-36 | `ios smoke options`, state tests | Options/root real state evidence. |
| CA-119-37 | `scan no-full-pull-normal-path --strict` | No normal bootstrap/full recovery report PASS. |
| CA-119-38 | `scan sensitive --task TASK-119` | Redaction/sensitive scan PASS. |
| CA-119-39 | final review architecture maps | Before/after maps with ownership reduction. |
| CA-119-40 | final review evidence matrix | All non-external gates PASS; external blockers resolved or accepted. |

## Changelog planning
- **2026-05-24 — Planning hardening integration**: creato TASK-119 come `ACTIVE / PLANNING — HARDENED` con file audit, architettura attuale/target, harness contract, scanner ownership, MCP safety, status taxonomy, evidence/redaction rules, cleanup/live gates, CA-119-01...40, test/risk/traceability matrices e prompt future EXECUTION-AUDIT. No runtime verification, no code changes, no schema changes, no live/cleanup.

## Execution

### EXECUTION-AUDIT start — 2026-05-24

#### Obiettivo compreso
Avviare TASK-119 da `ACTIVE / PLANNING — HARDENED` a `ACTIVE / EXECUTION-AUDIT`, iniziando da HEAD/preflight/config via harness canonico, prima di qualunque refactor Swift.

#### File controllati
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-119-ios-sync-automatic-architecture-purification.md`
- `docs/TASKS/EVIDENCE/TASK-119/README.md`

#### Gate eseguiti
- `./tools/agent/mc-agent.sh git head-consistency --task TASK-119`
- `./tools/agent/mc-agent.sh preflight --require-head-consistency --task TASK-119`
- `./tools/agent/mc-agent.sh config validate --task TASK-119`

#### Stato HEAD / tracking
- Local HEAD, `origin/main`, `git ls-remote origin refs/heads/main` e GitHub branch API sono coerenti su snapshot storico TASK-118 `3bcb58f9bb921e92b31f2c89de622ffbd6d11694`.
- TASK-119 tracking e planning files sono presenti localmente ma assenti su `origin/main` / GitHub rendered `main` (`404` per task file ed evidence README).
- Classificazione: `BLOCKED_HEAD_OR_TRACKING_MISMATCH` per qualunque refactor Swift.
- Decisione operativa: proseguire solo con harness/audit locali finche' il mismatch e' tracciato; non iniziare move/refactor Swift prima di riallineamento GitHub o accettazione esplicita local-only.

#### Evidence
- `docs/TASKS/EVIDENCE/TASK-119/agent-runs/20260524T020448Z-git-head-consistency-task-TASK-119-p40486.{md,json,log}`
- `docs/TASKS/EVIDENCE/TASK-119/agent-runs/20260524T020448Z-preflight-require-head-consistency-task-TASK-119-p40485.{md,json,log}`
- `docs/TASKS/EVIDENCE/TASK-119/agent-runs/20260524T020448Z-config-validate-task-TASK-119-p40487.{md,json,log}`

#### Prossima azione
Completare il blocco EXECUTION-AUDIT / harness-first creando i comandi TASK-119 mancanti, mantenendo il refactor Swift bloccato fino a risoluzione/accettazione del mismatch tracking.

### EXECUTION-AUDIT harness/baseline — 2026-05-24

#### Obiettivo compreso
Implementare la fase harness-first approvata per TASK-119 prima di qualunque refactor Swift di produzione: creare comandi TASK-119 mancanti, mantenere scanner ownership fuori da `task117_scans.py`, aggiornare MCP come thin allowlisted adapter e produrre baseline audit evidence.

#### File controllati
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-119-ios-sync-automatic-architecture-purification.md`
- `docs/TASKS/EVIDENCE/TASK-119/README.md`
- `tools/agent/mc-agent.sh`
- `tools/agent/lib/common.sh`
- `tools/agent/lib/ios.sh`
- `tools/agent/lib/task117_scans.py`
- `tools/agent/mcp/server.mjs`
- `iOSMerchandiseControl/Sync/SyncAutomaticRuntime.swift`
- `iOSMerchandiseControl/Sync/SyncAutomaticRuntimeProviders.swift`
- `iOSMerchandiseControl/Sync/AutomaticPushServices.swift`
- `iOSMerchandiseControl/Sync/SyncOrchestrator.swift`
- `iOSMerchandiseControl/Sync/SyncDecisionEngine.swift`
- `iOSMerchandiseControl/Sync/SyncDecisionInputProvider.swift`
- `iOSMerchandiseControl/SupabaseInventoryService.swift`
- `iOSMerchandiseControl/HistorySessionSyncService.swift`
- `iOSMerchandiseControl/ContentView.swift`
- `iOSMerchandiseControl/OptionsView.swift`

#### Piano minimo
1. Aggiungere scanner read-only TASK-119 con report `.md/.json/.log` via mc-agent.
2. Aggiungere suite `ios test automatic-architecture` separata da `ios test sync`.
3. Aggiornare allowlist MCP senza shell arbitraria e senza `MC_ALLOW_LIVE` / `MC_ALLOW_CLEANUP`.
4. Eseguire baseline scans/test e registrare evidence.
5. Fermare il refactor Swift di produzione sul mismatch local-only vs GitHub/origin.

#### Modifiche fatte
- Creato `tools/agent/lib/sync_architecture_scans.py` per scan condivisi sync architecture.
- Creato `tools/agent/lib/task119_scans.py` come entrypoint TASK-119 dedicato.
- Aggiornato `tools/agent/mc-agent.sh` con:
  - `scan sync-architecture --task TASK-119 --strict`
  - `scan manual-boundary --task TASK-119 --strict`
  - `scan dead-code --task TASK-119 --strict`
  - `scan xcode-membership --task TASK-119 --strict`
- Aggiornato `tools/agent/lib/common.sh` con wrapper `mc_cmd_scan_task119_static`, help text/json e CA refs.
- Aggiornato `tools/agent/lib/ios.sh` con suite `ios test automatic-architecture`.
- Creato `iOSMerchandiseControlTests/Task119AutomaticArchitectureTests.swift` con test statici baseline su boundary automatic/manual, Options/root hardcoded idle e scanner ownership.
- Aggiornato `tools/agent/mcp/server.mjs` con allowlist TASK-119 thin/argv-based per head/preflight/scans/test/report validation.
- Prodotta baseline audit evidence `20260524T021620Z-baseline-architecture-audit-task-TASK-119.{md,json,log}`.
- Corretto scanner `xcode-membership` per ignorare URL `.swift` in `project.pbxproj` e non classificarli come missing file refs.

#### Check eseguiti
- ✅ ESEGUITO — `python3 -m py_compile tools/agent/lib/sync_architecture_scans.py tools/agent/lib/task119_scans.py` PASS.
- ✅ ESEGUITO — `bash -n tools/agent/mc-agent.sh tools/agent/lib/common.sh tools/agent/lib/ios.sh` PASS.
- ✅ ESEGUITO — `node --check tools/agent/mcp/server.mjs` PASS.
- ✅ ESEGUITO — `node tools/agent/mcp/server.mjs --self-test` PASS; allowlist/injection refusal/timeout smoke verificati.
- ✅ ESEGUITO — `./tools/agent/mc-agent.sh scan sync-architecture --task TASK-119 --strict` FAIL atteso come baseline: directory target assenti, `AutomaticPushServices.swift`/`SupabaseInventoryService.swift` god files, runtime `@MainActor`, `activeTask` senza single-flight dedicato.
- ✅ ESEGUITO — `./tools/agent/mc-agent.sh scan manual-boundary --task TASK-119 --strict` FAIL atteso come baseline: `SupabaseInventoryService.swift` espone simboli manual-only.
- ✅ ESEGUITO — `./tools/agent/mc-agent.sh scan dead-code --task TASK-119 --strict` PASS; report read-only con 27 candidate rows, nessuna cancellazione.
- ✅ ESEGUITO — `./tools/agent/mc-agent.sh scan xcode-membership --task TASK-119 --strict` PASS nella riesecuzione `20260524T021412Z...`.
- ✅ ESEGUITO — `./tools/agent/mc-agent.sh ios test automatic-architecture --task TASK-119` PASS.
- ✅ ESEGUITO — `./tools/agent/mc-agent.sh scan sensitive --task TASK-119` PASS.
- ✅ ESEGUITO — `./tools/agent/mc-agent.sh scan evidence --task TASK-119` PASS.
- ✅ ESEGUITO — `./tools/agent/mc-agent.sh report validate-json --task TASK-119 --path docs/TASKS/EVIDENCE/TASK-119/agent-runs` PASS nella riesecuzione `20260524T021936Z...`.
- ✅ ESEGUITO — `git diff --check` PASS.
- ❌ NON ESEGUITO — Debug/Release build broad gates; non necessari per harness-first e refactor Swift di produzione ancora bloccato.
- ❌ NON ESEGUITO — `ios test sync`, `ios test automatic-domain`, Options smoke; rimandati a execution post-refactor o a decisione sul mismatch.
- ❌ NON ESEGUITO — Supabase live/cleanup; non richiesti, nessuna riga live creata.

#### Evidence prodotte
- `docs/TASKS/EVIDENCE/TASK-119/agent-runs/20260524T021325Z-scan-sync-architecture-task-TASK-119-strict-p45340.{md,json,log}`
- `docs/TASKS/EVIDENCE/TASK-119/agent-runs/20260524T021325Z-scan-manual-boundary-task-TASK-119-strict-p45343.{md,json,log}`
- `docs/TASKS/EVIDENCE/TASK-119/agent-runs/20260524T021325Z-scan-dead-code-task-TASK-119-strict-p45341.{md,json,log}`
- `docs/TASKS/EVIDENCE/TASK-119/agent-runs/20260524T021412Z-scan-xcode-membership-task-TASK-119-strict-p47330.{md,json,log}`
- `docs/TASKS/EVIDENCE/TASK-119/agent-runs/20260524T021419Z-ios-test-automatic-architecture-task-TASK-119-p47812.{md,json,log}`
- `docs/TASKS/EVIDENCE/TASK-119/agent-runs/20260524T021620Z-baseline-architecture-audit-task-TASK-119.{md,json,log}`
- `docs/TASKS/EVIDENCE/TASK-119/agent-runs/20260524T021858Z-scan-sensitive-task-TASK-119-p51424.{md,json,log}`
- `docs/TASKS/EVIDENCE/TASK-119/agent-runs/20260524T021858Z-scan-evidence-task-TASK-119-p51442.{md,json,log}`
- `docs/TASKS/EVIDENCE/TASK-119/agent-runs/20260524T021936Z-report-validate-json-task-TASK-119-path-docs-TASKS-EVIDENCE-TASK-119-agent-runs-p54031.{md,json,log}`

#### Rischi rimasti
- `BLOCKED_HEAD_OR_TRACKING_MISMATCH`: TASK-119 task/evidence tracking files are local-only and absent from `origin/main` / GitHub rendered `main`. Per user gate, production Swift refactor must not start until this is reconciled or explicitly accepted as local-only.
- `scan sync-architecture` FAIL is real baseline debt, not a harness failure.
- `scan manual-boundary` FAIL is real baseline debt in shared remote contract surface.
- Manual sync remains supported; future isolation requires explicit regression coverage.
- Live/device/smoke gates remain NOT_RUN; no PASS claim made.

#### Handoff / next action
Stato ammesso corrente: `ACTIVE / EXECUTION-AUDIT — HARNESS_BASELINE_COMPLETE / BLOCKED_HEAD_OR_TRACKING_MISMATCH_FOR_SWIFT_REFACTOR`.

Next concrete action: choose one before production Swift refactor:
1. riallineare/committare/pubblicare TASK-119 tracking so GitHub/origin contain the task/evidence plan; oppure
2. dare accettazione esplicita a procedere local-only despite mismatch.

Until then, only additional read-only audit/harness work should continue. Do not mark REVIEW or DONE.

### EXECUTION — HEAD realignment and progressive Swift refactor — 2026-05-24

#### Obiettivo compreso
Rimuovere il blocker `BLOCKED_HEAD_OR_TRACKING_MISMATCH_FOR_SWIFT_REFACTOR`, pubblicare la baseline harness/task su `origin/main`, poi procedere con refactor Swift progressivo solo dopo gate HEAD/preflight/config PASS. Completare split automatic-domain, engine/single-flight/cancel policy, boundary automatic/manual e prove locali senza dichiarare DONE.

#### File controllati
- `docs/MASTER-PLAN.md`
- `docs/TASKS/TASK-119-ios-sync-automatic-architecture-purification.md`
- `docs/TASKS/EVIDENCE/TASK-119/README.md`
- `iOSMerchandiseControl/Sync/AutomaticPushServices.swift`
- `iOSMerchandiseControl/Sync/SyncAutomaticRuntime.swift`
- `iOSMerchandiseControl/Sync/Automatic/Core/*`
- `iOSMerchandiseControl/Sync/Automatic/Catalog/*`
- `iOSMerchandiseControl/Sync/Automatic/ProductPrice/*`
- `iOSMerchandiseControl/Sync/Automatic/History/*`
- `iOSMerchandiseControl/Sync/Automatic/Outbox/*`
- `iOSMerchandiseControl/Sync/Automatic/Decision/*`
- `iOSMerchandiseControl/Sync/Automatic/Pull/*`
- `iOSMerchandiseControl/Sync/Automatic/Presentation/*`
- `iOSMerchandiseControl/Sync/Manual/*`
- `iOSMerchandiseControl/Sync/Shared/*`
- `iOSMerchandiseControlTests/Task118AutomaticDomainTests.swift`
- `iOSMerchandiseControlTests/Task119AutomaticArchitectureTests.swift`
- `tools/agent/mc-agent.sh`
- `tools/agent/lib/common.sh`
- `tools/agent/lib/sync_architecture_scans.py`

#### Piano minimo
1. Commit/push della baseline TASK-119 harness/planning/evidence gia' local-only.
2. Rerun HEAD/preflight/config TASK-119 via harness canonico.
3. Rerun baseline scans/test TASK-119.
4. Aggiungere test architetturale failing per engine/single-flight/cancel policy.
5. Spezzare `AutomaticPushServices.swift` in file automatic-domain coesi.
6. Estrarre `AutomaticSyncEngine`, `AutomaticSyncSingleFlight`, `AutomaticSyncCancellationPolicy` e facade runtime.
7. Rerun scans/build/test/smoke/hygiene finali via harness.
8. Aggiornare tracking e consegnare a review, non DONE.

#### Modifiche fatte
- Risolto il mismatch HEAD/tracking: commit `5454070e9937ea55b6a68e731b44eaef1ec14b22` (`TASK-119 harness baseline`) pushato su `origin/main`; `git head-consistency`, preflight e config TASK-119 PASS dopo push.
- Verificato che `origin/main` / GitHub contengano il task file TASK-119, evidence README e harness TASK-119.
- Aggiunto test TASK-119 RED iniziale per richiedere engine dedicato, single-flight, cancellation policy e rimozione `activeTask` da `SyncAutomaticRuntime.swift`.
- Spezzato `AutomaticPushServices.swift` nei domini:
  - `Sync/Automatic/Catalog/CatalogRemoteWriting.swift`
  - `Sync/Automatic/Catalog/CatalogPushPayloads.swift`
  - `Sync/Automatic/Catalog/CatalogPushService.swift`
  - `Sync/Automatic/ProductPrice/ProductPriceRemoteWriting.swift`
  - `Sync/Automatic/ProductPrice/ProductPricePushPayloads.swift`
  - `Sync/Automatic/ProductPrice/ProductPricePushService.swift`
  - `Sync/Automatic/History/HistorySessionAutomaticPushService.swift`
  - `Sync/Automatic/Outbox/AutomaticSyncEventOutboxWriter.swift`
  - `Sync/Automatic/Outbox/SyncActivityRegistrationService.swift`
- Creati boundary marker per `Sync/Automatic/Decision`, `Pull`, `Presentation`, `Sync/Manual` e `Sync/Shared`.
- Estratto `AutomaticSyncEngine` actor non-UI, con `AutomaticSyncSingleFlight` e `AutomaticSyncCancellationPolicy`; `SyncAutomaticRuntime` resta facade `@MainActor` per auth/UI boundary e delega l'esecuzione non-UI all'engine.
- Rimosso `activeTask` dal runtime automatico; single-flight/cancel sono ora owned dall'engine.
- Mantenuto `ModelContainer` + fresh `ModelContext` nei servizi automatici split.
- Tenuto `HistorySessionSyncService` fuori da delete/split distruttivo: il nuovo automatic history push e' in `HistorySessionAutomaticPushService`, ma il servizio storico resta condiviso finche' reference scan/test non autorizzano un intervento piu' profondo.
- Aggiornato `Task118AutomaticDomainTests` per riconoscere che la redazione errori runtime ora vive anche in `AutomaticSyncEngine.swift`.
- Aggiornato `scan no-full-pull-normal-path --task TASK-119 --strict` per usare `task119_scans.py` / `sync_architecture_scans.py`, mantenendo `task117_scans.py` per compatibilita' storica TASK-117/TASK-118.
- Aggiornato help/CA refs harness per il gate TASK-119 no-full-pull.
- Corretto warning Swift 6 in `SyncActivityRegistrationService` usando `SyncEventOutboxLocalStore` diretto per i conteggi e helper `status` nonisolated.

#### Check eseguiti
- ✅ ESEGUITO — `./tools/agent/mc-agent.sh git head-consistency --task TASK-119` PASS dopo push baseline: `20260524T022406Z-git-head-consistency-task-TASK-119-p57249`.
- ✅ ESEGUITO — `./tools/agent/mc-agent.sh preflight --require-head-consistency --task TASK-119` PASS dopo push baseline: `20260524T022406Z-preflight-require-head-consistency-task-TASK-119-p57248`.
- ✅ ESEGUITO — `./tools/agent/mc-agent.sh config validate --task TASK-119` PASS dopo push baseline: `20260524T022406Z-config-validate-task-TASK-119-p57301`.
- ✅ ESEGUITO — `./tools/agent/mc-agent.sh scan sync-boundaries --task TASK-119 --strict` PASS finale: `20260524T025800Z-scan-sync-boundaries-task-TASK-119-strict-p99167`.
- ✅ ESEGUITO — `./tools/agent/mc-agent.sh scan no-full-pull-normal-path --task TASK-119 --strict` PASS finale: `20260524T025235Z-scan-no-full-pull-normal-path-task-TASK-119-strict-p93424`.
- ✅ ESEGUITO — `./tools/agent/mc-agent.sh scan sync-architecture --task TASK-119 --strict` PASS finale: `20260524T025235Z-scan-sync-architecture-task-TASK-119-strict-p93354`.
- ✅ ESEGUITO — `./tools/agent/mc-agent.sh scan manual-boundary --task TASK-119 --strict` PASS finale: `20260524T025235Z-scan-manual-boundary-task-TASK-119-strict-p93423`.
- ✅ ESEGUITO — `./tools/agent/mc-agent.sh scan dead-code --task TASK-119 --strict` PASS finale: `20260524T025800Z-scan-dead-code-task-TASK-119-strict-p99166`.
- ✅ ESEGUITO — `./tools/agent/mc-agent.sh scan xcode-membership --task TASK-119 --strict` PASS finale: `20260524T025235Z-scan-xcode-membership-task-TASK-119-strict-p93425`.
- ✅ ESEGUITO — `./tools/agent/mc-agent.sh ios build debug --task TASK-119` PASS finale: `20260524T025239Z-ios-build-debug-task-TASK-119-p94980`.
- ✅ ESEGUITO — `./tools/agent/mc-agent.sh ios build release --task TASK-119` PASS finale: `20260524T025251Z-ios-build-release-task-TASK-119-p95591`.
- ✅ ESEGUITO — `./tools/agent/mc-agent.sh ios test automatic-domain --task TASK-119` PASS finale: `20260524T025408Z-ios-test-automatic-domain-task-TASK-119-p96385`.
- ✅ ESEGUITO — `./tools/agent/mc-agent.sh ios test sync --task TASK-119` PASS finale: `20260524T025433Z-ios-test-sync-task-TASK-119-p97120`.
- ✅ ESEGUITO — `./tools/agent/mc-agent.sh ios test automatic-architecture --task TASK-119` PASS finale: `20260524T025706Z-ios-test-automatic-architecture-task-TASK-119-p97953`.
- ✅ ESEGUITO — `./tools/agent/mc-agent.sh ios smoke options --task TASK-119` PASS finale: `20260524T025717Z-ios-smoke-options-task-TASK-119-p98542`.
- ✅ ESEGUITO — `./tools/agent/mc-agent.sh supabase status-redacted --task TASK-119` PASS read-only: `20260524T025027Z-supabase-status-redacted-task-TASK-119-p87039`.
- ✅ ESEGUITO — `./tools/agent/mc-agent.sh scan sensitive --task TASK-119` PASS finale: `20260524T030035Z-scan-sensitive-task-TASK-119-p7960`.
- ✅ ESEGUITO — `./tools/agent/mc-agent.sh scan evidence --task TASK-119` PASS finale: `20260524T030035Z-scan-evidence-task-TASK-119-p7959`.
- ✅ ESEGUITO — `./tools/agent/mc-agent.sh report validate-json --task TASK-119 --path docs/TASKS/EVIDENCE/TASK-119/agent-runs` PASS finale: `20260524T030035Z-report-validate-json-task-TASK-119-path-docs-TASKS-EVIDENCE-TASK-119-agent-runs-p8007`.
- ✅ ESEGUITO — `git diff --check` PASS.
- ✅ ESEGUITO — warning review su build logs: restano solo warning ambientali AppIntents metadata; i warning Swift 6 introdotti nel nuovo outbox service sono stati rimossi.
- ❌ NON ESEGUITO — live matrix/reconcile TASK-119; non richiesti per il refactor locale e non autorizzati con `MC_ALLOW_LIVE=1`.
- ❌ NON ESEGUITO — cleanup/residue; nessuna riga live sintetica creata, quindi cleanup non richiesto.
- ❌ NON ESEGUITO — migration/schema/RLS/grants/RPC; vietati da TASK-119 e non necessari.

#### Evidence prodotte
Evidence principale sotto `docs/TASKS/EVIDENCE/TASK-119/agent-runs/`:
- HEAD/preflight/config post-push: `20260524T022406Z-{git-head-consistency,preflight-require-head-consistency,config-validate}-task-TASK-119-*`.
- Baseline FAIL/RED attesi prima del refactor: `20260524T022453Z-scan-sync-architecture-*`, `20260524T022453Z-scan-manual-boundary-*`, `20260524T022727Z-ios-test-automatic-architecture-*`.
- Gate finali locali PASS: `20260524T025235Z-scan-*`, `20260524T025239Z-ios-build-debug-*`, `20260524T025251Z-ios-build-release-*`, `20260524T025408Z-ios-test-automatic-domain-*`, `20260524T025433Z-ios-test-sync-*`, `20260524T025706Z-ios-test-automatic-architecture-*`, `20260524T025717Z-ios-smoke-options-*`, `20260524T025800Z-scan-*`, `20260524T025818Z-report-validate-json-*`.

#### Rischi rimasti
- Manual sync e' ancora supportata come boundary esplicito; le scans automatic/manual e `ios test sync` sono verdi, ma non e' stato eseguito un live/manual flow end-to-end in questo turno.
- `HistorySessionSyncService` resta condiviso/retained; non e' stato cancellato perche' la reference scan non autorizza una deletion sicura.
- `SupabaseInventoryService.swift` resta grande e shared remote service; automatic writes sono stretti da protocolli automatic-domain, ma uno split piu' profondo resta follow-up candidate se richiesto.
- Live gates TASK-119 sono NOT_RUN per assenza di autorizzazione `MC_ALLOW_LIVE=1`; non contano come PASS e non sono necessari per il passaggio a local review.
- Cleanup e residue sono NOT_RUN/not required perche' non sono state create righe live sintetiche.

#### Handoff post-execution verso Claude
Stato proposto: `ACTIVE / REVIEW — EXECUTION_COMPLETE_LOCAL_GATES_PASS`.

Reviewer focus:
- Verificare che lo split da `AutomaticPushServices.swift` riduca davvero ownership confusion e non sia solo rename/move.
- Verificare che `AutomaticSyncEngine` sia un core non-UI sufficiente e che il `@MainActor` residuo in `SyncAutomaticRuntime` sia facade/presentation/auth boundary.
- Verificare che il routing TASK-119 di `scan no-full-pull-normal-path` non rompa compatibilita' TASK-117/TASK-118.
- Valutare se il retained shared `HistorySessionSyncService` e `SupabaseInventoryService` richiedano una task successiva o siano accettabili per TASK-119.
- Non marcare DONE senza review approval e senza decisione esplicita sui live/device blocker NOT_RUN.

## Prompt future EXECUTION-AUDIT
Usare questo prompt solo dopo review/approvazione planning:

```text
Esegui TASK-119 in modalita EXECUTION-AUDIT prima di qualunque refactor Swift.

Vincoli:
- verifica HEAD dinamicamente con mc-agent TASK-119;
- usa solo comandi canonici mc-agent quando disponibili;
- aggiungi/migliora prima gli scan TASK-119 mancanti e MCP allowlist;
- non spostare o cancellare Swift finche' sync-architecture, manual-boundary, dead-code e xcode-membership non esistono;
- non eseguire live senza consenso esplicito e MC_ALLOW_LIVE=1;
- non eseguire cleanup senza dry-run, cleanup_plan_id, prefix TASK119_ e MC_ALLOW_CLEANUP=1;
- Supabase contract validation read-only; nessuna migration/schema/RLS/grant/RPC;
- produci evidence sotto docs/TASKS/EVIDENCE/TASK-119/agent-runs/ con .md/.json/.log redatti;
- non dichiarare DONE.
```
