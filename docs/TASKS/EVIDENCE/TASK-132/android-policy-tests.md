# TASK-132 Android Policy Tests

## Commands

```bash
./gradlew testDebugUnitTest --tests 'com.example.merchandisecontrolsplitview.data.CatalogAutoSyncCoordinatorTest'
```

Result: PASS.

```bash
./gradlew assembleDebug lintDebug
```

Result: PASS.

## Coverage

- Automatic push is blocked by `automatic_push_safety_guard`.
- Auth signed-in schedules bootstrap but not immediate push.
- Network and local catalog changes do not auto-push while guard is active.
- Sync-event drain tests remain separate from the auto-push guard.
