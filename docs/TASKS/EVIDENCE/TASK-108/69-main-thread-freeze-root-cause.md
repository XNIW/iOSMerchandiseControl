# TASK-108 — Main thread freeze root cause

Date: 2026-05-14 15:25 -0400  
Executor: Codex  
Status: FIX EVIDENCE

## Preflight

| Area | Evidence |
|---|---|
| iOS branch / HEAD | `main` / `74480c20c654a07174ba99dede2458d914426ab2` |
| Android branch / HEAD | `main` / `7cfc536b7200a7e2e4a2224800650d2e0b7f7ac0` |
| iOS worktree | Dirty before this FIX: prior TASK-108 Swift changes, tracking, evidence |
| Android worktree | Dirty before this FIX: ProductPrice page streaming and tracking changes already present |
| Supabase workspace | `/Users/minxiang/Desktop/MerchandiseControlSupabase` is not a git repo |
| Supabase live | MCP project `jpgoimipbothfgkokyvm` / `merchandisecontrol-dev`, Postgres `17.6.1.104`, `ACTIVE_HEALTHY` |
| Simulator | iPhone 15 Pro Max iOS 26.1 booted (`459C668B-7CE8-443B-BAB3-7D3D5FFC9143`) |
| Device fisico | iPhone offline |
| Android device tooling | `adb` not found in PATH |

## Reproduction before structural fix

Run:
- Debug `build_run_sim` with `-TASK108ThreadFreezeProbe 1`, pid `82337`, warnings `0`.
- During launch/foreground auto-check, tried tab taps while cloud banner/check was active.
- Captured `sample 82337 5 -file /tmp/task108-before.sample.txt`.

Observed:
- First Options tab tap pair took about `3.6s` wall time and did not switch tab immediately.
- CPU was observed at `100%`.
- RSS grew from about `1.45GB` to about `2.18GB`, later settling around `1.77GB`.
- This reproduced the user symptom: tab taps were queued while the sync/check path was active.

Profiler root cause:
- Main thread was executing:
  - `ContentView.startRootForegroundCheckIfAllowed`
  - `SupabaseManualSyncForegroundRootHost`
  - `SupabaseManualSyncViewModel.startForegroundSemiAutomaticCheckIfAllowed`
  - `SupabaseManualSyncCoordinator.run`
  - `SupabaseManualSyncPullPreviewAdapter.loadRemotePreviewSummary`
  - `SupabasePullPreviewService.generatePreview(context:)`
  - `SwiftDataInventorySnapshotService.makeSnapshot()`
- The hot loop was local SwiftData snapshot generation over ProductPrice/current price state.
- A large fraction of samples were inside `canonicalDateString`, which created `DateFormatter` repeatedly for ProductPrice rows.

Conclusion:
- The immediate UI freeze was not only progress spam.
- Auto-check preview was doing CPU-heavy SwiftData snapshot work on the UI `ModelContext` / main actor path.
- `DateFormatter` per ProductPrice row multiplied the cost enough to make tab taps visibly queue.

## Second blocker found after first worker patch

After moving preview snapshot to a background context, a second launch-time CPU blocker appeared in `/tmp/task108-after.sample.txt`:

- `ContentView.schedulePriceHistoryBackfillIfNeeded()`
- `PriceHistoryBackfillRunner.runIfNeeded()`
- `PriceHistoryBackfillService.backfillIfNeeded(context:)`

The backfill runner used `MainActor.run` and the UI `ModelContext`, then scanned ProductPrice/current price state during app launch.

Conclusion:
- There were two launch/foreground lifecycle mutators competing with the UI:
  1. sync preview local snapshot on UI context;
  2. automatic price-history backfill on UI context.
- The prior mitigations (`yield`, progress throttling, 700 ms delay) could reduce symptoms but could not remove this structural cause.

## Function classification from audit

| Function/file | Classification | Before FIX actor/context | Risk found |
|---|---|---|---|
| `SwiftDataInventorySnapshotService.makeSnapshot()` | SwiftData read / preview local snapshot | UI `ModelContext` via preview adapter | CPU-heavy ProductPrice scan and date formatting on main |
| `SupabasePullPreviewService.generatePreview(context:)` | network fetch + local snapshot | `@MainActor` entry with UI context | Combined remote preview and local snapshot on UI path |
| `SupabasePullApplyService.applyBatched` | catalog SwiftData write | `@MainActor` service with UI context | catalog apply/save on UI actor |
| `SupabaseProductPriceApplyService.applyPagedFullPull` | ProductPrice fetch/decode/apply/save | adapter passed UI context; service was main-actor constrained by protocol path | large apply/save could run on UI context |
| `HistorySessionSyncService.pullHistorySessionsFromCloud` | history/session fetch/apply/save | methods `@MainActor`, UI context from release adapter | history/session apply/save on UI actor |
| `SupabaseManualSyncViewModel.applyStagedLocalChanges` | orchestration/progress UI | `@MainActor` | mixed UI state and heavy apply planning |
| `SupabaseManualSyncReleaseFactory` adapters | release bridge | captured UI `ModelContext` | central source of UI-context leaks into sync |
| `ContentView.schedulePriceHistoryBackfillIfNeeded` | lifecycle mutative backfill | launch `.task`, `MainActor.run`, UI context | second measured launch CPU blocker |
| `OptionsView` / root foreground | UI/lifecycle trigger | View lifecycle starts checks | trigger was allowed to start costly work during first interaction window |

## Raw evidence artifacts

- Before profile copied to `docs/TASKS/EVIDENCE/TASK-108/profiles/2026-05-14-before-main-freeze.sample.txt`.
- Intermediate profile copied to `docs/TASKS/EVIDENCE/TASK-108/profiles/2026-05-14-after-worker-pre-backfill.sample.txt`.

## Verdict

Root cause confirmed:
- Main-thread SwiftData snapshot during auto-check preview.
- Per-row `DateFormatter` creation inside the ProductPrice snapshot loop.
- Automatic launch price-history backfill using `MainActor.run` and UI `ModelContext`.

This was a structural MainActor/UI-context problem, not just a progress-update problem.
