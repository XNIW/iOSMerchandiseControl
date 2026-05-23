# TASK-117 - Legacy Dependency Map

Date: 2026-05-23 17:48:36 -0400

## Classification
| File / family | Classification | Execution outcome |
|---|---:|---|
| `SupabaseManualSyncViewModel.swift` | KEEP_MANUAL_ONLY | Not referenced by `ContentView`, `OptionsView`, `SyncOrchestrator`, runtime/providers automatic path. |
| `SupabaseManualSyncCompatibilityAdapter.swift` | DELETE_IN_EXECUTION | Deleted; no remaining call sites. |
| `SupabaseManualSyncReleaseFactory.swift` | KEEP_MANUAL_ONLY | Still builds manual VM; automatic runtime factory does not use it. |
| `SupabaseManualSyncCoordinator*` | KEEP_MANUAL_ONLY | Retained for explicit manual boundary. |
| `SupabaseManualSyncSemiAutomaticPolicy.swift` | KEEP_MANUAL_ONLY | Not used by `SyncOrchestrator` automatic triggers. |
| `SupabaseManualSyncLifecycleRunGate.swift` | KEEP_MANUAL_ONLY | Manual VM lifecycle only. |
| `SupabaseManualSyncAggregatedPushOutboxProducer.swift` | KEEP_MANUAL_ONLY | Used inside manual adapter boundary for telemetry/pending state, not automatic owner. |
| `SupabaseManualSyncLocalPendingSnapshotProvider.swift` | KEEP_MANUAL_ONLY | Manual coordinator dependency. |
| `SupabaseManualSyncBaselineCommitter.swift` | KEEP_MANUAL_ONLY | Manual/full apply boundary. |
| `SupabaseSyncEventIncrementalApplyService.swift` | KEEP_DEBUG_HARNESS_ONLY | Compatibility wrapper over clean domain summary; automatic path calls `SyncEventIncrementalPullService`. |
| `SupabasePullApplyService.swift` | KEEP_MANUAL_ONLY | Full pull/manual apply boundary; not reachable from normal root/timer/realtime/local mutation path. |
| `SupabaseProductPriceApplyService.swift` | KEEP_MANUAL_ONLY | Full apply/manual bootstrap/recovery helper; automatic incremental uses domain apply services. |
| `HistorySessionSyncService.swift` | KEEP_DOMAIN_SERVICE_RENAMED | Domain helper for history push/pull; automatic runtime uses `SyncHistorySessionPushAdapter` for incremental push. |
| `AutomaticSyncReconnectScheduler.swift` | MOVE_TO_SYNC_DOMAIN | Retained as reconnect helper owned only by `SyncOrchestrator`. |
| `CloudSyncOverviewState.swift` | KEEP_MANUAL_ONLY | Shared presentation/progress structs; public Options automatic card no longer owns manual VM. |
| root `SyncEventOutbox*` / `SyncEventRecording*` | MOVE_TO_SYNC_DOMAIN | Automatic activity registration uses clean `SyncActivityRegistrationProviding`; outbox ownership remains domain-side. |

