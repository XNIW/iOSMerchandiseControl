# Threat Model

| Asset | Threat | Existing / added controls | Residual |
|---|---|---|---|
| Supabase user session | Token leak in logs/evidence | App code does not print tokens; sanitizer drops auth/JWT/token messages; config rejects server-only keys. | SDK storage implementation not deeply audited beyond app code. |
| Tenant inventory rows | Cross-tenant read/write | RLS owner policies; TASK-101 explicit owner filters on iOS reads/read-backs/updates. | Migration drift should be reconciled. |
| Sync events | Sensitive metadata stored remotely | RPC allowlist and denylist; iOS sanitizer/outbox tests; metadata budget enforced server-side. | Advisor warning on SECURITY DEFINER RPC accepted as intentional because caller is `authenticated` and owner is `auth.uid()`. |
| Evidence/docs | PII/secrets in task artifacts | Evidence uses redacted hashes and synthetic examples; scans run for secret-like patterns. | Historical DONE docs contain old full account references; not changed due DONE tracking rules. |
| UI screenshots | Full account ID/email visible | iOS account display now masks UUID/email in Options. | Android reference still logs raw userId. |
| Test data | Unsafe cleanup / deletion | Inventory DELETE is not granted to `authenticated`; cleanup requires operator/admin path; no data rows mutated in TASK-101. | Retention automation not implemented in this task. |
| Backend functions | SECURITY DEFINER callable by client roles | `rls_auto_enable()` public/anon/auth execute revoked and verified. | Auth leaked-password setting still open in Supabase dashboard. |

