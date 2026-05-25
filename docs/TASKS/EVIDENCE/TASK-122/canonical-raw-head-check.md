# TASK-122 Canonical Raw Head Check

- status: BLOCKED_EXTERNAL_HEAD_MISMATCH
- exitCode: 2
- localHead: `6cc042c5dede5b492734cc5a36c2c05a96e61b50`
- originHead: `6cc042c5dede5b492734cc5a36c2c05a96e61b50`
- githubHead: `6cc042c5dede5b492734cc5a36c2c05a96e61b50`

## Raw checks
- task122: status=404 bytes=0 mentions_TASK_122=False
- master: status=200 bytes=468106 mentions_TASK_122=False
- transport: status=200 bytes=77538 mentions_TASK_122=False
- agent_readme: status=200 bytes=8141 mentions_TASK_122=False
- common: status=200 bytes=87495 mentions_TASK_122=False

## NEXT_ACTION
Publish/align TASK-122 planning docs to GitHub canonical main, then rerun canonical raw/head checks before Swift moves/splits/deletes.
