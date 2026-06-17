# iOS to Android propagation

| metric | value |
|---|---:|
| runs | 10 |
| pass | 10 |
| p50_ms | 1241 |
| p95_ms | 1314 |
| max_ms | 1314 |

Evidence:
- JSON: `agent-runs/20260617T171130Z-live-task123-single-propagation-prefix-TASK133_PERF_20260617_130313_-p14983.json`.
- CSV: `performance.csv`.

Result: PASS against propagation p50 <= 2000ms and p95 <= 5000ms.

Scope note: existing live harness measures scoped catalog product create propagation, not the stricter TASK-133 concurrent field-level merge fixture.

