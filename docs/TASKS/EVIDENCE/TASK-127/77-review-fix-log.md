# TASK-127 Review Fix Log

Result: PASS

Fixes applied during review:

1. `OptionsSyncSummaryProvider` now preserves the latest coalesced refresh request and reruns it after the active refresh finishes, avoiding missed pending/history/auth refreshes during an in-flight debounce window.
2. `OptionsPendingAttentionCounter` now uses owner/store/localStore scoped `fetchCount` instead of broad owner-only counting or View array materialization.
3. `OptionsLocalSummaryServiceTests` now covers store-scoped pending attention counting.
4. `OptionsSyncSummaryProviderTests` now covers replay of a coalesced refresh with latest local data.
5. `SlowRemoteCountFetcher` test fake no longer loses early `release()` calls.
6. `OptionsLocalDatabaseSummaryTests` waits for debounced drift refresh state.
7. `ios smoke options-performance` and `task127-final-gates` no longer accept missing UI tap metrics as numeric performance PASS; they require `PASS_WITH_NOTES`.
8. `59-final-performance-comparison.json` now keeps missing UI tap/stall metrics as `null`.

Failed intermediate checks and resolution:

- `ios test options-summary-performance` initially failed because a complex SwiftData predicate exceeded type-check limits. Predicate was simplified and rerun PASS.
- `ios test options-summary-provider` initially failed due a race in the test fake. Fixed and rerun PASS.
- `ios test sync` initially failed because a test asserted before the debounced cached drift update completed. Fixed and rerun PASS.

