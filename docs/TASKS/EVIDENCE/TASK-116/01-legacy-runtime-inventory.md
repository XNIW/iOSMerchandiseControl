# TASK-116 Legacy Runtime Inventory

Generated during S116-B preflight/inventory on 2026-05-23.

## Static call graph findings
- `ContentView.swift` constructs `SyncOrchestrator` with `SupabaseManualSyncCompatibilityAdapter(viewModel: SupabaseManualSyncReleaseFactory.makeViewModel(...))`.
- `SyncOrchestrator.swift` uses `legacyAdapter` for automatic foreground execution and busy state.
- `SupabaseManualSyncCompatibilityAdapter.swift` forwards automatic calls to `SupabaseManualSyncViewModel`.
- `SupabaseManualSyncReleaseFactory.swift` wires `SyncEventIncrementalPullService` into the manual VM dependency graph.
- `SyncEventIncrementalPullService.swift` calls `SupabaseSyncEventIncrementalApplyService.applyNextEvents`.
- `SupabaseSyncEventIncrementalApplyService.swift` is currently the real monolithic incremental event apply owner.
- Options still receives and observes the manual VM for manual sync cards.

## File classification
| File | Current role | TASK-116 classification | Reason |
|---|---|---|---|
| `SupabaseManualSyncViewModel.swift` | Manual + automatic workhorse | KEEP_MANUAL_ONLY then DEPRECATE_AFTER_EXTRACTION | Must leave normal automatic path; may remain for explicit manual UI until replaced. |
| `SupabaseManualSyncCompatibilityAdapter.swift` | Orchestrator bridge to VM | KEEP_MANUAL_ONLY or DELETE | Adapter is forbidden in final automatic path. |
| `SupabaseManualSyncReleaseFactory.swift` | VM composition root | KEEP_MANUAL_ONLY | Cannot be automatic composition root after TASK-116. |
| `SupabaseSyncEventIncrementalApplyService.swift` | Monolithic incremental apply owner | DEPRECATE_AFTER_EXTRACTION | Domain apply logic must move under `Sync/Incremental`. |
| `SyncEventIncrementalPullService.swift` | Pass-through incremental pull provider | KEEP_DOMAIN_SERVICE | Must become fetch/dispatch/watermark owner. |
| `SupabasePullApplyService.swift` | Full pull apply | KEEP_DOMAIN_SERVICE | Allowed for bootstrap/recovery/manual/harness, not foreground normal. |
| `SupabaseProductPriceApplyService.swift` | Price apply/full pull helper | KEEP_DOMAIN_SERVICE | Reuse or wrap for price domain without main-thread full scan. |
| `SupabaseProductPriceManualPushService.swift` | Manual/price push helper | KEEP_MANUAL_ONLY initially | Automatic push should move to outbox services. |
| `HistorySessionSyncService.swift` | History push/pull/apply helper | KEEP_DOMAIN_SERVICE | Incremental facade should live under `Sync/Incremental`. |
| `SyncEventRecording.swift` | RPC recording contract | MOVE_TO_SYNC / KEEP_DOMAIN_SERVICE | Recorder is part of domain outbox runtime. |
| `SyncEventOutboxEntry.swift` | SwiftData outbox model/store | MOVE_TO_SYNC / KEEP_DOMAIN_SERVICE | Needs owner-bound automatic drain. |
| `LocalPendingChange.swift` | Local pending model/accumulator | KEEP_DOMAIN_SERVICE | Must remain owner-bound and no cross-account leakage. |
| `AutomaticSyncReconnectScheduler.swift` | Reconnect trigger scheduler | KEEP_DOMAIN_SERVICE | Allowed only if orchestrator is single owner. |
| `CloudSyncOverviewState.swift` | Presentation state reducer | KEEP_DOMAIN_SERVICE | Presentation helper; not automatic runtime owner. |

## Immediate stop conditions
- Automatic path still calls `legacyAdapter.startForeground*`.
- `SyncEventIncrementalPullService` remains pass-through to `SupabaseSyncEventIncrementalApplyService`.
- Any foreground/timer/realtime/local mutation path calls `FULL_PULL`.
- Options or ContentView makes sync decisions or remote fetches as source of truth.
