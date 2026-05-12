# TASK-101 Traceability Matrix

| Slice | Acceptance criteria | M101 | Evidence | Risk | Decision |
|---|---|---|---|---|---|
| S101-A Preflight | CA-T101-08, CA-T101-10 | M101-01 | `MANIFEST.md`, `test-build-runtime-report.md` | R101-10 | PASS |
| S101-B RLS inventory | CA-T101-02, CA-T101-03 | M101-02 | `rls-policy-inventory.md` | R101-01, R101-02 | PASS |
| S101-C Owner scope | CA-T101-02, CA-T101-09 | M101-04 | `owner-scope-matrix.md`, `data-flow-map.md` | R101-06, R101-07 | PASS |
| S101-D Auth/session | CA-T101-04, CA-T101-10 | M101-05 | `auth-session-audit.md`, `ios-local-privacy-audit.md`, `ios/simulator-smoke-ios-26.5.txt` | R101-03, R101-04 | PASS |
| S101-E service_role/admin | CA-T101-01, CA-T101-04 | M101-06 | `secrets-scan-notes.md`, `grants-audit.md` | R101-03 | PASS |
| S101-F Logging/privacy | CA-T101-01, CA-T101-08, CA-T101-10 | M101-09 | `logging-privacy-audit.md`, `ios-local-privacy-audit.md`, `test-build-runtime-report.md` | R101-04, R101-05 | PASS |
| S101-G Live write/delete safety | CA-T101-05, CA-T101-06 | M101-07, M101-08 | `live-write-safety-audit.md`, `rls-policy-inventory.md` | R101-02, R101-08 | PASS_WITH_ADMIN_CLEANUP_CAVEAT |
| S101-H Retention/cleanup | CA-T101-07 | M101-10 | `cleanup-retention-policy.md` | R101-08 | PASS_POLICY |
| S101-I Android parity | CA-T101-09 | M101-11 | `android-ios-security-parity.md`, `android/` | R101-07 | PASS |
| S101-J Risk routing | CA-T101-01..10 | M101-12 | `findings-register.md` | R101-01..10 | PASS |
| S101-K Final decision | CA-T101-01..10 | M101-12 | `decision-final.md` | R101-10 | DONE |
