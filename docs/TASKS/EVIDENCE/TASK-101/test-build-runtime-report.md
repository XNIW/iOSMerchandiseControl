# Test / Build / Runtime Report

## Build And XCTest

| Check | Command | Result | Evidence |
|---|---|---|---|
| Xcode schemes | `xcodebuild -list -project iOSMerchandiseControl.xcodeproj` | PASS | Scheme/target list available. |
| Targeted XCTest | `xcodebuild test ... -only-testing:SupabaseConfigSecurityTests -only-testing:SyncEventOutboxStateTests -only-testing:SupabaseSyncEventDebugViewModelTests -only-testing:SupabaseManualPushServiceTests` | PASS | `Test-iOSMerchandiseControl-2026.05.10_23-01-18--0400.xcresult` |
| Review targeted XCTest | `xcodebuild test ... -only-testing:SyncEventOutboxEnqueueServiceTests -only-testing:SyncEventOutboxStateTests` | PASS | `Test-iOSMerchandiseControl-2026.05.10_23-49-25--0400.xcresult` |
| Review TASK-101 suite | `xcodebuild test ... -only-testing:SupabaseConfigSecurityTests -only-testing:SupabaseSyncEventDebugViewModelTests -only-testing:SupabaseManualPushServiceTests -only-testing:SyncEventOutboxStateTests -only-testing:SyncEventOutboxEnqueueServiceTests` | PASS | `Test-iOSMerchandiseControl-2026.05.10_23-51-11--0400.xcresult` |
| Full XCTest | `xcodebuild test -project iOSMerchandiseControl.xcodeproj -scheme iOSMerchandiseControl -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4.1'` | PASS | Final review rerun `Test-iOSMerchandiseControl-2026.05.11_00-00-42--0400.xcresult`: 640 passed, 12 skipped, 0 failed. |
| Release build | `xcodebuild build -configuration Release -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.4.1'` | PASS | Build succeeded. |
| New warnings | Release build log scan | PASS_WITH_NOTE | Only AppIntents metadata warning remains; no task-introduced Swift warning after fix. |
| Diff whitespace | `git diff --check` | PASS | No output. |
| Evidence redaction scan | `rg` scan over TASK-101 task/evidence for emails, JWT-like tokens, bearer/API key shapes, connection strings and raw Supabase REST URLs | PASS | No output for token/email/connection string patterns; UUID/long-number scan only matched a migration timestamp. |

## Supabase Runtime / Schema

| Check | Result | Notes |
|---|---|---|
| Linked query sanity | PASS | `select now()` succeeded. |
| RLS/policy inventory | PASS | Live metadata queried. |
| Grants inventory | PASS | Live metadata queried before/after remediation. |
| Function grant hardening | PASS | `rls_auto_enable()` client-role EXECUTE revoked and verified. |
| Schema lint, execution evidence | PASS_REPORTED | Earlier TASK-101 execution recorded `supabase db lint --linked --level warning` with no schema errors. |
| Schema lint, review rerun | NON ESEGUIBILE | `supabase db lint --linked --level warning` could not authenticate to linked Postgres in this review (`SUPABASE_DB_PASSWORD` not available/accepted). Current review therefore does not treat linked lint as freshly verified. |
| Migration list | PARTIAL | `supabase migration list --linked` rerun; live/local migration drift remains, including local-only `20260511030000` and remote-only `20260424145010`. |
| Local Supabase Docker status | NON ESEGUIBILE | `docker` command unavailable / Docker daemon not reachable, so `supabase start`, `supabase status` and local lint/dump could not run. |

## Runtime Data

No test rows were created, updated or deleted. TASK-101 performed metadata reads and one scoped DDL privilege update only. The review pass performed no destructive Supabase operation.
