# TASK-097 Test And Build Summary

Status: REVIEW PASS.

## Preflight

| Check | Command/evidence | Result |
|-------|------------------|--------|
| Initial git status | `git status --short` before TASK-097 execution edits | PASS; pre-existing `M docs/MASTER-PLAN.md`, `?? docs/TASKS/TASK-097-runtime-sandbox-smoke-ios-supabase.md` |
| Branch | `git branch --show-current` | PASS; `main` |
| File task path | `docs/MASTER-PLAN.md` vs filesystem | PASS; `docs/TASKS/TASK-097-runtime-sandbox-smoke-ios-supabase.md` exists |
| TASK-098 not opened | `find docs/TASKS -maxdepth 1 -name '*TASK-098*'` | PASS; no file output |
| Supabase config | redacted local inspection | PASS; HTTPS project URL, publishable key only, service-role-like key false |
| Simulator availability | `xcrun simctl list devices available` | PASS; iPhone 15 Pro Max iOS 26.1 and iPhone 17 Pro iOS 26.4 available |
| `xcodebuild -list` | `xcodebuild -list` | PASS; project/scheme/targets listed |

## Runtime Smoke

| Check | Command/evidence | Result |
|-------|------------------|--------|
| iOS/Supabase runtime smoke | execution live XCTest harness using app SDK/auth; review retained a separate read-only harness below | PASS; `TEST SUCCEEDED`, owner_hash `81a269773be6`, project_hash `bf02812f63e2`, dataset suffix `R1778437271` |
| Runtime command | `xcodebuild test -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,id=459C668B-7CE8-443B-BAB3-7D3D5FFC9143' -parallel-testing-enabled NO -only-testing:iOSMerchandiseControlTests/Task097RuntimeSmokeTests/testTask097RuntimeSandboxSmokeIOSSupabase` | PASS; 1 test, 0 failures |
| Review retained read-back harness | `xcodebuild test -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,id=AC6FBFC3-A97F-412C-BEC0-F88B9956107B' -only-testing:iOSMerchandiseControlTests/Task097RuntimeSmokeTests` | PASS; test-only harness compiles and is intentionally skipped unless `TASK097_RUNTIME_SMOKE=1`; no writes or cleanup |
| Seed read-back | runtime ledger | PASS; 1 supplier, 1 category, 2 products, 6 ProductPrice rows |
| Pull/apply read-back | runtime ledger | PASS; catalog inserted 2, price inserted 6, baseline valid |
| Local edit/pending | runtime ledger | PASS; Product B pending total 3, price pending 2, catalog pending 1 |
| Aggregated push/read-back | runtime ledger | PASS; catalog status completed, ProductPrice verified, remote prices 8 |
| Lifecycle smoke | runtime ledger | PASS; interrupted, readyToRetry and duplicate active run checks passed |

Review retained `iOSMerchandiseControlTests/Task097RuntimeSmokeTests.swift` as a gated, read-only harness for reproducible remote read-back. It has no secrets, performs no writes and does not clean up TASK097 rows left as evidence.

## Build And XCTest

| Check | Command/evidence | Result |
|-------|------------------|--------|
| `git diff --check` | `git diff --check` | PASS |
| Debug build | `xcodebuild build -scheme iOSMerchandiseControl -configuration Debug -destination 'id=459C668B-7CE8-443B-BAB3-7D3D5FFC9143'` | PASS |
| Release build | `xcodebuild build -scheme iOSMerchandiseControl -configuration Release -destination 'id=459C668B-7CE8-443B-BAB3-7D3D5FFC9143'` | PASS |
| Targeted TASK-091...096 regressions, first attempt | selected sync suites on iPhone 15 Pro Max iOS 26.1 | FAILED_ENV; test process crashed with malloc/free issue after many passing tests; rerun on iOS 26.4 used for final result |
| Lifecycle isolated rerun | `SupabaseManualSyncLifecycleRunGateTests` on iPhone 17 Pro iOS 26.4 | PASS; 6/0 |
| Targeted TASK-091...096 regressions, final | selected sync suites on iPhone 17 Pro iOS 26.4 | PASS; 310/0, exit code 0 |
| Full XCTest | full scheme test on iPhone 17 Pro iOS 26.4 | PASS; 626/0, exit code 0 |
| Review Debug build | `xcodebuild build -scheme iOSMerchandiseControl -configuration Debug -destination 'platform=iOS Simulator,id=AC6FBFC3-A97F-412C-BEC0-F88B9956107B'` | PASS |
| Review Release build | `xcodebuild build -scheme iOSMerchandiseControl -configuration Release -destination 'platform=iOS Simulator,id=AC6FBFC3-A97F-412C-BEC0-F88B9956107B'` | PASS |
| Review targeted TASK-091...096 regressions | selected sync/manual sync/ProductPrice/pending/lifecycle/UI/localization suites on iPhone 17 Pro iOS 26.4 | PASS; 246/0 |
| Review full XCTest | full scheme test on iPhone 17 Pro iOS 26.4 | PASS; 626 passed, 1 skipped, 0 failed |
| Review localization lint | `plutil -lint` IT/EN/ES/zh-Hans | PASS |

Known build note: Debug/Release builds emitted the existing AppIntents metadata extraction skipped note; no production code change was retained by TASK-097.

Review note: the iOS 26.1 crash from the first execution batch remains classified as a runner/destination issue because the same families passed on iOS 26.4; no TASK-097 regression was found.
