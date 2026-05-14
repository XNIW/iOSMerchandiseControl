# TASK-108 Evidence 00 — Audit Options State

Status: EXECUTED (STATIC + BUILD + UNIT + SIM smoke).

Initial findings:
- Release card is driven by `SupabaseManualSyncViewModel.presentationState`.
- DEBUG Options sections read `SupabaseAuthViewModel` and manual sync diagnostics directly, so OAuth can show signed-in while Release presents a sign-in recovery CTA.
- `SupabaseManualSyncViewModel` maps remote preview auth failures to `.blockedAuth`; when OAuth is already signed in, the primary Sign in action can be disabled because `canSignIn == false`.
- Baseline absence is currently a coordinator block before remote preview/apply in the Release path, which prevents first-download UX from behaving like a bootstrap.

No PASS claimed yet.

Result:
- Added `CloudSyncOverviewState` reducer to separate OAuth, remote access, baseline, pending and review states.
- Release UI no longer maps a signed-in remote auth/permission failure to an inert Sign in CTA; signed-in recovery is now Check cloud / account check.
- DEBUG auth diagnostics are under a collapsed disclosure in Options.
- Simulator reached Options successfully after Debug build/run; screenshot captured in `options-smoke-debug.jpg`.

FIX/COMPLETION update 2026-05-13:
- Re-ran full iOS XCTest after final Options copy/boundary fixes: PASS 659/0.
- Options signed-out smoke and Dynamic Type XXXL smoke captured in `screenshots/2026-05-13-options-release-signed-out.jpg` and `screenshots/2026-05-13-options-dynamic-type-xxxl.jpg`.
- Release and DEBUG surfaces stayed non-contradictory in signed-out simulator state; authenticated live state remains NOT RUN.
