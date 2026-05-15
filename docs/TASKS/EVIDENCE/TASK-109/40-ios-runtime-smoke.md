# TASK-109 — 40 iOS Runtime Smoke

Date: 2026-05-15  
Simulator: iPhone 15 Pro Max iOS 26.1 (`459C668B-7CE8-443B-BAB3-7D3D5FFC9143`)  
Build: Debug via XcodeBuildMCP, warnings `0`.

## Smoke result

| Scenario | Evidence | Result |
|---|---|---|
| Cold launch signed-in on Inventory | `screenshots/final-root-banner-auto-check.jpg` | PASS: root banner starts `Checking for updates...` before Options is opened. |
| Options after root check | `screenshots/final-options-observer-local-status.jpg` | PASS: Options shows observer/manual state and local counts, including `History sessions, 0`. |
| Manual Sync now | `screenshots/final-options-syncnow-in-progress.jpg` and `screenshots/final-options-syncnow-completed-notes-no-review.jpg` | PASS: active job shows progress/cancel; settled state is `Sync completed with notes`, no Review sheet. |
| No-op / warning-only Review | UI hierarchy after manual sync | PASS: no `Review cloud changes`, no `Device already updated`, no `Recheck` primary CTA. |
| Root banner no-op completion | UI hierarchy after final cold launch | PASS: warning-only/no-action completion does not leave root Review banner sticky. |
| History count/list baseline | Wave 1 `06-history-count-and-list.md` plus Options final screenshot | PASS_WITH_NOTES: remote History dataset was empty (`0`), local/UI `0` are coherent; remote non-empty pull covered by unit tests, not live data. |

## Build/log artifacts

- Final Debug build/run log: `logs/final-debug-build-run-postfix.log`.
- Final runtime log: `logs/final-runtime-postfix.log`.
- Dynamic Type build/run log: `logs/final-dynamic-type-build-run.log`.

## Simulator runner note

XcodeBuildMCP `test_sim` on the iPhone 15 Pro Max clone failed earlier with CoreSimulator clone/launch errors. Final automated XCTest validation used iPhone 17 Pro iOS 26.5 via direct `xcodebuild`.
