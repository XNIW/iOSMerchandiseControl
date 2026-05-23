# 03 - Legacy File Classification

## Categories
- `DELETE_IN_EXECUTION`
- `MOVE_TO_SYNC_DOMAIN`
- `KEEP_MANUAL_ONLY`
- `KEEP_DEBUG_HARNESS_ONLY`
- `KEEP_DOMAIN_SERVICE_RENAMED`
- `UNKNOWN_REQUIRES_AUDIT`

No file is deleted during planning.

## Classification
| File | Classification | Reason / future proof required |
|---|---|---|
| `SupabaseManualSyncViewModel.swift` | `KEEP_MANUAL_ONLY` | Keep only for explicit manual facade until replacement exists; forbidden in automatic path. |
| `Sync/SupabaseManualSyncCompatibilityAdapter.swift` | `DELETE_IN_EXECUTION` | Automatic path must not use compatibility bridge; delete if manual boundary no longer needs it. |
| `SupabaseManualSyncReleaseFactory.swift` | `KEEP_MANUAL_ONLY` | Manual composition root only after extracting shared automatic adapters. |
| `SupabaseManualSyncCoordinator.swift` | `KEEP_MANUAL_ONLY` | Manual run coordinator; not automatic owner. |
| `SupabaseManualSyncCoordinating.swift` | `KEEP_MANUAL_ONLY` | Manual abstraction/test doubles only. |
| `SupabaseManualSyncCoordinatorModels.swift` | `KEEP_MANUAL_ONLY` | Manual run DTOs only. |
| `SupabaseManualSyncSemiAutomaticPolicy.swift` | `KEEP_MANUAL_ONLY` | Manual/semi-automatic legacy naming must not drive automatic runtime. |
| `SupabaseManualSyncLifecycleRunGate.swift` | `KEEP_MANUAL_ONLY` | Manual lifecycle gate only; automatic runtime must have its own clean gate. |
| `SupabaseManualSyncAggregatedPushOutboxProducer.swift` | `MOVE_TO_SYNC_DOMAIN` | Outbox production belongs under `Sync/Outbox` with non-manual naming. |
| `SupabaseManualSyncLocalPendingSnapshotProvider.swift` | `KEEP_MANUAL_ONLY` | Manual UI snapshot provider; automatic pending/outbox uses domain stores. |
| `SupabaseManualSyncBaselineCommitter.swift` | `MOVE_TO_SYNC_DOMAIN` | Baseline commit can be domain/shared, but naming must be cleaned after proof. |
| `SupabaseSyncEventIncrementalApplyService.swift` | `UNKNOWN_REQUIRES_AUDIT` | Do not pre-classify. Execution must prove wrapper/domain/dead role via call graph and tests. |
| `SupabasePullApplyService.swift` | `UNKNOWN_REQUIRES_AUDIT` | Do not pre-classify. Execution must prove full-only helper vs domain service vs legacy. |
| `SupabaseProductPriceApplyService.swift` | `UNKNOWN_REQUIRES_AUDIT` | Do not pre-classify. Execution must prove bootstrap/full helper vs incremental domain role. |
| `SupabaseProductPriceManualPushService.swift` | `MOVE_TO_SYNC_DOMAIN` | Push implementation may be domain, but manual naming/result coupling must be removed from automatic contracts. |
| `HistorySessionSyncService.swift` | `UNKNOWN_REQUIRES_AUDIT` | Do not pre-classify. Execution must prove helper/domain/dead role via tests and automatic call graph. |
| `AutomaticSyncReconnectScheduler.swift` | `MOVE_TO_SYNC_DOMAIN` | Keep only if single owner is proven; otherwise replace with clean orchestrator-owned scheduler. |
| `CloudSyncOverviewState.swift` | `MOVE_TO_SYNC_DOMAIN` | Presentation state can remain if observer-only and no manual runtime coupling. |
| root-level `SyncEventOutbox*` | `MOVE_TO_SYNC_DOMAIN` | Move production stores/services under `Sync/Outbox`; debug view models remain debug-only. |
| root-level `SyncEventRecording*` | `MOVE_TO_SYNC_DOMAIN` | Recorder protocol/service belongs to sync domain; no manual naming. |
| `SyncEventOutboxDrainDebugViewModel.swift` | `KEEP_DEBUG_HARNESS_ONLY` | Debug/harness UI only; no Release automatic path dependency. |

## Rule
`KEEP_DOMAIN_SERVICE_RENAMED` is allowed only after execution proves the file is a real domain service with source/call-graph checks and regression tests.
