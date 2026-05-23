# SwiftData / Concurrency Contract

## Implemented
- `SyncAutomaticRuntime` is `@MainActor` only for trigger ownership, auth snapshot and UI-safe diagnostics.
- Existing apply/push providers continue to use background `ModelContext` or detached utility work where already implemented.
- `SyncEventIncrementalPullService` delegates to `SyncEventIncrementalDomainApplyService`, whose catalog/price/history work remains background-context based.
- Automatic runtime supports cancellation and no longer starts VM automatic foreground tasks.

## Evidence
- Debug build PASS: `agent-runs/20260523T162939Z-ios-build-debug-task-TASK-116-p20511.md`
- Sync tests PASS: `agent-runs/20260523T162955Z-ios-test-sync-task-TASK-116-p21120.md`
- Performance budget PASS after stale-window fix: `agent-runs/20260523T162552Z-live-sync-performance-budget-task-TASK-116-prefix-TASK116_PERF_-p15267.md`

## Residual review point
The apply engine is now physically split into Catalog/ProductPrice/History service files plus shared helper functions. Remaining review risk is testability granularity: the canonical sync suite now runs existing ProductPrice apply and HistorySession tests, but direct fake-inventory tests for each incremental service are still limited by the concrete `SupabaseInventoryService` actor boundary. Do not treat this as DONE evidence for live/device/account criteria.

## Review rerun update — 2026-05-23 15:54 -0400
- `OptionsSyncSummaryProvider` no longer cancels/restarts remote count checks on every local refresh while the remote snapshot is fresh; it reuses the last remote count for 60s, recomputes local drift from current SwiftData counts, and guards in-flight fetches.
- Regression test PASS in `OptionsLocalDatabaseSummaryTests` via `ios test sync` `agent-runs/20260523T194020Z-ios-test-sync-task-TASK-116-p53802.md`.
- Debug/Release build PASS on the same review fix: `agent-runs/20260523T194331Z-ios-build-debug-task-TASK-116-p54844.md`, `agent-runs/20260523T194338Z-ios-build-release-task-TASK-116-p55368.md`.
