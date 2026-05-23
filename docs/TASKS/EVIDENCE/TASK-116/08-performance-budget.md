# Performance Budget

## Gate
`MC_ALLOW_LIVE=1 ./tools/agent/mc-agent.sh live sync-performance-budget --task TASK-116 --prefix TASK116_PERF_`

## Results
- First run FAIL due stale `attemptWindow.count` persisted from old diagnostics.
  - Evidence: `agent-runs/20260523T162514Z-live-sync-performance-budget-task-TASK-116-prefix-TASK116_PERF_-p14465.md`
- Harness/runtime corrected to window attempts by timestamp.
- Rerun PASS.
  - Evidence: `agent-runs/20260523T162552Z-live-sync-performance-budget-task-TASK-116-prefix-TASK116_PERF_-p15267.md`

## Observed
- No spinner 0/0 failure on rerun.
- No foreground full-pull signal.
- Attempts/min budget now ignores stale windows older than 60 seconds and new runtime records a bounded 60-second window.
