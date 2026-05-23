# TASK-117 - Final Handoff

Date: 2026-05-23 17:48:36 -0400

## Verdict
`ACTIVE / BLOCKED_EXTERNAL_LIVE_GATES`.

## Implemented
- Removed automatic runtime coupling to manual sync VM/factory/adapter/contracts.
- Replaced root host with clean `AppSyncRootHost`.
- Made public Options sync card observer-only.
- Moved automatic runtime contracts to clean DTOs.
- Kept manual sync behind explicit manual-only conversion boundary.
- Deleted dead compatibility adapter.
- Added strict TASK-117 harness scans including `no-full-pull-normal-path`.

## Verified PASS
- Debug build: `20260523T214344Z-ios-build-debug-task-TASK-117-p88637`
- Release build: `20260523T214400Z-ios-build-release-task-TASK-117-p90016`
- iOS sync tests: `20260523T214520Z-ios-test-sync-task-TASK-117-p90749`
- Simulator smoke: `20260523T212846Z-ios-smoke-simulator-task-TASK-117-p61133`
- no-legacy runtime path: `20260523T214343Z-scan-no-legacy-runtime-path-task-TASK-117-p88591`
- no-full-pull normal path: `20260523T214343Z-scan-no-full-pull-normal-path-task-TASK-117-p88592`
- sensitive/evidence scans: `p97995` / `p97994`

## External blockers
- Options smoke: macOS Accessibility/JXA permission required.
- iOS physical/live: app login/session restore required.
- Android live: `MC_ANDROID_DEVICE_SERIAL` required.
- Supabase linked grants/residue: linked/started DB required.
- Account matrix: iOS and Android app targets signed in plus scoped fixtures required.

## Next action
Resolve the external live/device/tooling prerequisites above, then rerun the blocked gates and return TASK-117 to review only if CA-117-16 and CA-117-22 become PASS.
