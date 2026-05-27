# TASK-127 Evidence 20 - iOS Fix Design

Implemented a small Options-specific hardening:

- `OptionsView` no longer owns an unscoped `@Query` for pending changes.
- `OptionsSyncSummaryProvider` publishes loading/stale/cache metadata.
- Summary refresh is debounced and single-flight.
- ProductPrice count uses `fetchCount` instead of full fetch/filter.
- Pending attention count uses scoped `fetchCount`.
- Remote drift remains non-blocking after local summary publishes.

