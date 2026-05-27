# TASK-127 Review Code Quality

Result: PASS_WITH_NOTES

Review findings fixed directly:

- Pending count was owner-scoped but not store/local-store-scoped. Fixed `OptionsPendingAttentionCounter` to use scoped SwiftData `fetchCount` without materializing arrays.
- Summary refresh coalescing counted in-flight events but discarded the follow-up refresh. Fixed by retaining the latest pending refresh request and rerunning after the active refresh finishes.
- Provider test fake remote fetcher could miss `release()` before continuation registration. Fixed the test actor to be deterministic.
- Existing drift cached-snapshot test asserted synchronously after a debounced refresh. Fixed the test to wait for the updated local drift report.

Notes:

- The implementation still uses a MainActor presenter with `fetchCount`-based summary work rather than a fully separate background summary service. Review accepts this as a scoped TASK-127 hardening because the heavy ProductPrice full fetch/filter and View `@Query` materialization path are removed, first render is not blocked by synchronous refresh, and follow-up evidence gates pass.
- Legacy pending rows with nil store/localStore are not counted by the hot Options attention counter after review hardening. New `LocalPendingChange` rows are normalized with store identity at creation time; this is safer than over-counting cross-store rows in Options.

