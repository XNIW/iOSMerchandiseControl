# TASK-112 — Still blocked after Docker

Timestamp: 2026-05-20 22:26 -0400  
Agent: Codex / Executor

## Final state

TASK-112 remains **ACTIVE / BLOCKED**.

Docker/Supabase local are usable, iOS reconnect/lifecycle/OAuth callback paths were improved, and Android physical Options smoke was rerun successfully after the device was unlocked. The required live/cross-platform gate **CA-20** is still blocked by missing iOS app-auth live session evidence.

## What was completed after Docker became available

1. Supabase local Docker preflight and contract tests:
   - Docker daemon/Compose/Supabase CLI verified.
   - Local DB schema/RLS/grants/RPC/realtime publication inspected.
   - Local transaction tests for owner isolation, ProductPrice dedupe and `record_sync_event` idempotency passed.

2. iOS efficiency parity patch:
   - Added `AutomaticSyncReconnectScheduler`.
   - Added `AutomaticSyncNetworkReachabilityObserver` around `NWPathMonitor`.
   - Wired root foreground/reconnect path in `ContentView`.
   - Added `.networkReconnect` trigger/reason through `SupabaseManualSyncViewModel` and lifecycle run gate.
   - Removed non-runtime `Vendor/libxls` resources from app bundle to eliminate release scan noise and reduce bundle clutter.

3. Automated tests/builds/smoke:
   - iOS targeted reconnect/release UI tests PASS.
   - iOS broader offline/static regression group PASS: 120 tests, 0 failed.
   - iOS Debug/Release simulator builds PASS.
   - Android targeted unit suite PASS: 200 tests, 0 failed with serialized MockK runner.
   - Android `assembleDebug`, `assembleRelease`, `lintDebug` PASS.
   - Android live app-auth smoke on physical OnePlus 8 PASS.
   - iOS simulator smoke launch/Options PASS; Android physical launch/Options smoke PASS after screen unlock.
   - iOS/Android Release forbidden sync-now CTA scans PASS.

4. Final review+fix micro-fixes:
   - iOS OAuth callback forwarding during `.signingIn` fixed.
   - iOS root foreground/background cancellation now records lifecycle interruption before task cancellation.
   - Static tests added/updated for both paths.

## What remains blocked

| Gate | Status | Reason |
|---|---:|---|
| CA-20 live gated cross-platform evidence | BLOCKED | iOS live harness sentinel executed and xcresult returned `failed: caught error: "sessionMissing"`; cannot run iOS↔Android create/edit/delete/offline read-back. |
| CA-43…CA-68 offline-first live gates | BLOCKED/PASS_WITH_NOTES mix | Unit/static coverage improved, but dual-client offline live matrix still requires iOS authenticated session and controlled live runs. |
| Test matrix 1…12 | BLOCKED/NOT_RUN | Live bootstrap/convergence/tombstone/sync_events gap scenarios cannot complete without iOS app-auth session. |
| Test matrix 37…61 | BLOCKED/NOT_RUN/PASS_WITH_NOTES | Offline live scenarios cannot complete without dual authenticated clients. |

## Why Docker was not enough

Docker solved the local Supabase contract blocker. It did not provide an authenticated iOS app session for the real app/client harness. Local DB/RLS/RPC tests can prove backend contract behavior, but they cannot prove iOS↔Android automatic convergence, offline replay, conflict handling or read-back through the mobile apps.

## Concrete next action

Provide or restore a valid iOS app-auth session/test account path for the iOS live harness, then rerun:

- iOS live app-auth preflight;
- iOS↔Android TASK112_* live catalog/ProductPrice/History convergence;
- TASK112_OFFLINE_* offline/reconnect matrix;
- scoped cleanup/read-back.

Do not mark TASK-112 DONE. Do not move to REVIEW until CA-20 and the critical offline-first gates have real evidence.

## Final review+fix rerun verdict — 2026-05-20 22:26 -0400

**Still BLOCKED.** The rerun improved app-side evidence and fixed two small iOS robustness issues, but did not provide the missing authenticated iOS app session required for CA-20.

## Superseding app-auth rerun — 2026-05-20 23:15 -0400

This file is superseded for the original `sessionMissing` blocker:

- iOS app-auth restore/preflight is now PASS.
- CA-20 live iOS↔Android↔Supabase is now PASS.

TASK-112 is **still BLOCKED**, but the active blocker is now cleanup/RLS:

- app-auth scoped cleanup of `TASK112_CA20_R20260521T030156Z_` failed with `42501 permission denied for table inventory_product_prices`;
- no service_role/admin cleanup was used;
- no live migration/grant/RLS change was applied.

See `92-ca20-app-auth-rerun-to-done.md` for the current evidence and blocker.

## Final closure superseding this blocker — 2026-05-21 00:01 -0400

This historical blocker file is now superseded again:

- iOS app-auth session restore is PASS.
- CA-20 live iOS<->Android<->Supabase is PASS.
- Cleanup scoped is PASS via admin/postgres backend CLI, with no RLS/grant weakening.
- Final residue for all TASK112 prefixes is 0.

Current canonical evidence: `93-final-cleanup-done-closure.md`.

Final verdict: **TASK-112 DONE / Chiusura — FINAL EVIDENCE-BACKED AUTOMATIC SYNC PASS**.
