# Android Harness

Status: PASS_WITH_NOTES.

PASS:
- `android build debug`: `20260521T053016Z-android-build-debug.json`
- `android build release`: `20260521T053023Z-android-build-release.json`
- `android test sync`: `20260521T053036Z-android-test-sync.json`
- `android test offline` L1 JVM: `20260521T052939Z-android-test-offline.json`
- `android offline-write --tier L1`: `20260521T053007Z-android-offline-write-tier-L1-prefix-TASK113_OFFLINE_L1_.json`
- `android reconnect-drain --tier L1`: `20260521T052939Z-android-reconnect-drain-tier-L1-prefix-TASK113_OFFLINE_L1_.json`
- `android offline-tier-status`: `20260521T052939Z-android-offline-tier-status.json`

L2 implementation:
- Test source set file: `app/src/androidTest/java/com/example/merchandisecontrolsplitview/Task113AndroidOfflineHarnessTest.kt`
- Method: `offlineWriteAndReconnectDrainInstrumentedL2`
- Scope: Room in-memory + fake/controlled remote failure/reconnect; no business logic changes.
- Compile evidence: `20260521T054342Z-android-offline-write-tier-L2-prefix-TASK113_OFFLINE_L2_.log` includes `:app:assembleDebugAndroidTest` BUILD SUCCESSFUL.

L2 professional review result:
- `20260521T060955Z-android-offline-write-tier-L2-prefix-TASK113_OFFLINE_L2_-p46345.json`: PASS.
- `20260521T061015Z-android-reconnect-drain-tier-L2-prefix-TASK113_OFFLINE_L2_-p47457.json`: PASS.
- Root cause fixed: the harness wakefulness check used a `printf | grep -q` pipeline under `pipefail`, producing false BLOCKED via SIGPIPE even when ADB reported `mWakefulness=Awake`.

L3:
- Refused without `MC_ALLOW_LIVE=1`; not claimed as PASS.
- If live L3 is enabled later, the instrumented test now requires remote read-back after push and reports only PASS_WITH_NOTES unless network-off/on proof is explicit.

Professional review update — 2026-05-21:
- PASS: `android build debug`: `20260521T060819Z-android-build-debug-p42456.json`.
- PASS: `android build release`: `20260521T060840Z-android-build-release-p43580.json`.
- PASS: `android test sync`: `20260521T060840Z-android-test-sync-p43579.json`.
- PASS: `android test offline` L1: `20260521T060819Z-android-test-offline-p42459.json`.
- PASS: `android smoke device`: `20260521T060955Z-android-smoke-device-p46364.json`.
- PASS: `android smoke options`: `20260521T061015Z-android-smoke-options-p47458.json`.
