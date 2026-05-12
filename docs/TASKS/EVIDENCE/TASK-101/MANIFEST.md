# TASK-101 Evidence Manifest

## Snapshot

| Item | Value |
|---|---|
| Timestamp | 2026-05-12 12:46 -0400 |
| iOS repo | `/Users/minxiang/Desktop/iOSMerchandiseControl` |
| iOS branch / commit at review start | `main`, `71dcbb4f3f91a03fb38e1743ec945784d376e1d9` |
| Android repo | `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView` |
| Android branch / commit at review start | `main`, `d5ab72c52e5e91a2df6c41397914c029e6ed7d83` |
| Supabase workspace | `/Users/minxiang/Desktop/MerchandiseControlSupabase` |
| Supabase CLI | `2.98.2` |

## Scope Actually Executed

- Static audit iOS, Android reference, Supabase local migrations and live DB metadata.
- Live Supabase metadata queries for RLS, grants, functions, event trigger and migration state.
- One live DDL remediation: revoked direct client-role EXECUTE on `public.rls_auto_enable()`; no table rows inserted, updated, deleted or exported.
- iOS remediation for privacy-safe diagnostics, owner-scoped defense-in-depth filters, create-payload owner validation, debug-only logging, privacy-safe auth display and hashed plan-derived sync identifiers.
- Targeted XCTest, full XCTest and Release simulator build rerun on iOS 26.5 after installing the missing local simulator runtime.
- Supabase local and linked lint rerun with no schema errors.
- Android raw `userId` runtime log remediated and Android unit/lint/debug/release build checks rerun.
- iOS app-level `PrivacyInfo.xcprivacy` added, linted and verified in the Release simulator app bundle.
- Migration drift classified by read-only introspection as non-blocking registry/history drift.
- Review/fix pass reconciled task/evidence state and closed the previously open TASK-101 findings as either remediated or documented non-blocking Ops follow-up.

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
- `supabase-local-status.txt`
- `supabase-local-db-lint.txt`
- `supabase-linked-migration-list.txt`
- `supabase-linked-db-lint.txt`
- `supabase-linked-query-sanity.txt`
- `supabase-linked-drift-introspection.txt`
- `supabase-local-drift-introspection.txt`
- `supabase-migration-drift-analysis.md`
- `privacy-scan-final.txt`
- `android/`
- `ios/`

## Privacy Guard

No real email address, full owner UUID, JWT, refresh token, service-role key, connection string, raw project URL, barcode catalog dump or production/customer dataset is intentionally copied into this evidence pack. Literal role names and placeholder strings may appear where they are necessary to document policies or scans.
