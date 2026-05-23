# TASK-117 - Build Test Smoke Results

Date: 2026-05-23 17:48:36 -0400

## Harness results
| Gate | Result | Evidence |
|---|---:|---|
| iOS Debug build | PASS | `20260523T214344Z-ios-build-debug-task-TASK-117-p88637` |
| iOS Release build | PASS | `20260523T214400Z-ios-build-release-task-TASK-117-p90016` |
| iOS sync tests | PASS | `20260523T214520Z-ios-test-sync-task-TASK-117-p90749` |
| iOS simulator smoke | PASS | `20260523T212846Z-ios-smoke-simulator-task-TASK-117-p61133` |
| iOS Options smoke | BLOCKED | `20260523T212856Z-ios-smoke-options-task-TASK-117-p61742` |

## Blocker
Options smoke requires macOS Accessibility/JXA permission for `osascript`. This is external tooling readiness, not app failure. Next action: grant/verify macOS Accessibility for the automation runner, then rerun `./tools/agent/mc-agent.sh ios smoke options --task TASK-117`.

