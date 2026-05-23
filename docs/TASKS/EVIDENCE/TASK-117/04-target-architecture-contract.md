# 04 - Target Architecture Contract

## Automatic path contract
- `SyncOrchestrator` is the only automatic owner.
- `SyncOrchestrator` owns/schedules foreground, realtime, reconnect and local mutation triggers through one serialized path.
- Automatic path uses `SyncAction`, `SyncTrigger`, domain services and clean provider contracts only.
- Automatic path must not reference `SupabaseManualSync*`, `ManualPushPlan`, `SupabaseManualPushResult`, `ProductPriceManualPushResult`, `SupabaseSyncEventIncrementalApplySummary`, or manual root/banner DTOs.

## UI contract
- `ContentView.swift` hosts app-level lifecycle only and does not construct manual sync VM/factory/adapter/root host.
- `OptionsView.swift` observes cached/presenter state only and does not decide automatic sync, start foreground/realtime/reconnect, or perform decision-heavy remote fetches.
- Root banner is compact, native iOS, reduced-motion aware and does not show spinner 0/0.
- Public UI has no duplicate sync CTA.
- Blocked/auth/retry states are clear in IT/EN/ES/ZH.
- "Up to date" is shown only after recent account/store-bound verification.
- Dynamic Type and VoiceOver smoke are required in execution.

## Manual sync boundary
- Manual sync is allowed only as explicit user action.
- Manual sync lives under `Sync/Manual` or `ManualSync`.
- Manual sync can use manual DTOs internally, but no normal automatic path imports or references those types.

## Full pull policy
Full pull is allowed only for:
- bootstrap;
- full recovery;
- explicit manual sync;
- harness/test path.

Full pull is forbidden for:
- foreground normal check;
- timer/safety loop;
- realtime event drain;
- reconnect;
- local mutation auto push.

## Strict scans to implement/enforce
- Fail if `ContentView.swift` contains `SupabaseManualSyncForegroundRootHost`, `SupabaseManualSyncCompatibilityAdapter`, `SupabaseManualSyncReleaseFactory`, or `SupabaseManualSyncViewModel`.
- Fail if `SyncOrchestrator.swift` contains `legacyAdapter`, `legacyManualSyncViewModel`, `SyncOrchestratorLegacySyncAdapter`, or `SupabaseManualSync*` in the automatic path.
- Fail if `SyncAutomaticRuntime.swift` or `SyncAutomaticRuntimeProviders.swift` expose automatic contracts using `ManualPushPlan`, `SupabaseManualPushResult`, `ProductPriceManualPushResult`, `SupabaseManualSyncActivityRegistration*`, `SupabaseManualSyncHistorySessionSummary`, or `SupabaseSyncEventIncrementalApplySummary`.
- Fail if foreground/realtime/reconnect/localMutation can reach full pull.
- Fail if `OptionsView` performs decision-heavy remote fetch instead of observing presenter/provider cache.
- Fail if two timers/watchers/safety loops can trigger sync concurrently.
- Fail if scans are naming-only and do not inspect source/call graph.
