# TASK-123 AutoSync Speed — iOS -> Android

RESULT `PARTIAL_PASS_WITH_NOTES`

Post-tuning live runs: 5/5 PASS.

Receiver/apply latency on Android after iOS remote events:
- p50: 0.962s
- p90: 1.002s
- p95: 1.015s
- max: 1.028s
- failures/timeouts: 0/0

Available iOS multi-mutation batch total, including local save + remote push + Android receive:
- p50: 4.555s
- p90: 4.878s
- p95: 4.892s
- max: 4.907s

Strict TASK-123 final acceptance is not claimed because this is 5 post-fix smoke samples, not the required 20 warm iterations, and the batch total contains multiple catalog/price/history writes.
