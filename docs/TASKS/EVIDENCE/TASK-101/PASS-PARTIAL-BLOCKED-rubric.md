# PASS / PARTIAL / BLOCKED Rubric

| Area | PASS condition | TASK-101 result |
|---|---|---|
| iOS client privacy/security | No consumer secrets; sanitizer covers sensitive shapes; auth display privacy-safe; build/test pass. | PASS |
| Supabase RLS owner scope | Core tenant tables have owner RLS and no ordinary cross-tenant route observed. | PASS |
| Grants least privilege | No unsafe client grants on privileged functions/tables; migration state aligned. | PARTIAL |
| Auth/session | App code handles sign-in/out/refresh and does not persist tokens directly. | PASS_STATIC |
| Live write/delete safety | Writes scoped and cleanup policy explicit; no uncontrolled data mutation. | PASS |
| Retention/cleanup | Policy plus automated or operationally accepted lifecycle. | PARTIAL |
| Cross-platform parity | iOS and Android both verified and privacy gaps closed. | PARTIAL |
| Evidence quality | Complete, redacted, traceable. | PASS |

No area is BLOCKED after TASK-101 execution. Global decision is PARTIAL because backend migration drift, auth dashboard setting, retention automation and Android log privacy remain open.

