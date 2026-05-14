# TASK-108 Evidence 34 — Android Sync Parity Device Smoke

Date: 2026-05-13 23:45 -0400

Device:
- OnePlus IN2013 over adb: `8ac48ff0`, status `device`.

What ran:
- `./gradlew assembleDebug`: PASS.
- `./gradlew testDebugUnitTest --tests '*CatalogSync*'`: PASS.
- `adb install -r app/build/outputs/apk/debug/app-debug.apk`: PASS.
- Launch smoke with `monkey`: PASS.
- Options screen reached and UI hierarchy dumped.

Observed Android UI:
- Device language was Chinese.
- Public cloud section shows a single sync action: `立即同步`.
- The action description says it aligns catalog, prices, history/sessions and local changes.
- No separate public quick/full sync pair was visible after the patch.
- Signed-out state blocks the button as expected; no authenticated sync was attempted.
- Screenshot: `screenshots/2026-05-13-android-options-single-sync-now.png`.

Checks:
- ✅ BUILD — `assembleDebug` passed.
- ✅ TEST — `testDebugUnitTest --tests '*CatalogSync*'` passed.
- ✅ DEVICE — install/launch/navigation smoke passed.
- ✅ STATIC — Android Options public API now has one cloud action; internal quick sync remains available for non-public flows.
- ⚠️ NOT EXECUTABLE — authenticated Android sync run was not executed because the device was signed out and no test account/session was provided.

Post-TASK-108 targeted FIX update 2026-05-14 00:38 -0400:
- `Local database status` card implemented in Android Options.
- `./gradlew assembleDebug`: PASS.
- `./gradlew testDebugUnitTest --tests '*CatalogSync*' --tests '*RealtimeRefreshCoordinatorTest*'`: PASS/up-to-date.
- `adb install -r` and launch with `monkey`: PASS.
- UI hierarchy on OnePlus IN2013 showed the new Chinese localized card:
  - `本地数据库状态`
  - `本地数据库已就绪`
  - product count row visible (`商品 18866`)
  - signed-out cloud account state visible (`未登录`)
- Authenticated Android sync was still not executed because the device was signed out.
