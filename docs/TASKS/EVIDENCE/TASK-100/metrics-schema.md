# TASK-100 Metrics Schema

Raw rows are stored in `metrics.jsonl` and summarized in `performance-summary.md`.

| Column | Description |
|--------|-------------|
| `scenario_id` | S100/M100 scenario identifier |
| `dataset_class` | `D100-S`, `D100-M`, `D100-L`, or `not_applicable` |
| `device_target` | Simulator/device/test harness target |
| `row_counts` | Aggregate counts only |
| `file_size_mb` | XLSX/import/export size where applicable |
| `time_to_first_feedback_s` | Time from action start to observable progress/running state in the tested surface |
| `total_duration_s` | Total scenario duration |
| `result_state` | `PASS`, `PARTIAL`, `BLOCKED`, or `SKIPPED` |
| `failure_mode` | `none` or short redacted failure |
| `notes_redacted` | Short privacy-safe note |

Notes:

- `time_to_first_feedback_s=0.000` for pure synthetic/component runs means the harness entered work immediately; it is not a manual UI screen-recording measurement.
- `device_target` may identify Simulator, physical iPhone XCTest, or live Supabase authenticated read/write/read-only verification.
- Live Supabase rows must remain aggregate-only and must use a `TASK100_*` prefix in notes/row counts.
- Simulator-only timings support scenario acceptance but not a global production-ready performance claim.
