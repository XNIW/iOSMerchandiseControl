# TASK-109 — 110 Review Final Verdict

Review pass: 2026-05-15 02:25 -0400

## Verdict

BLOCKED_WITH_PLAYBOOK / CHANGES_REQUIRED.

TASK-109 must remain ACTIVE / REVIEW — CHANGES_REQUIRED. Do not mark DONE.

## Root cause review

Confirmed with correction.

- Confirmed: TASK-109 implementation fixes the core architectural regression in code: root/app-scoped sync, Options observer/manual trigger, no stale/no-op Review, cleaner Cancel behavior, and History count visibility.
- Corrected in review: direct/root sync now defers History sync until staged catalog/price apply completes.
- Not confirmed runtime: live non-empty History iOS pull.

## Blocking stop conditions

- Stop 11: History live non-empty has not been validated in iOS runtime.
- Stop 12: Options `History sessions` remains `0` while Supabase now has one applicable test session, because app runtime is signed-out.
- Stop 13/14 live History second sync no-duplicate is not validated.
- Stop 23: smoke runtime was executed, but signed-in portions were not executable in current simulator session.

## Non-blocking passes

- Debug build PASS.
- Release build PASS.
- Targeted XCTest PASS on rerun.
- Localization lint PASS.
- `git diff --check` PASS.
- Supabase seed creation PASS and owner-scoped counts PASS.
- Android parity static audit PASS_WITH_NOTES, no Kotlin patch required.

## Required playbook to close

1. Restore app-auth on iOS simulator/device for the owner hash documented in `104-review-history-live-non-empty.md`.
2. Run Sync now or cold-launch auto-check.
3. Verify local SwiftData `ZHISTORYENTRY > 0`.
4. Verify Options `History sessions > 0`.
5. Verify History tab row visible.
6. Run a second sync and verify no duplicate History row.
7. Cleanup or explicitly retain `TASK109_REVIEW_HISTORY_20260515_0622Z`.

## Tracking decision

- TASK-109: ACTIVE / REVIEW — CHANGES_REQUIRED.
- MASTER-PLAN: ACTIVE / REVIEW — CHANGES_REQUIRED.
- Conditional user DONE confirmation is not consumed because final review is not APPROVED.
