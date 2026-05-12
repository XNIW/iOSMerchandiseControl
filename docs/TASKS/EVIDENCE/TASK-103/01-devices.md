# 01 - Devices, Build, Install, Launch

## Setup

| Item | Value |
|------|-------|
| iOS toolchain | Xcode `26.5` build `17F42` |
| iOS scheme | `iOSMerchandiseControl` |
| iOS bundle id | `com.niwcyber.iOSMerchandiseControl` |
| Android adb | local Android SDK `adb` path redacted |
| Android Gradle JVM | Android Studio JBR, Java `21.0.10` |
| Android application id | `com.example.merchandisecontrolsplitview` |

## Steps

1. Detect physical iPhone with Xcode tooling.
2. Detect physical Android with adb.
3. Build/install/launch iOS app and run device XCTest slices.
4. Build/install/launch Android app and run instrumentation slices.

## Expected

Both physical devices are available, installable and launchable from the recorded builds.

## Observed

- iPhone physical detected: `iPhone di Min`, iOS `26.5`, device id redacted.
- Android physical detected: OnePlus8 / IN2013, state `device`, serial redacted.
- iOS Release build/install/launch passed during preflight.
- iOS Debug build-for-testing passed after TASK-103 test harness updates.
- Android `assembleDebug assembleDebugAndroidTest`, `installDebug`, `installDebugAndroidTest` passed on the physical device.
- Android launch package/activity: `com.example.merchandisecontrolsplitview/.MainActivity`.

## Result

`PASS` for CA-103-01 and CA-103-02.

## Notes/Redactions

Raw device identifiers are not stored. Android Gradle emitted pre-existing AGP/Kotlin configuration warnings; iOS build emitted an AppIntents metadata warning unrelated to TASK-103 code.
