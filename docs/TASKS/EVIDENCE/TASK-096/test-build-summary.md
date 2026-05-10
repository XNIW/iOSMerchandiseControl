# TASK-096 Test And Build Summary

Status: READY FOR REVIEW.

| Check | Command/evidence | Result |
|-------|------------------|--------|
| Initial git status | `git status --short` | `M docs/MASTER-PLAN.md`; `?? docs/TASKS/TASK-096-release-semi-auto-acceptance-ios.md` before TASK-096 execution edits |
| `git diff --check` | `git diff --check` after evidence/tracking edits | PASS |
| `xcodebuild -list` | `xcodebuild -list -project iOSMerchandiseControl.xcodeproj` | PASS; scheme `iOSMerchandiseControl`, targets `iOSMerchandiseControl`, `iOSMerchandiseControlTests`, configs Debug/Release |
| Debug build | `xcodebuild build -quiet ... -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4.1'` | PASS |
| Release build | `xcodebuild build -quiet ... -configuration Release -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4.1'` | PASS |
| Release ViewModel XCTest | `SupabaseManualSyncViewModelTests` | PASS 87/0 |
| Lifecycle TASK-095 XCTest | `SupabaseManualSyncLifecycleRunGateTests` | PASS 6/0 |
| Planner TASK-094 XCTest | `LocalPendingAggregatedPushPlannerTests` | PASS 11/0 |
| Snapshot/pending TASK-093 XCTest | `SupabaseManualSyncLocalPendingSnapshotProviderTests`, `LocalPendingChangeAccumulatorTests` | PASS 13/0 + 12/0 |
| Release UI XCTest | `SupabaseManualSyncReleaseUITests` | PASS 24/0 |
| Localization coverage | `LocalizationCoverageTests` | PASS 8/0 |
| Regression TASK-091...095 | selected related sync suites | PASS 364/0 source-counted test methods, exit code 0 |
| Full XCTest | full scheme test | PASS 626/0 source-counted test methods, exit code 0 |
| `plutil -lint` Localizable | IT/EN/ES/zh-Hans | PASS all OK |

## Notes

- First Debug build invocation used `OS=26.4` and failed before build because Xcode exposes the simulator as `OS=26.4.1`; rerun with the correct destination passed.
- Test build emitted four known non-Sendable warnings in `SyncEventOutboxDrainDebugViewModelTests.swift`; they are pre-existing debug test warnings from prior tasks and not introduced by TASK-096 tracking/evidence edits.
