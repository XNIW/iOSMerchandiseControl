# TASK-126 scanner fixtures

Each scanner directory has RED and GREEN fixture text used by:

```bash
./tools/agent/mc-agent.sh scan scanner-self-tests --task TASK-126 --strict
```

RED fixtures must fail the scanner. GREEN fixtures must pass.
