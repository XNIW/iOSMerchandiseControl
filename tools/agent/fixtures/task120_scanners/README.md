# TASK-120 scanner fixtures

Each scanner directory has a `red/` fixture expected to return `FAIL` or
`MISCONFIGURED` and a `green/` fixture expected to return `PASS` or
`PASS_WITH_NOTES` when run by `scan scanner-self-tests --task TASK-120 --strict`.

Expected exit mapping:

- RED: scanner status `FAIL` or `MISCONFIGURED`, harness exit `1` or `3`.
- GREEN: scanner status `PASS` or `PASS_WITH_NOTES`, harness exit `0`.

The canonical self-test report is produced under
`docs/TASKS/EVIDENCE/TASK-120/agent-runs/` as `.md`, `.json`, and `.log`, and
contains the `NEXT_ACTION` field from `task120_scans.py`.
