# TASK-099 Test Summary

## Commands

| Check | Evidence | Result |
|-------|----------|--------|
| Project listing | `xcodebuild -list` | PASS |
| Targeted XCTest suite | `xcodebuild test -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4.1' -only-testing:...` for sync plan, remote preview, coordinator, ViewModel, ProductPrice manual push, Release UI | PASS |
| Release build | `xcodebuild build -scheme iOSMerchandiseControl -configuration Release -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4.1'` | PASS |
| Full XCTest | `xcodebuild test -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4.1'` | PASS |
| Targeted review recheck | `xcodebuild test -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4.1' -only-testing:iOSMerchandiseControlTests/SupabaseSyncPlanContractTests -only-testing:iOSMerchandiseControlTests/SupabaseManualSyncViewModelTests` | PASS; bundle `Test-iOSMerchandiseControl-2026.05.10_19-34-13--0400.xcresult` |
| Result bundle summary | `xcrun xcresulttool get test-results summary --path /Users/minxiang/Library/Developer/Xcode/DerivedData/iOSMerchandiseControl-hipxsmlvmjphcyaknnsmrggoalrx/Logs/Test/Test-iOSMerchandiseControl-2026.05.10_19-36-07--0400.xcresult` | 630 passed, 5 skipped, 0 failed |
| Localization syntax | `plutil -lint` on IT/EN/ES/zh-Hans `Localizable.strings` | PASS |
| Patch whitespace | `git diff --check` | PASS |
| Anti-scope scan | `git diff -- iOSMerchandiseControl iOSMerchandiseControlTests | rg -n "Timer|BGTask|BGTaskScheduler|Realtime|polling|\\.channel|\\.rpc|service_role|JWT|refresh token|xniw97|@gmail|eyJ|sb_secret|SUPABASE_.*KEY"` | PASS / no matches |

## Notes

- Review found and fixed a precedence mismatch: permission/RLS now blocks above stale baseline. An initial targeted run after that review edit exposed a compile typo (`return` missing); it was fixed and the targeted tests were rerun successfully before the full suite.
- Build logs still include the known AppIntents metadata warning (`No AppIntents.framework dependency found`), already seen in prior task logs and not introduced by TASK-099.
- The 5 skipped tests in the full suite are gated tests from the existing suite, not TASK-099 failures.
- No Supabase live account was used; fakeable XCTest coverage was sufficient for the diff.
