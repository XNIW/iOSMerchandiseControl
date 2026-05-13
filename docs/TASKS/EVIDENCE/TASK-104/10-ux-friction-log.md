# UX Friction Log

Status: `PASS_WITH_NOTES`

| ID | Area | Severity | Observation | Routing |
|----|------|----------|-------------|---------|
| UX104-01 | Verdict boundary | P1 | No real shop run can be claimed without an explicit operator-selected file, backup/rollback owner, and sentinel list. | Accepted note for PASS2; blocks only real-user-data/no-notes claims. |
| UX104-02 | Supabase/Ops | P2 | PASS1 linked CLI reads were unstable; PASS2 used authenticated client sessions for live scoped read/write/read-back. | No TASK-104 blocker; shell diagnostics can remain optional Ops follow-up. |
| UX104-03 | Android launch | P2 | Physical Android app launched to the expected Italian inventory/home surface. No operator feedback was available. | No immediate action; validate with operator during real run. |
| UX104-04 | iOS copy | P2 | Localization files linted successfully; no real operator copy review was performed. | Review during user acceptance. |

No UI/UX code was changed in TASK-104. P1/P2 observations are routed as notes only; no executed-path P0 UX blocker remains for the realistic synthetic verdict.
## PASS 2 Update

Observed/retained UX notes:

- UX104-01: scanner hardware camera was not validated in PASS2; manual fallback remains accepted only with notes.
- UX104-02: manual share destination was not operator-confirmed; export file integrity did pass.
- UX104-03: broad Android JVM unit suite is blocked by local ByteBuddy attach; keep separate from operator UX but route as engineering environment follow-up.
- UX104-04: no full manual iOS PreGenerate -> Generated -> History tap-through was performed in PASS2; service/model path passed.

No P0 UX blocker was found in the executed live sync path.
