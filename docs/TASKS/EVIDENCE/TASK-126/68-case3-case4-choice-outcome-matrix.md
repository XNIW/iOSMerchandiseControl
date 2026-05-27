# Case 3/4 Choice Outcome Matrix

- status: `PASS`
- task: `TASK-126`
- safety: safe-readonly / privacy-redacted

## Matrix Summary
- Rows: `54`.
- Includes Case 3 clean account populated, dirty account switch, backup/export/discard flows.
- Includes Case 4 different-field auto merge, same-field review both directions, delete-vs-edit, ProductPrice stale and mixed batch partial review.
- `observedResult` is deterministic interaction-equivalent evidence from XCTest/JVM reducers; runtime smoke screenshots/JSON prove UI surfaces/buttons are present on simulator/emulator.

## References
- `docs/TASKS/EVIDENCE/TASK-126/agent-runs/20260527T021511Z-ios-test-conflict-review-ui-task-TASK-126-p67064.json`
- `docs/TASKS/EVIDENCE/TASK-126/agent-runs/20260527T021511Z-android-test-conflict-review-ui-task-TASK-126-p67065.json`
- `docs/TASKS/EVIDENCE/TASK-126/agent-runs/20260527T021711Z-ios-test-account-switch-review-ui-task-TASK-126-p70136.json`
- `docs/TASKS/EVIDENCE/TASK-126/agent-runs/20260527T021712Z-android-test-account-switch-review-ui-task-TASK-126-p70216.json`
- `docs/TASKS/EVIDENCE/TASK-126/agent-runs/20260527T021126Z-ios-smoke-conflict-review-ui-task-TASK-126-p61137.json`
- `docs/TASKS/EVIDENCE/TASK-126/agent-runs/20260527T021306Z-android-smoke-conflict-review-ui-task-TASK-126-p63521.json`
- `docs/TASKS/EVIDENCE/TASK-126/agent-runs/20260527T021729Z-ios-smoke-account-switch-review-ui-task-TASK-126-p71204.json`
- `docs/TASKS/EVIDENCE/TASK-126/agent-runs/20260527T021729Z-android-smoke-account-switch-review-ui-task-TASK-126-p71205.json`
