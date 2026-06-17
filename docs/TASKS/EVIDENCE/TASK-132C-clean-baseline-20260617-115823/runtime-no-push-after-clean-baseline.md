# Runtime no-push after clean baseline

## Initial clean-baseline no-push

| runtime | sync_events before | sync_events after | result |
|---|---:|---:|---|
| iOS signed-in reopen | 1823 / max 3035 | 1823 / max 3035 | PASS |
| Android signed-in reopen | 1823 / max 3035 | 1823 / max 3035 | PASS |

Evidence:
- iOS before/after: `raw/ios-no-push-sync-events-before.raw`, `raw/ios-no-push-sync-events-after.raw`.
- Android before/after: `raw/android-no-push-sync-events-before.raw`, `raw/android-no-push-sync-events-after.raw`.
- Android log filter: `raw/android-no-push-logcat-filtered.txt`.

## Final no-push after TASK-133 cleanup

| runtime | sync_events before | sync_events after | result |
|---|---:|---:|---|
| iOS signed-in reopen 95s | 1823 / max 3035 | 1823 / max 3035 | PASS |
| Android signed-in reopen 95s | 1823 / max 3035 | 1823 / max 3035 | PASS |

Evidence:
- iOS before/after: `../TASK-133/performance-20260617-130313/raw/final-ios-no-push-sync-events-before.raw`, `../TASK-133/performance-20260617-130313/raw/final-ios-no-push-sync-events-after.raw`.
- Android before/after: `../TASK-133/performance-20260617-130313/raw/final-android-no-push-sync-events-before.raw`, `../TASK-133/performance-20260617-130313/raw/final-android-no-push-sync-events-after.raw`.
- Android log filter: `../TASK-133/performance-20260617-130313/raw/final-android-no-push-logcat-filtered.txt`.

Result:
- No unexpected push was observed on clean signed-in reopen.
- Android logs show `automatic_push_safety_guard`, `syncEventOutboxInserted=0`, `catalogEventOutcome=no_op`, and `priceEventOutcome=no_op`.
- Final screenshots: `../TASK-133/performance-20260617-130313/screenshots/final-ios-options.png`, `../TASK-133/performance-20260617-130313/screenshots/final-android-options.png`.

