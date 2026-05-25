# TASK-124 Offline / Reconnect Matrix

Status: `BLOCKED_EXTERNAL`

Canonical command executed:

```bash
MC_ALLOW_LIVE=1 MC_TASK_ID=TASK-124 ./tools/agent/mc-agent.sh live offline-reconnect-sync --task TASK-124 --prefix TASK124_OFFLINE_LIVE_
```

Report:
`docs/TASKS/EVIDENCE/TASK-124/agent-runs/20260525T153917Z-live-offline-reconnect-sync-task-TASK-124-prefix-TASK124_OFFLINE_LIVE_-p16598.json`

Blocker:
`MC_ANDROID_DEVICE_SERIAL` is not set to a physical device or emulator serial, so the canonical cross-platform live/offline harness cannot execute the required iOS <-> Android scenarios.

No PASS is claimed for AC-124-16..22.
