# TASK-112 — Verification results

Timestamp: 2026-05-20 20:47 -0400  
Agent: CURSOR / Executor

## Static scans

| Check | Result | Evidence |
|---|---:|---|
| iOS `git diff --check` | PASS | command exited 0 |
| Android `git diff --check` | PASS | command exited 0 |
| iOS source/test forbidden public CTA scan | PASS | no matches for `Sync now`, `Sincronizza ora`, `Sincronizar ahora`, `立即同步`, `CatalogCloudActionBlock`, `onCatalogRefresh`, `onClick = onRefresh` in app/tests |
| Android source/res/test forbidden public CTA scan | PASS | no matches for same forbidden terms in `app/src/main/java`, `app/src/main/res`, `app/src/test` |

## Builds

| Platform | Command | Result | Notes |
|---|---|---:|---|
| iOS Debug simulator | `xcodebuild -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' build` | PASS | `** BUILD SUCCEEDED **` |
| iOS Release simulator | `xcodebuild -scheme iOSMerchandiseControl -configuration Release -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' build` | PASS | initial Release failure fixed by moving `CloudSyncProgressInlineView` outside DEBUG |
| Android Debug | `JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home" ./gradlew :app:assembleDebug` | PASS | initial AAPT string escaping issue fixed |
| Android Release | `JAVA_HOME=... GRADLE_OPTS="-Xmx6g -Dfile.encoding=UTF-8" ./gradlew --no-daemon :app:assembleRelease` | PASS_WITH_NOTES | default heap run failed at `mergeDexRelease`; retry with explicit heap passed |
| Android lint | `JAVA_HOME=... ./gradlew :app:lintDebug` | PASS | pre-existing AGP/Kotlin deprecation warnings remain |

## Automated tests

| Platform | Command | Result | Notes |
|---|---|---:|---|
| iOS smoke targeted | `xcodebuild test ... -only-testing:iOSMerchandiseControlTests/CloudSyncOverviewStateTests` | PASS | 7 tests, 0 failures |
| iOS sync targeted suite | `xcodebuild test ... SupabaseManualSyncLifecycleRunGateTests LocalPendingAggregatedPushPlannerTests HistorySessionSyncServiceTests SupabaseProductPriceApplyServiceTests SupabaseManualSyncCoordinatorTests SupabaseManualSyncViewModelTests LocalizationCoverageTests` | FAIL_THEN_FIXED | first run: 196 tests, 1 obsolete copy assertion failure expecting `Sincronizza ora`; updated expectation |
| iOS fixed assertion rerun | `xcodebuild test ... SupabaseManualSyncViewModelTests/testTask108BaselineAbsentUsesUnifiedSyncCopyForApplicableReviewCTA` | PASS | 1 test, 0 failures |
| Android targeted sync tests | `./gradlew :app:testDebugUnitTest --tests CatalogAutoSyncCoordinatorTest --tests CatalogSyncViewModelTest --tests HistorySessionPushCoordinatorTest --tests SyncErrorClassifierTest --tests InventoryRemoteFetchSupportTest` | PASS | `BUILD SUCCESSFUL` |

## Simulator / emulator smoke

| Platform | Command | Result | Notes |
|---|---|---:|---|
| iOS Release install | `xcrun simctl install 240F400E-5EFA-486A-9137-FFBBE70F604D .../Release-iphonesimulator/iOSMerchandiseControl.app` | PASS | install exited 0 |
| iOS Release launch | `xcrun simctl launch 240F400E-5EFA-486A-9137-FFBBE70F604D com.niwcyber.iOSMerchandiseControl` | PASS | launched pid `15264`; process visible in simulator `ps` |
| Android debug install | `adb install -r app/build/outputs/apk/debug/app-debug.apk` | PASS | `Success` |
| Android debug launch | `adb shell am start -W -n com.example.merchandisecontrolsplitview/.MainActivity` | PASS | `Status: ok`, `WaitTime: 3035` |
| Android focused app | `adb shell dumpsys window` | PASS_WITH_NOTES | focused app is `MainActivity`; current focus was notification shade due device state |

## Supabase / database

| Operation | Result | Notes |
|---|---:|---|
| Local Supabase status | BLOCKED_EXTERNAL | Docker daemon unavailable |
| Live TASK112_* dataset creation | NOT_RUN | no verified authenticated live test/dev DB session available |
| Live cleanup | NOT_RUN | no TASK112_* records created by this execution |
| Migration | NOT_RUN | no safe verified environment; no migration applied |

## Sensitive logs

- Source scans did not reveal raw token/JWT/email additions in the changed code.
- Runtime logs inspected for Android smoke contained no app crash/FATAL; system/vendor logs mentioned package install/top-app only.
- Full binary sensitive-log audit was not completed.
