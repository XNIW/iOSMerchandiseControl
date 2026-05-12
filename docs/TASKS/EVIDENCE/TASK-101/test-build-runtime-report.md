# Test / Build / Runtime Report

## Build And XCTest

| Check | Command | Result | Evidence |
|---|---|---|---|
| Xcode schemes | `xcodebuild -list -project iOSMerchandiseControl.xcodeproj` | PASS | Scheme/target list available. |
| iOS 26.5 simulator runtime | `xcodebuild -downloadPlatform iOS -buildVersion 26.5 -architectureVariant arm64` | PASS | Runtime installed; destinations list includes iPhone 17 Pro iOS 26.5. |
| Privacy manifest lint | `plutil -lint iOSMerchandiseControl/PrivacyInfo.xcprivacy` | PASS | `ios/privacy-manifest-validation.txt`. |
| Release build, final rerun | `xcodebuild build -quiet ... -configuration Release -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'` | PASS | `ios/release-build-ios-26.5.txt`. |
| TASK-101 targeted XCTest, final rerun | `xcodebuild test -quiet ... -only-testing:SupabaseConfigSecurityTests ...` | PASS | `ios/targeted-task101-tests-ios-26.5.txt`: 84 passed, 0 failed. |
| Full XCTest, final rerun | `xcodebuild test -quiet ... -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'` | PASS | `ios/full-xctest-ios-26.5.txt`: 640 passed, 12 skipped, 0 failed. |
| Simulator launch smoke | `xcrun simctl install/launch/screenshot` | PASS | `ios/simulator-smoke-ios-26.5.txt` and PNG screenshot. |
| Targeted XCTest | `xcodebuild test ... -only-testing:SupabaseConfigSecurityTests -only-testing:SyncEventOutboxStateTests -only-testing:SupabaseSyncEventDebugViewModelTests -only-testing:SupabaseManualPushServiceTests` | PASS | `Test-iOSMerchandiseControl-2026.05.10_23-01-18--0400.xcresult` |
| Review targeted XCTest | `xcodebuild test ... -only-testing:SyncEventOutboxEnqueueServiceTests -only-testing:SyncEventOutboxStateTests` | PASS | `Test-iOSMerchandiseControl-2026.05.10_23-49-25--0400.xcresult` |
| Review TASK-101 suite | `xcodebuild test ... -only-testing:SupabaseConfigSecurityTests -only-testing:SupabaseSyncEventDebugViewModelTests -only-testing:SupabaseManualPushServiceTests -only-testing:SyncEventOutboxStateTests -only-testing:SyncEventOutboxEnqueueServiceTests` | PASS | `Test-iOSMerchandiseControl-2026.05.10_23-51-11--0400.xcresult` |
| Full XCTest | `xcodebuild test -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4.1'` | PASS | Final review rerun `Test-iOSMerchandiseControl-2026.05.11_00-00-42--0400.xcresult`: 640 passed, 12 skipped, 0 failed. |
| Release build | `xcodebuild build -configuration Release -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4.1'` | PASS | Build succeeded. |
| New warnings | Release build log scan | PASS_WITH_NOTE | Only AppIntents metadata warning remains; no task-introduced Swift warning after fix. |
| Diff whitespace | `git diff --check` | PASS | No output. |
| Evidence redaction scan | `rg` scan over TASK-101 task/evidence for emails, JWT-like tokens, bearer/API key shapes, connection strings and raw Supabase REST URLs | PASS | No output for token/email/connection string patterns; UUID/long-number scan only matched a migration timestamp. |

## Supabase Runtime / Schema

| Check | Result | Notes |
|---|---|---|
| Linked query sanity | PASS | `select now()` succeeded. |
| RLS/policy inventory | PASS | Live metadata queried. |
| Grants inventory | PASS | Live metadata queried before/after remediation. |
| Function grant hardening | PASS | `rls_auto_enable()` client-role EXECUTE revoked and verified. |
| Local Supabase status | PASS | `supabase status` confirms local development setup running; secrets redacted in evidence. |
| Local schema lint | PASS | `supabase db lint --local --level warning`: no schema errors found. |
| Linked migration list | PASS_WITH_OPS_NOTE | `supabase migration list --linked` still shows registry drift; drift analysis confirms live objects are present. |
| Linked schema lint | PASS | `supabase db lint --linked --level warning`: no schema errors found. |
| Drift introspection | PASS | Read-only linked/local metadata confirms required tables, functions, policies and triggers. |

## Android Reference Runtime

| Check | Result | Evidence |
|---|---|---|
| Raw `userId` log scan | PASS | `android/privacy-scan-userid-log.txt` |
| `testDebugUnitTest` | PASS | `android/testDebugUnitTest.txt` |
| `lintDebug` | PASS | `android/lintDebug.txt` |
| `assembleDebug` | PASS | `android/assembleDebug.txt` |
| `assembleRelease` | PASS | `android/assembleRelease.txt` |

## Runtime Data

No test rows were created, updated or deleted. TASK-101 performed metadata reads and one scoped DDL privilege update only. The review pass performed no destructive Supabase operation.
