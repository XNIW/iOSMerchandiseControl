# TASK-135 Final History Parity Summary

Status: PARTIAL FIX / READY FOR REVIEW OF iOS PATCH, NOT DONE

## Canonical Counts

| surface | products | suppliers | categories | product_prices | history_sessions |
|---|---:|---:|---:|---:|---:|
| Supabase | NOT RUN | NOT RUN | NOT RUN | NOT RUN | NOT RUN |
| iOS | NOT RUN live | NOT RUN live | NOT RUN live | NOT RUN live | covered by targeted tests |
| Android | BLOCKED | BLOCKED | BLOCKED | BLOCKED | BLOCKED |

## History Row-Level Metrics

| metric | Supabase | iOS | Android |
|---|---:|---:|---:|
| active history sessions | NOT RUN | NOT RUN live | BLOCKED |
| tombstoned history sessions | NOT RUN | NOT RUN live | BLOCKED |
| TASK135 history fixtures | NOT RUN | STATIC count excludes `TASK*` | BLOCKED |
| duplicate remote_id | NOT RUN | NOT RUN live | BLOCKED |
| duplicate fingerprint | NOT RUN | in-memory logical dedupe test PASS | BLOCKED |
| missing remote_id visible rows | NOT RUN | in-memory relink test PASS | BLOCKED |
| payload hash mismatches | NOT RUN | NOT RUN live | BLOCKED |

## Checks

- iOS targeted tests: PASS, 18/18 via XcodeBuildMCP.
- iOS Debug build: PASS, no warnings via XcodeBuildMCP.
- `git diff --check`: PASS.
- service_role/RLS bypass scan: PASS_WITH_NOTE, hits are existing guard/tests only.

## Not Run / Blocked

- Android emulator/Room snapshots: BLOCKED, `adb` unavailable and Android repo absent.
- Supabase row-level snapshot: BLOCKED, local Supabase container unavailable.
- Required simulator/emulator screenshots: NOT RUN, Android emulator unavailable.

