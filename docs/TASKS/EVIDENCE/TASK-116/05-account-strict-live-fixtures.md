# Account Strict-Live Fixtures

## Status
- Gate: `MC_ALLOW_LIVE=1 MC_ANDROID_DEVICE_SERIAL=8ac48ff0 ./tools/agent/mc-agent.sh live account-merge-policy-matrix --task TASK-116 --prefix TASK116_ACCOUNT_`
- Result: BLOCKED, not PASS.
- Evidence: `agent-runs/20260523T162603Z-live-account-merge-policy-matrix-task-TASK-116-prefix-TASK116_ACCOUNT_-p15962.md`

## Reason
Strict A-L fixture execution requires live scoped account fixtures and available signed-in iOS + Android app targets. The Android physical serial was not available later in the run, so cross-device live account execution cannot be claimed.

## Dry-run commands added
- `account fixture prepare --task TASK-116 --prefix TASK116_ACCOUNT_ --dry-run`
- `account fixture cleanup --task TASK-116 --prefix TASK116_ACCOUNT_`

Evidence:
- Prepare dry-run PASS: `agent-runs/20260523T161528Z-account-fixture-prepare-task-TASK-116-prefix-TASK116_ACCOUNT_-dry-run-p3825.md`
- Cleanup dry-run PASS: `agent-runs/20260523T161528Z-account-fixture-cleanup-task-TASK-116-prefix-TASK116_ACCOUNT_-p3839.md`

## Review classification
`BLOCKED_ACCOUNT_FIXTURES` is external/fixture readiness, not app DONE. TASK-116 can enter REVIEW with this blocker documented, but cannot enter DONE.
