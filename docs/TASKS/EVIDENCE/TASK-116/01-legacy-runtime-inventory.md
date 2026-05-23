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

## Severe review/fix delta — 2026-05-23 14:28 -0400
- `HEAD` and `origin/main` were verified equal at `e0a540f6871be474a7f8266f5e5d60f4ca1b7e6f` before this FIX.
- `SyncOrchestrator.submitForegroundTrigger` schedules `automaticRuntime.run(action:source:)`; forbidden `legacyAdapter.startForegroundIncrementalCheckNow` / `legacyAdapter.startForegroundSemiAutomaticCheckIfAllowed` are absent.
- `SyncAutomaticRuntime.swift` does not reference `SupabaseManualSyncViewModel`, `SupabaseManualSyncCompatibilityAdapter`, `SupabaseSyncEventIncrementalApplyService` or `SupabaseManualSyncReleaseFactory`.
- `SyncEventIncrementalPullService.swift` constructs `SyncEventIncrementalDomainApplyService`, not `SupabaseSyncEventIncrementalApplyService`.
- `SyncEventIncrementalDomainApplyService.swift` now exists under `Sync/Incremental` and dispatches to physical `CatalogIncrementalApplyService`, `ProductPriceIncrementalApplyService`, `HistoryIncrementalApplyService`.
- Hardened gate `scan no-legacy-runtime-path` now fails if the physical domain service files are missing or the dispatcher does not reference them.

## Final cleanup classification — 2026-05-23 15:08 -0400
| Use | Classification | Decision |
|---|---|---|
| `SyncAutomaticRuntime.swift` provider dependencies | automatic runtime dependency | Renamed to `SyncCatalogPushProviding`, `SyncProductPriceSyncProviding`, `SyncHistorySessionPushProviding`, `SyncIncrementalPullProviding`, `SyncActivityRegistrationProviding`. No `SupabaseManualSync*Providing` dependency remains in this file. |
| `SyncAutomaticRuntimeProviders.swift` DTO/result boundary | automatic runtime contract | Adds `SyncActivityRegistration*` and `SyncHistorySessionSummary` wrappers so automatic provider protocols expose `Sync*` contracts; legacy DTO conversion is limited to adapter compatibility shims. |
| `SyncCatalogPushAdapter`, `SyncProductPriceAdapter`, `SyncHistorySessionPushAdapter`, `SyncActivityRegistrationAdapter` | automatic/domain adapters | Renamed from `SupabaseManualSyncRelease*Adapter` naming; may still conform to old manual protocols for VM compatibility. |
| `SupabaseManualSyncViewModel` | manual-only facade | Still present for Options/manual UI and explicit manual actions; forbidden as automatic owner. |
| `SupabaseManualSyncCompatibilityAdapter` | manual/root presentation compatibility | Still present to expose manual VM state to root/presentation; no automatic foreground methods. |
| `SupabaseManualSyncReleaseFactory` | manual VM factory | Still composes manual VM dependencies; not automatic runtime composition root. |
| `SupabaseSyncEventIncrementalApplyService` | compat wrapper | Summary/protocol/wrapper only; not constructed by `SyncEventIncrementalPullService`. |
| `HistorySessionSyncService` | retained domain helper | Kept as official history helper behind `HistoryIncrementalApplyService`; not a competing automatic runtime owner. |

Final gate hardening: `scan no-legacy-runtime-path` fails if `SyncAutomaticRuntime.swift` references `SupabaseManualSync*Providing` or `SupabaseManualSyncRelease*Adapter` names.
