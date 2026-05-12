# TASK-101 Evidence Manifest

## Snapshot

| Item | Value |
|---|---|
| Timestamp | 2026-05-11 00:03 -0400 |
| iOS repo | `/Users/minxiang/Desktop/iOSMerchandiseControl` |
| iOS branch / commit at start | `main`, `fe585fcbe215e32b789478c924015c907beb57a4` |
| Android repo | `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView` |
| Android branch / commit at start | `main`, `d5ab72c52e5e91a2df6c41397914c029e6ed7d83` |
| Supabase workspace | `/Users/minxiang/Desktop/MerchandiseControlSupabase` |
| Supabase CLI | `2.90.0` |

## Scope Actually Executed

- Static audit iOS, Android reference, Supabase local migrations and live DB metadata.
- Live Supabase metadata queries for RLS, grants, functions, event trigger and migration state.
- One live DDL remediation: revoked direct client-role EXECUTE on `public.rls_auto_enable()`; no table rows inserted, updated, deleted or exported.
- iOS remediation for privacy-safe diagnostics, owner-scoped defense-in-depth filters, create-payload owner validation, debug-only logging, privacy-safe auth display and hashed plan-derived sync identifiers.
- Targeted XCTest, full XCTest and Release simulator build.
- Review/fix pass reconciled task/evidence state and documented residual non-executable Supabase local/linked checks.

## Files Created In This Evidence Pack

- `TRACEABILITY-S101-CA-M101.md`
- `MATRIX-M101-results.md`
- `findings-register.md`
- `data-flow-map.md`
- `threat-model.md`
- `ios-local-privacy-audit.md`
- `rls-policy-inventory.md`
- `grants-audit.md`
- `auth-session-audit.md`
- `secrets-scan-notes.md`
- `logging-privacy-audit.md`
- `owner-scope-matrix.md`
- `live-write-safety-audit.md`
- `cleanup-retention-policy.md`
- `android-ios-security-parity.md`
- `ux-privacy-accessibility-notes.md`
- `test-build-runtime-report.md`
- `PASS-PARTIAL-BLOCKED-rubric.md`
- `decision-final.md`

## Privacy Guard

No real email address, full owner UUID, JWT, refresh token, service-role key, connection string, raw project URL, barcode catalog dump or production/customer dataset is intentionally copied into this evidence pack. Synthetic examples use `example.test` / `example.supabase.co`.
