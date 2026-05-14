# TASK-108 Evidence 32 — MainActor / Performance Sync Audit

Date: 2026-05-13 23:45 -0400

Goal: reduce UI freezes during sync without moving SwiftData `ModelContext` work across actor boundaries unsafely.

Findings:
- The project uses default MainActor isolation, and SwiftData contexts are UI-owned in the current architecture.
- Moving large SwiftData apply work fully off MainActor would require a larger model-container/background-context refactor outside this FIX pass.
- The safer minimal fix is batching, yielding between batches/pages and surfacing progress so the UI stays responsive.

iOS changes:
- `SupabasePullApplyService.applyBatched(...)` saves/yields every bounded catalog batch and emits supplier/category/product/saving progress.
- `SupabaseProductPriceApplyService.applyPagedFullPull(...)` already paged ProductPrice; this pass adds cooperative yields after page saves/no-op pages.
- `HistorySessionSyncService` push/pull now has progress callbacks and applies remote sessions in bounded batches with `Task.yield()`.
- `SupabaseManualSyncViewModel` maps service progress into a single throttled public progress state for banner/Options/review sheet.

MainActor risk still present:
- Heavy SwiftData mutation still occurs on the current SwiftData context actor. It is now bounded/yielding, not a monolithic loop.
- Legacy `PriceHistoryBackfillRunner` remains MainActor-isolated because the existing SwiftData context is MainActor-owned; it is outside the unified sync orchestrator and should be a future background-context refactor if still visible.

Simulator evidence:
- iOS app launched on `iPhone 15 Pro Max` simulator.
- Root banner displayed `Checking for updates... / Fetching cloud counts...`.
- While cloud check was active, Options scrolling remained responsive and showed progress state plus `Cancel`.
- Screenshot: `screenshots/2026-05-13-ios-root-progress-checking.jpg`.
- Screenshot: `screenshots/2026-05-13-ios-options-progress-scroll.jpg`.

Verification status:
- ✅ STATIC — no new giant sync loop without await/yield was added.
- ✅ BUILD — Debug and Release iOS builds passed.
- ✅ TEST — TASK-108 targeted tests passed.
- ✅ SIM — qualitative scroll smoke passed during cloud count fetch.
- ⚠️ NOT EXECUTABLE — live large authenticated apply jank was not re-run after this pass because app-auth was not available.

## Final live performance update — 2026-05-14 12:34 -0400

The large authenticated ProductPrice apply was rerun after the keyset/error-propagation fixes.

Live observations:
- UI progress stayed visible during full ProductPrice apply.
- Scroll remained responsive while progress advanced from `135,900 / 290,955` to completion.
- No crash occurred.
- No idle-without-completion/error occurred.
- Final Options local status refreshed to `Database locale aggiornato`.

Performance samples:
- `186,802` local ProductPrice rows at 12:12:44, RSS about `2.03 GB`.
- `220,067` rows at 12:16:54, RSS about `2.58 GB`.
- `252,439` rows at 12:21:01, RSS about `2.83 GB`.
- `289,065` rows at 12:26:45, RSS about `3.26 GB`.
- Completed at about 12:33:52 with `328,589` local rows and `290,953` remote-linked rows.

Residual risk:
- The simulator run completed, but RSS peaked above `3 GB`.
- This is acceptable as evidence that the original silent cancellation bug is fixed, but it is not ideal for low-memory devices.
- Recommended follow-up inside TASK-108 review/future performance pass: move ProductPrice full bootstrap to a private/bounded SwiftData context or chunked import strategy that releases inserted objects between pages.
