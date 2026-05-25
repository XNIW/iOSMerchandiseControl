# TASK-123 AutoSync Speed — Android -> iOS

RESULT `PARTIAL_PASS_WITH_NOTES`

Post-tuning live runs: 5/5 PASS.

Receiver/apply latency on iOS after Android remote events:
- p50: 0.409s
- p90: 0.435s
- p95: 0.444s
- max: 0.452s
- failures/timeouts: 0/0

Available Android multi-mutation batch total, including local save + remote push + iOS receive:
- p50: 13.619s
- p90: 16.703s
- p95: 17.714s
- max: 18.724s

Strict TASK-123 final acceptance is not claimed. Android foreground debounce was reduced from 2.0s to 0.5s and improved the path, but the current harness still measures a serial catalog/history matrix batch rather than isolated single propagation samples.
