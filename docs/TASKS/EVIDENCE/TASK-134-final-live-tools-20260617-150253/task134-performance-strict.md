# task134-performance-strict

- status: PASS
- prefix: `TASK134_FINAL_PERF_RERUN_`
- rowsCreated: 15
- rowsDeleted: 15
- residueCount: 0

## Gates

- PASS_CLI_HARNESS: PASS - supabase_cli_p95=17518ms target=25000ms total_harness_ms=[17182, 14956, 13979, 17518, 13315]
- PASS_APP_LATENCY: PASS - app_sync_p95=1313.7ms target=5000ms app_sync_ms=[1252, 482, 1314, 462, 1280, 461, 1145, 468, 1250, 470, 1241, 460, 1062, 455, 1079, 481, 1239, 451, 1308, 469]
- all_iterations_completed: PASS - iterations=5
- duplicates_zero: PASS - duplicates=0
- unexpected_sync_events_zero: PASS - unexpected_sync_events=0
- cleanup_residue_zero: PASS - residue=0

## Summary

Strict performance smoke completed with app latency split from Supabase CLI overhead.
