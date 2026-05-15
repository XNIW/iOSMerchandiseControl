# TASK-108 Evidence 56 - Android sync performance profile

Timestamp: 2026-05-14 13:23 -0400  
Device: OnePlus IN2013, serial `8ac48ff0`

## Measurements executed

### Targeted ProductPrice paging test

Command:

```sh
JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew testDebugUnitTest --tests '*DefaultInventoryRepositoryTest*product price full pull streams remote prices by page*' --no-daemon
```

Result:

- BUILD SUCCESSFUL
- Runtime: `36s`
- Test creates `905` remote ProductPrice rows.
- Repository fetches 2 pages:
  - page 1: `afterId = null`, 900 rows
  - page 2: `afterId = priceRows[899].id`, 5 rows
- Summary asserts `remoteRowsEvaluated = 905`.

### Repository regression class

Command:

```sh
JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew testDebugUnitTest --tests '*DefaultInventoryRepositoryTest*' --no-daemon
```

Result:

- BUILD SUCCESSFUL
- Runtime: `17s`

### App build / launch memory

Commands:

```sh
JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew assembleDebug --no-daemon
adb install -r app/build/outputs/apk/debug/app-debug.apk
adb shell am start -n com.example.merchandisecontrolsplitview/.MainActivity
adb shell dumpsys meminfo com.example.merchandisecontrolsplitview
```

Results:

- `assembleDebug`: BUILD SUCCESSFUL in `15s`
- Install: Success
- Launch: Success
- Memory after launch:
  - TOTAL PSS: `151,044 KB`
  - TOTAL RSS: `233,876 KB`
  - TOTAL SWAP PSS: `248 KB`

## Full live sync

Android app-auth live ProductPrice sync was NOT EXECUTED in this pass.

Reason: this pass had a connected Android device and could install/launch/profile idle memory, but no verified signed-in app-auth sync rerun was completed. Therefore no Android live ProductPrice duration, rows/sec, or sync peak memory is claimed.

## Additional test note

Running both `DefaultInventoryRepositoryTest` and `CatalogSyncViewModelTest` together produced 25 failures in `CatalogSyncViewModelTest` caused by `ExceptionInInitializerError -> AttachNotSupportedException` at mock creation (`mockk<InventoryRepository>()`). The repository tests and ProductPrice paging test pass; the ViewModel failure is classified as environment/MockK attach, not a ProductPrice paging assertion failure.

