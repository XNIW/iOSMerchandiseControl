# TASK-108 — Final live sync E2E

Date: 2026-05-14 15:25 -0400  
Executor: Codex  
Status: NOT EXECUTED IN THIS FIX

## Requested live scenarios

- Full live post-patch ProductPrice apply with real dataset around `290k`.
- Incremental pull using `TASK108_THREAD_PULL_*`.
- Incremental push using `TASK108_THREAD_PUSH_*`.
- Generated apply/update/read-back.
- History/session update/read-back and dirty clear only after ack.

## Status

| Scenario | Stato | Evidence |
|---|---|---|
| Full ProductPrice post-patch rerun | ❌ NON ESEGUITO | Structural thread fix was verified by profiler/smoke, but the 290k live rerun was not completed |
| Idempotent no-op live rerun | ❌ NON ESEGUITO | Not run |
| Incremental pull live | ❌ NON ESEGUITO | No `TASK108_THREAD_PULL_*` remote row created |
| Incremental push live | ❌ NON ESEGUITO | No `TASK108_THREAD_PUSH_*` local/remote row created |
| Generated live | ❌ NON ESEGUITO | Not run |
| History/session live | ❌ NON ESEGUITO | Not run |
| Supabase cleanup | ⚠️ NON ESEGUIBILE | No new scoped live test data created |

## Why this file exists

The user requested final live sync E2E evidence. This pass fixed and proved the measured thread/MainActor freeze path, but did not complete the full live E2E matrix. The tracking must preserve that gap instead of converting a thread fix into a false global PASS.

## Verdict

Final live sync E2E remains open. TASK-108 must stay NON DONE until these rows are executed successfully or explicitly accepted as blocked by the reviewer/user.
