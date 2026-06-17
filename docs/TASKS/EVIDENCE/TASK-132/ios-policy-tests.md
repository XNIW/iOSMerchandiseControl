# TASK-132 iOS Policy Tests

## Commands

```bash
xcodebuild -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -configuration Debug -destination 'generic/platform=iOS Simulator' build
```

Result: PASS.

```bash
xcodebuild test -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'id=459C668B-7CE8-443B-BAB3-7D3D5FFC9143' -only-testing:iOSMerchandiseControlTests/SyncDecisionEngineTests -only-testing:iOSMerchandiseControlTests/Task118AutomaticDomainTests/testBackgroundRunnerUsesDecisionEngineBeforeAutomaticRun
```

Result: PASS, 13 tests, 0 failures.

## Coverage

- Remote event with pending drains before push.
- Drift blocks pending push.
- Light reconcile request does not push first.
- Same-account binding still requires bootstrap when baseline is absent and local catalog exists.
- Background runner uses decision engine instead of hardcoded push/drain.
