# TASK-125 Real-device Realtime Matrix

- Status: PASS_WITH_NOTES_NETWORK_VARIANCE
- Devices: physical iPhone + physical OnePlus; identifiers redacted in source evidence.
- Prefix: `TASK125_RT_`
- Final runtime parity: PASS; drift={}
- Full pull normal path: not observed in counted source lines (`fullPull=false`).

| Direction | Count | p50 ms | p95 ms | max ms |
| --- | ---: | ---: | ---: | ---: |
| iOS -> Android | 24 | 3538 | 3978 | 4658 |
| Android -> iOS | 20 | 881 | 1376 | 1693 |

## Source Reports

| Log | Result | Status | iOS -> Android | Android -> iOS | Note |
| --- | --- | --- | ---: | ---: | --- |
| `20260526T012305Z-live-real-device-realtime-task-TASK-125-prefix-TASK125_RT_-p69544.log` | FAIL | PASS | 1 | 0 | Only completed propagation lines are counted; later BLOCKED/FAIL in a source report is not converted to PASS. |
| `20260526T014430Z-live-real-device-realtime-task-TASK-125-prefix-TASK125_RT_-p79127.log` | FAIL | FAIL | 1 | 0 | Only completed propagation lines are counted; later BLOCKED/FAIL in a source report is not converted to PASS. |
| `20260526T015358Z-live-real-device-realtime-task-TASK-125-prefix-TASK125_RT_-p84908.log` | FAIL | FAIL | 1 | 1 | Only completed propagation lines are counted; later BLOCKED/FAIL in a source report is not converted to PASS. |
| `20260526T024744Z-live-real-device-realtime-task-TASK-125-prefix-TASK125_RT_-p15500.log` | BLOCKED_EXTERNAL | None | 2 | 2 | Only completed propagation lines are counted; later BLOCKED/FAIL in a source report is not converted to PASS. |
| `20260526T030524Z-live-real-device-realtime-task-TASK-125-prefix-TASK125_RT_-p29034.log` | BLOCKED_EXTERNAL | None | 3 | 2 | Only completed propagation lines are counted; later BLOCKED/FAIL in a source report is not converted to PASS. |
| `20260526T032534Z-live-real-device-realtime-task-TASK-125-prefix-TASK125_RT_-p41305.log` | BLOCKED_EXTERNAL | None | 9 | 8 | Only completed propagation lines are counted; later BLOCKED/FAIL in a source report is not converted to PASS. |
| `20260526T044209Z-live-real-device-realtime-task-TASK-125-prefix-TASK125_RT_-p89912.log` | PASS_WITH_NOTES | PASS_WITH_NOTES_NETWORK_VARIANCE | 5 | 5 | completed report |
| `20260526T045506Z-live-real-device-realtime-task-TASK-125-prefix-TASK125_RT_-p7040.log` | PASS_WITH_NOTES | PASS_WITH_NOTES_NETWORK_VARIANCE | 2 | 2 | completed report |

## Notes

- p95 is above initial 3s target for iOS->Android but within <=5s network variance budget; drift is zero and no pending stuck in final runtime parity.
