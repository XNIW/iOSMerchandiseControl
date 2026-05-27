# TASK-127 Evidence 11 - iOS Main Thread Stall Profile

The pre-fix profile is static plus XCTest-backed:

- `OptionsView` materialized all `LocalPendingChange` rows through `@Query`.
- `OptionsSyncSummaryProvider` refreshed summary synchronously on `@MainActor`.
- `LocalDatabasePublicSummary.makeReconciliationAware` performed ProductPrice full fetch plus relationship filtering.

The post-fix path schedules summary refresh after a short debounce, uses count queries, and avoids `@Query` in `OptionsView`.

