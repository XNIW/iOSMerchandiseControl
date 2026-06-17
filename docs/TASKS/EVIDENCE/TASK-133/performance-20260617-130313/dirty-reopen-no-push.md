# Dirty/protected reopen no-push

Status: NOT_RUN / REVIEW_REQUIRED for dirty/protected fixture.

Clean reopen no-push result:

| runtime | sync_events before | sync_events after | result |
|---|---:|---:|---|
| iOS signed-in reopen 95s | 1823 / max 3035 | 1823 / max 3035 | PASS |
| Android signed-in reopen 95s | 1823 / max 3035 | 1823 / max 3035 | PASS |

Evidence:
- iOS before/after: `raw/final-ios-no-push-sync-events-before.raw`, `raw/final-ios-no-push-sync-events-after.raw`.
- Android before/after: `raw/final-android-no-push-sync-events-before.raw`, `raw/final-android-no-push-sync-events-after.raw`.
- Android log: `raw/final-android-no-push-logcat-filtered.txt`.

Reason this is not full TASK-133 PASS:
- No controlled unsafe local dirty/protected fixture was injected after cleanup.
- Therefore clean no-push is PASS, dirty/protected no-push remains NOT_RUN.

