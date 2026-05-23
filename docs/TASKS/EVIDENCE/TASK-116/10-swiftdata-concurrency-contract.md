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
The apply engine is still physically large. Reviewer may request a follow-up FIX to split helper code into separate Catalog/ProductPrice/History files before DONE.
