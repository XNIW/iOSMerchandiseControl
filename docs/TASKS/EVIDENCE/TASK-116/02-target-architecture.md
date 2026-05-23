# Target Architecture Evidence

## Implemented automatic path
```text
SwiftUI lifecycle/notifications
-> SyncOrchestrator
-> SyncDecisionEngine
-> SyncAutomaticRuntime
-> catalog/product-price/history push providers
-> SyncEventIncrementalPullService
-> SyncEventIncrementalDomainApplyService
-> WatermarkStore / AccountBindingStore
```

## Boundary changes
- `SyncOrchestrator` no longer calls `SupabaseManualSyncCompatibilityAdapter.startForeground*`.
- `SupabaseManualSyncCompatibilityAdapter` no longer exposes automatic foreground methods.
- `ContentView` injects `SyncAutomaticRuntimeFactory.make(...)` into `SyncOrchestrator`.
- `SupabaseManualSyncViewModel` remains available to Options/manual UI as manual facade only.
- `SyncEventIncrementalPullService` no longer constructs `SupabaseSyncEventIncrementalApplyService`; it calls `SyncEventIncrementalDomainApplyService`.

## Static gate evidence
- Initial fail before refactor: `agent-runs/20260523T161514Z-scan-no-legacy-runtime-path-task-TASK-116-p2324.md`
- PASS after refactor: `agent-runs/20260523T162330Z-scan-no-legacy-runtime-path-task-TASK-116-p12027.md`
- Live wrapper PASS: `agent-runs/20260523T162330Z-live-no-legacy-runtime-path-task-TASK-116-p12026.md`
- No full pull normal path PASS: `agent-runs/20260523T162340Z-live-no-full-pull-normal-path-task-TASK-116-p13232.md`

## Residual manual facade
`SupabaseManualSyncReleaseFactory`, `SupabaseManualSyncViewModel` and `SupabaseManualSyncCompatibilityAdapter` remain for manual presentation/actions. They are no longer the automatic execution path owner.
