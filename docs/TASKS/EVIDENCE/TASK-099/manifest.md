# TASK-099 Evidence Manifest

- Task: TASK-099 — Conflict / recovery hardening iOS
- Date: 2026-05-10 19:37 -0400
- Executor: Codex / Executor + Reviewer/Fixer
- Repository: `/Users/minxiang/Desktop/iOSMerchandiseControl`
- Platform used: iOS Simulator, iPhone 17 Pro, iOS 26.4.1
- Targeted XCTest result bundles:
  - Full touched-file targeted suite: `/Users/minxiang/Library/Developer/Xcode/DerivedData/iOSMerchandiseControl-hipxsmlvmjphcyaknnsmrggoalrx/Logs/Test/Test-iOSMerchandiseControl-2026.05.10_19-24-56--0400.xcresult`
  - Review micro-fix recheck (`SupabaseSyncPlanContractTests`, `SupabaseManualSyncViewModelTests`): `/Users/minxiang/Library/Developer/Xcode/DerivedData/iOSMerchandiseControl-hipxsmlvmjphcyaknnsmrggoalrx/Logs/Test/Test-iOSMerchandiseControl-2026.05.10_19-34-13--0400.xcresult`
- Full XCTest result bundle: `/Users/minxiang/Library/Developer/Xcode/DerivedData/iOSMerchandiseControl-hipxsmlvmjphcyaknnsmrggoalrx/Logs/Test/Test-iOSMerchandiseControl-2026.05.10_19-36-07--0400.xcresult`

## Privacy

- No JWT, refresh token, service_role key, Supabase URL secret, connection string, or full email is recorded in this evidence pack.
- No live Supabase write/read-back was required for this diff.
- The existing test account mentioned by the user was not used during TASK-099 execution.
- Evidence is based on deterministic local XCTest/build results and privacy-safe state/category assertions.

## Scope

- Swift / SwiftUI / XCTest / localization changes only.
- No Supabase schema change, SQL migration, RLS/policy change, backend deployment, Android port, or new dependency.
- No Timer, Realtime, BGTask, polling worker, or silent automatic sync introduced.
- TASK-100, TASK-101, and TASK-102 were not created.

## Review closure

- Review outcome: TASK-099 DONE / REVIEW PASS.
- Review fix: permission/RLS now has explicit precedence above stale baseline (`auth > permission/RLS > stale > failure/review`).
- Full suite summary: 630 passed, 5 skipped, 0 failed.
