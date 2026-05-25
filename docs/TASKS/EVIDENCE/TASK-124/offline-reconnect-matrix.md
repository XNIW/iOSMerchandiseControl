# TASK-124 Offline / Reconnect Matrix

Status: `PASS — SIMULATOR_EMULATOR_SCOPE_VERIFIED`

Canonical command executed:

```bash
MC_ALLOW_LIVE=1 MC_TASK_ID=TASK-124 ./tools/agent/mc-agent.sh live offline-reconnect-sync --task TASK-124 --prefix TASK124_OFFLINE_SIM_
```

Report:
`docs/TASKS/EVIDENCE/TASK-124/agent-runs/20260525T205558Z-live-offline-reconnect-sync-task-TASK-124-prefix-TASK124_OFFLINE_SIM_-p81521.json`

Scope:
- iOS Simulator;
- Android Emulator `emulator-5554`;
- Supabase linked/live same-account session;
- `TASK124_` scoped fixtures only.

Result:
- Offline/reconnect simulator/emulator PASS.
- AC-124-16..22 are covered for TASK-124 simulator/emulator scope by the report above.
- The earlier `TASK124_OFFLINE_LIVE_` physical/live `BLOCKED_EXTERNAL` report remains historical only and is superseded for TASK-124 closure.

Deferred TASK-125:
- physical iPhone;
- physical Android;
- locked/background real-device;
- long-offline real-device;
- real-device background sync.
