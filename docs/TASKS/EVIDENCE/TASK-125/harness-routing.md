# TASK-125 Harness Routing

- Status: `PASS`
- Task: `TASK-125`
- Redaction applied: `true`
- Generated: `2026-05-26T00:57:09Z`

TASK-125 commands were added/discovered in mc-agent help/list routes. Real-device matrix routes exist but currently block instead of executing the full physical matrix.

## Referenced agent runs
- `PASS` — `preflight --task TASK-125` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T002920Z-preflight-task-TASK-125-p9134.json`
- `PASS` — `report validate-json --task TASK-125 --path docs/TASKS/EVIDENCE/TASK-125/agent-runs` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T005031Z-report-validate-json-task-TASK-125-path-docs-TASKS-EVIDENCE-TASK-125-agent-runs-p35788.json`
- `BLOCKED_EXTERNAL` — `live real-device-realtime --task TASK-125 --prefix TASK125_RT_` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T005105Z-live-real-device-realtime-task-TASK-125-prefix-TASK125_RT_-p38862.json`
- `BLOCKED_EXTERNAL` — `live real-device-offline-reconnect --task TASK-125 --prefix TASK125_OFFLINE_` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T005106Z-live-real-device-offline-reconnect-task-TASK-125-prefix-TASK125_OFFLINE_-p39291.json`
- `BLOCKED_EXTERNAL` — `live real-device-background-sync --task TASK-125 --prefix TASK125_BG_` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T005107Z-live-real-device-background-sync-task-TASK-125-prefix-TASK125_BG_-p39721.json`
- `BLOCKED_EXTERNAL` — `live real-device-kill-restart-pending --task TASK-125 --prefix TASK125_RESTART_` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T005108Z-live-real-device-kill-restart-pending-task-TASK-125-prefix-TASK125_RESTART_-p40147.json`
- `BLOCKED_EXTERNAL` — `live real-device-network-flapping --task TASK-125 --prefix TASK125_FLAP_` — `docs/TASKS/EVIDENCE/TASK-125/agent-runs/20260526T005056Z-live-real-device-network-flapping-task-TASK-125-prefix-TASK125_FLAP_-p37011.json`

## Next action
Implement full TASK-125 real-device matrix execution behind these registered routes.
