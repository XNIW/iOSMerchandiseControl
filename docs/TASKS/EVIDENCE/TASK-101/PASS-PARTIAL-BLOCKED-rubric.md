# PASS / PARTIAL / BLOCKED Rubric

| Area | PASS condition | TASK-101 result |
|---|---|---|
| iOS client privacy/security | No consumer secrets; sanitizer covers sensitive shapes; auth display privacy-safe; build/test pass. | PASS |
| Supabase RLS owner scope | Core tenant tables have owner RLS and no ordinary cross-tenant route observed. | PASS |
| Grants least privilege | No unsafe client grants on privileged functions/tables; migration state aligned or non-blocking registry drift is evidenced. | PASS_WITH_OPS_NOTE |
| Auth/session | App code handles sign-in/out/refresh and does not persist tokens directly. | PASS |
| Live write/delete safety | Writes scoped and cleanup policy explicit; no uncontrolled data mutation. | PASS |
| Retention/cleanup | Policy plus automated or operationally accepted lifecycle. | PASS_POLICY |
| Cross-platform parity | iOS and Android both verified and privacy gaps closed. | PASS |
| Evidence quality | Complete, redacted, traceable. | PASS |

No area is BLOCKED after the final TASK-101 review. Global decision is DONE for TASK-101 because backend drift was classified as non-blocking registry/history drift with live objects present, auth leaked-password protection is a dashboard Ops note for password-login scenarios, retention is operationally documented, and the Android log privacy gap was fixed.
