# TASK-123 AutoSync Speed Summary

Timestamp: 2026-05-25T03:22Z.

RESULT `PARTIAL_PASS_WITH_NOTES / MATRIX_NOT_COMPLETE`

Superseded note: this early smoke summary was later superseded by the final TASK-123 strict acceptance evidence (`autosync-20x20-warm-matrix`, cold/no-op/burst matrices, cleanup residue, and final acceptance matrix). The verdict below is historical for this smoke run only, not the final task verdict.

Auth/session and the iOS Review gate are no longer blocking. After the targeted fixes, 5 live post-tuning same-account simulator/emulator mutation-near-realtime runs completed with `RESULT PASS` at the harness receiver budget.

Post-tuning runs:
- `20260525T025854Z-live-mutation-near-realtime-task-TASK-123-prefix-TASK123_SPEED_-p32537.json`
- `20260525T030341Z-live-mutation-near-realtime-task-TASK-123-prefix-TASK123_SPEED_-p59653.json`
- `20260525T030621Z-live-mutation-near-realtime-task-TASK-123-prefix-TASK123_SPEED_-p80759.json`
- `20260525T030859Z-live-mutation-near-realtime-task-TASK-123-prefix-TASK123_SPEED_-p85717.json`
- `20260525T031145Z-live-mutation-near-realtime-task-TASK-123-prefix-TASK123_SPEED_-p90552.json`

Measured receiver-side autosync after remote events became available:

| Direction | n | p50 | p90 | p95 | max | Result |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| iOS -> Android receive/apply | 5 | 0.962s | 1.002s | 1.015s | 1.028s | PASS |
| Android -> iOS receive/apply | 5 | 0.409s | 0.435s | 0.444s | 0.452s | PASS |

Measured multi-mutation matrix batch totals available from the harness:

| Direction | n | p50 | p90 | p95 | max | Result |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| iOS matrix local+remote+receive | 5 | 4.555s | 4.878s | 4.892s | 4.907s | FAIL against strict p50 <= 3s single-propagation budget; batch contains multiple writes |
| Android matrix local+remote+receive | 5 | 13.619s | 16.703s | 17.714s | 18.724s | FAIL against strict p50/p95/max budget; batch contains multiple serial catalog/history pushes |

Interpretation:
- Cross-platform detection/apply is fast after `sync_events` are present.
- Remaining performance uncertainty is the source-side write/push path under the current multi-mutation harness, especially Android catalog/history serial push timing.
- The required 20 warm iterations per direction, 5 cold-ish iterations per side, 3 no-op checks per side, and burst-10 matrix were not completed in this run.

Verdict:
- Receiver autosync smoke: PASS.
- Full TASK-123 speed acceptance for this early smoke run: not assessed yet; superseded by final strict acceptance evidence.
