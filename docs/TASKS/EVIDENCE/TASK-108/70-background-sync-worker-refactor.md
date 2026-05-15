# TASK-108 — Background sync worker refactor

Date: 2026-05-14 15:25 -0400  
Executor: Codex  
Status: FIX EVIDENCE

## Target tecnico

- Remove CPU-heavy preview/apply/backfill work from the UI `ModelContext`.
- Keep `SupabaseManualSyncViewModel` on `MainActor` only for UI state/progress.
- Use worker-owned `ModelContext` instances created from `ModelContainer`.
- Publish progress to the UI through explicit `MainActor.run` boundaries.
- Avoid View/ViewModel references in worker services.
- Do not use `service_role`, bypass RLS, or log tokens/JWT/raw email.

## Refactor applicato

| Area | Change |
|---|---|
| Preview snapshot | `SupabasePullPreviewService.generatePreview(modelContainer:)` now builds the local snapshot inside `Task.detached` with a new `ModelContext(modelContainer)` |
| Preview adapter | `SupabaseManualSyncPullPreviewAdapter` stores a `ModelContainer`, not the UI `ModelContext` |
| ProductPrice apply | Release adapter captures `context.container` and creates worker `ModelContext` instances for plan/apply instead of retaining the UI context |
| Catalog apply | `SupabaseManualSyncViewModel` runs apply plan/apply/baseline commit in detached workers with background contexts |
| History/session sync | Release adapter creates a background `ModelContext`; `HistorySessionSyncService` no longer carries `@MainActor` isolation for heavy work |
| Baseline commit/read/write | Baseline committer/reader/writer are no longer main-actor-bound so background apply can commit baseline safely |
| Progress publishing | ProductPrice, catalog apply, and history progress publish through `MainActor.run`; progress remains throttled and completion/failure/cancel remain immediate |
| ProductPrice page processing | Page-scoped lookup/apply contexts, page-scoped maps, cancellation checks, timing logs (`fetchMs/applyMs/saveMs`) |
| Snapshot date formatting | Replaced per-row `DateFormatter` with UTC `gmtime_r` formatting in `SwiftDataInventorySnapshotService` |
| Launch backfill | Removed automatic `PriceHistoryBackfillRunner` launch task from `ContentView`; heavy migration/backfill no longer runs from View lifecycle |

## Files changed for the structural fix

- `iOSMerchandiseControl/SwiftDataInventorySnapshotService.swift`
- `iOSMerchandiseControl/SupabasePullPreviewService.swift`
- `iOSMerchandiseControl/SupabaseManualSyncRemotePreview.swift`
- `iOSMerchandiseControl/SupabaseManualSyncReleaseFactory.swift`
- `iOSMerchandiseControl/SupabaseManualSyncViewModel.swift`
- `iOSMerchandiseControl/SupabasePullApplyService.swift`
- `iOSMerchandiseControl/SupabaseProductPriceApplyService.swift`
- `iOSMerchandiseControl/HistorySessionSyncService.swift`
- `iOSMerchandiseControl/SupabaseManualSyncBaselineCommitter.swift`
- `iOSMerchandiseControl/SupabaseCatalogBaselineWriter.swift`
- `iOSMerchandiseControl/SupabaseCatalogBaselineReader.swift`
- `iOSMerchandiseControl/PriceHistoryBackfillService.swift`
- `iOSMerchandiseControl/HistoryEntryRuntimeSummary.swift`
- `iOSMerchandiseControl/ContentView.swift`

## Why no `@ModelActor`

SwiftData `@ModelActor` was considered, but the local project already has service APIs built around explicit `ModelContext` injection and extensive tests/fakes. For this FIX, the lower-risk structural change was:
- pass `ModelContainer` across the release boundary;
- create isolated worker `ModelContext` instances inside detached work;
- keep all UI mutation on `MainActor`;
- avoid broad public API changes and new dependencies.

This still satisfies the requirement that heavy sync work not use the View/UI `ModelContext`.

## Worker result/cancellation behavior

- Existing coordinator result states are preserved: completed, failed, cancelled, partial/needs review through current preview/apply result models.
- `Task.checkCancellation()` remains in ProductPrice page loops.
- Progress callbacks are actor-safe.
- Cancel/failure states are published immediately, not throttled behind progress updates.

## Explicitly not changed

- No Supabase schema, RLS, grants, or RPC changes.
- No client `service_role`.
- No new dependency.
- No public user-facing sync API rewrite beyond moving execution context.
- No automatic destructive cleanup.

## Residual technical notes

- ProductPrice push planning still has some main-actor test-era plumbing in the planner path; it was not the measured launch freeze path and was not expanded in this FIX.
- The removed automatic launch backfill should return only as an explicit/background migration job with its own task/evidence, not as View lifecycle work.

## Verdict

The measured UI freeze path was moved off the UI context, and the second measured lifecycle mutator was removed from launch. Heavy SwiftData sync work is now owned by worker/background contexts instead of View lifecycle/UI `ModelContext`.
