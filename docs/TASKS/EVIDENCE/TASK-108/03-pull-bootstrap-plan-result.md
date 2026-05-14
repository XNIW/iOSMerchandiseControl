# TASK-108 Evidence 03 — Pull Bootstrap Plan Result

Status: EXECUTED (CODE + UNIT), runtime live NOT RUN.

Initial finding:
- Existing coordinator blocks on missing/invalid baseline before remote preview when used with Release dependencies.
- Bootstrap must allow remote preview/apply only when remote preview provider exists and local pending guard is clean.

Runtime result pending.

Result:
- `SupabaseManualSyncCoordinator` now keeps the legacy missing-baseline block when no remote preview provider exists.
- Release/bootstrap path with a remote preview provider can continue through local pending check and remote preview even when the local baseline is missing.
- `SupabaseManualSyncViewModel.applyStagedLocalChanges()` attempts `SupabaseCatalogBaselineWriter.commitAfterSuccessfulFullPullApply` after successful catalog apply and reports baseline commit status in the local apply summary.

Evidence:
- `SupabaseManualSyncCoordinatorTests/testDryRunBaselineMissingBlocks` PASS.
- `SupabaseManualSyncCoordinatorTests/testDryRunBaselineMissingWithRemotePreviewProviderAllowsBootstrapPreview` PASS.
- Live full pull/apply against Supabase dev/test NOT RUN.

FIX/COMPLETION update 2026-05-13:
- Baseline commit moved behind `SupabaseManualSyncLocalApplyBaselineCommitting` / `SupabaseManualSyncLocalApplyBaselineCommitter` to keep ViewModel boundaries clean while preserving successful full-pull baseline writes.
- Full XCTest PASS 659/0 and targeted TASK-108 PASS 26/0 after this refactor.
- Live app-auth full pull remains NOT RUN because no authenticated app session was available; no service_role workaround used.

Targeted Options cleanup FIX update 2026-05-13 20:45 -0400:
- Options now shows signed-out `Accedi` plus public local database status; the simulator local DB is empty (`0` products/suppliers/categories/ProductPrice).
- App-auth reached the Google credential prompt but did not complete sign-in.
- Live bootstrap/full pull remains NOT RUN / BLOCKED_APP_AUTH. Evidence: `23-app-auth-login-options-smoke.md`, `24-live-bootstrap-pull-smoke.md`.

Large ProductPrice bootstrap FIX update 2026-05-13 22:45 -0400:
- Replaced the fixed total ProductPrice preview/apply cap with preview sampling plus paged full-pull apply.
- Preview now samples 1,000 ProductPrice rows and emits `priceHistoryPagedApplyRequired` instead of source-erroring only because the remote history is large.
- Apply downloads ProductPrice in 1,000-row pages and saves SwiftData per page; baseline remains outside the apply service and is written only after catalog + ProductPrice apply return successfully.
- Baseline writer now batches baseline record inserts to avoid one huge SwiftData save after large bootstrap.
- Live app-auth observation after manual login: preview succeeded with 19,888 products / 101 suppliers / 64 categories / 1,000 ProductPrice sample; local store reached 19,886 products and 53,022 ProductPrice rows.
- Full live PASS is NOT claimed: baseline was not written in that first run, and app-auth was not available after rebuild to rerun the fixed batched baseline writer live.
- Evidence: `30-large-price-history-bootstrap.md`.
