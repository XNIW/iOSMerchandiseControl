# TASK-118 Execution Audit

Generated during Codex execution on 2026-05-23 before Swift implementation.

## HEAD / Preflight

- `./tools/agent/mc-agent.sh git head-consistency --task TASK-118`: PASS.
- `./tools/agent/mc-agent.sh preflight --require-head-consistency --task TASK-118`: PASS.
- Local HEAD, `origin/main`, `git ls-remote origin main`, and GitHub rendered `main` all resolve to `315c2f1d6e8e31a3821d39d9584dd9737388d5d5`.
- Branch: `main`.
- Dirty state before Swift implementation is limited to TASK-118 harness/tracking/evidence files.

## Current Automatic Runtime Call Graph

```text
iOSMerchandiseControlApp
-> ContentView
-> AppSyncRootHost
-> SyncAutomaticRuntimeFactory.make
-> SyncAutomaticRuntime
-> SyncOrchestrator
-> SyncDecisionEngine
-> SyncStateStore
```

Current runtime providers:

```text
SyncAutomaticRuntime
-> SyncCatalogPushAdapter
   -> SupabaseManualPushService
   -> manual push DTO/result boundary
-> SyncProductPriceAdapter
   -> SupabaseProductPriceManualPushService/result boundary
-> SyncHistorySessionPushAdapter
   -> HistorySessionSyncService
-> SyncActivityRegistrationAdapter
   -> SyncEventRecording
-> SyncEventIncrementalPullService
   -> SupabaseInventoryService
   -> incremental apply services
```

## Root Sync Wiring

Root wiring currently lives in:

- `iOSMerchandiseControl/ContentView.swift`
- `iOSMerchandiseControl/iOSMerchandiseControlApp.swift`

The stale planning symbol `AppSyncRootHost` maps to the nested root host in `ContentView.swift`.

## Automatic Files Contaminated By Manual Boundary

- `iOSMerchandiseControl/ContentView.swift`: owns and forwards `SupabaseManualPushService?` into automatic runtime/options wiring.
- `iOSMerchandiseControl/iOSMerchandiseControlApp.swift`: constructs `SupabaseManualPushService` as an app dependency used by automatic wiring.
- `iOSMerchandiseControl/Sync/SyncAutomaticRuntime.swift`: factory accepts `SupabaseManualPushService?` and constructs `SyncCatalogPushAdapter`.
- `iOSMerchandiseControl/Sync/SyncAutomaticRuntimeProviders.swift`: missing automatic plan/run-result types; provider protocols still actor-bound for non-UI work.
- `iOSMerchandiseControl/Sync/SyncEventOutboxEnqueueService.swift`: automatic outbox file contains conversion functions from manual push result types.
- `iOSMerchandiseControl/AutomaticSyncReconnectScheduler.swift`: automatic scheduler imports debounce from `SupabaseManualSyncSemiAutomaticPolicy`.
- `iOSMerchandiseControl/OptionsView.swift`: Options status card builds `CloudSyncProgressState.idle()` instead of reading runtime state.

## Manual-Only Files To Keep Isolated

- `iOSMerchandiseControl/SupabaseManualSyncViewModel.swift`
- `iOSMerchandiseControl/SupabaseManualSyncCoordinator.swift`
- `iOSMerchandiseControl/SupabaseManualSyncCoordinating.swift`
- `iOSMerchandiseControl/SupabaseManualSyncReleaseFactory.swift`
- `iOSMerchandiseControl/SupabaseManualSyncReleaseActivityRegistrationAdapter.swift`
- `iOSMerchandiseControl/SupabaseManualPushService.swift`
- `iOSMerchandiseControl/SupabaseProductPriceManualPushService.swift`
- `iOSMerchandiseControl/SupabasePushPreflightViewModel.swift`

## Files Expected To Change

- `iOSMerchandiseControl/ContentView.swift`
- `iOSMerchandiseControl/iOSMerchandiseControlApp.swift`
- `iOSMerchandiseControl/OptionsView.swift`
- `iOSMerchandiseControl/Sync/SyncAutomaticRuntime.swift`
- `iOSMerchandiseControl/Sync/SyncAutomaticRuntimeProviders.swift`
- `iOSMerchandiseControl/Sync/SyncOrchestrator.swift`
- `iOSMerchandiseControl/Sync/SyncState.swift`
- `iOSMerchandiseControl/Sync/SyncStateStore.swift`
- `iOSMerchandiseControl/Sync/SyncDecisionEngine.swift`
- `iOSMerchandiseControl/AutomaticSyncReconnectScheduler.swift`
- `iOSMerchandiseControl/AutomaticSyncNetworkReachabilityObserver.swift`
- new automatic-domain push/provider files under `iOSMerchandiseControl/Sync/`
- new or updated XCTest coverage under `iOSMerchandiseControlTests/`
- harness selectors if new test classes are added to `ios test automatic-domain`

## Test Gaps

- `ios test sync` remains a broad regression suite and still includes manual sync tests.
- TASK-118 needs targeted automatic-domain tests for runtime result semantics, decision snapshots, no manual DTO/service leakage, provider behavior, and Options summary observer-only behavior.
- Initial strict scans are FAIL as an expected baseline until the Swift split is implemented.

## Harness Gaps

- TASK-118 harness foundation exists and produced evidence for head consistency, preflight, config validation, scans, and evidence scans.
- The automatic-domain test command exists, but selectors may need to be extended for new TASK-118 XCTest classes.
- JSON validation and final smoke/build/test evidence are still NOT_RUN at this audit point.

## SwiftData / Concurrency Risks

- Current automatic runtime and several provider protocols are `@MainActor`; TASK-118 requires background-safe domain services where work can use `ModelContainer` and fresh `ModelContext`.
- Existing manual adapters mix UI/main-context assumptions with sync work and must not remain on the automatic runtime path.
- Outbox, pending change snapshots, and incremental apply services need careful actor isolation to avoid using UI `ModelContext` for background automatic work.

## Xcode Project / File Move Risk

- The project uses a PBX file list. New Swift files or moved manual conversions may need project membership updates.
- Moving manual-only code should preserve buildability for explicit manual sync tests and UI harnesses.

## Supabase / Live Prerequisites

- No Supabase mutation was performed during this audit.
- Live gates require redacted status evidence and explicit live safety enablement before `live sync-matrix`.
- If live auth/session/device prerequisites are unavailable, the gate must be marked `BLOCKED_EXTERNAL` with concrete prerequisite details.
