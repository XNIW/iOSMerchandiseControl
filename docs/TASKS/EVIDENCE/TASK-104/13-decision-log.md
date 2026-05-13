# Decision Log

Status: `PASS`

| Time | Decision | Reason | Impact |
|------|----------|--------|--------|
| Execution start | Promote TASK-104 to EXECUTION by explicit user override. | User declared planning approved and requested end-to-end execution. | Planning gate bypass documented; task remains NON DONE. |
| Preflight | Do not open discovered real Excel candidates. | No operator-selected file, file-specific consent, or backup was available. | Real import criteria marked BLOCKED. |
| Supabase | Do not perform live writes. | Owner/session and backup gates were incomplete; later linked read hit auth/circuit-breaker failure. | Bidirectional real sync criteria marked BLOCKED/PARTIAL. |
| Device smoke | Install/launch iOS and Android apps. | Authorized and non-destructive; useful for preflight evidence. | Device criteria PASS, session criteria PARTIAL. |
| Code changes | Do not patch Swift/Kotlin/SQL. | No code blocker was proven by the available checks; real-data blockers were operational gates. | Codebase remains unchanged except tracking/evidence. |
| PASS 1 verdict | Propose TASK-104 `PARTIAL`. | Several build/test/device/static checks passed, but core real-shop acceptance was not safely executable. | Superseded by PASS 2 realistic synthetic run; real-user-data/no-notes claims remain disallowed. |
| Routing | Do not open TASK-105. | User explicitly required TASK-105 remain unopened. | Follow-up notes recorded only in evidence. |
## PASS 2 Decisions

- DEC-104-P2-01: Use synthetic realistic data instead of real shop files because the user authorized it and it avoids committing or exposing shop data.
- DEC-104-P2-02: Extend TASK-103 live acceptance harness for TASK104_PASS2 env/prefix gates instead of introducing a new production feature path.
- DEC-104-P2-03: Use physical iOS and Android authenticated client sessions for Supabase writes; no service_role and no RLS bypass.
- DEC-104-P2-04: When Android was signed out, stop writes, complete UI sign-in, then rerun auth preflight before any mutation.
- DEC-104-P2-05: Retain scoped synthetic rows for review rather than deleting immediately; record residue counts and require future cleanup to be prefix-scoped.
- DEC-104-P2-06: Classify broad Android JVM unit failure as environment/tooling note because live Android instrumentation passed and failures share ByteBuddy attach root cause.
- DEC-104-P2-07: Propose `PASS_WITH_NOTES`, not no-notes PASS, because real shop data, hardware scanner and final operator acceptance remain unproven.

## Final Review Decision

- DEC-104-REV-01: Close TASK-104 as `DONE / Chiusura — REVIEW PASS FINAL / PASS_WITH_NOTES` after independent review and targeted fixes.
- DEC-104-REV-02: Keep the verdict limited to realistic synthetic shop acceptance; do not claim real user data acceptance, production-ready global, production no-notes or global 100%.
- DEC-104-REV-03: Keep TASK-105 unopened; residual notes stay documented as accepted notes/future planning inputs, not a newly opened task.
