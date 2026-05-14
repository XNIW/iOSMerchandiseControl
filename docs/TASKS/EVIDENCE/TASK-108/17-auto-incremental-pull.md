# TASK-108 Evidence 17 — Auto Incremental Pull

Status: IMPLEMENTED (CODE), PARTIAL evidence.

Initial audit:
- Existing `SupabaseManualSyncLifecycleRunGate` and `SupabaseManualSyncForegroundAutomaticGate` provide debounce/cooldown and owner/app lifecycle gates.
- Existing behavior starts a dry-run foreground check but does not auto-apply safe remote changes.

Result:
- `startForegroundSemiAutomaticCheckIfAllowed(source: .rootForeground)` now auto-applies only if:
  - baseline status is valid;
  - preview is complete, non-partial, non-cancelled;
  - no remote failure category exists;
  - remote signals exist;
  - no local pending work is present;
  - local apply eligibility is true.
- Missing/invalid baseline is excluded from automatic apply; bootstrap remains user-triggered.

Evidence:
- Existing foreground gate/debounce tests still PASS in `SupabaseManualSyncViewModelTests`.
- Dedicated simulator launch/foreground auto-apply smoke NOT RUN.

FIX/COMPLETION update 2026-05-13:
- Full suite includes TASK-091/TASK-092 lifecycle and debounce regression tests and passed 659/0.
- Simulator foreground relaunch smoke was run and did not crash or start duplicate visible work in signed-out state.
- Live signed-in incremental pull remains NOT RUN without an authenticated app session.

Targeted Options cleanup FIX update 2026-05-13 20:45 -0400:
- UI cleanup did not introduce a new `.onAppear`/scenePhase trigger.
- App-auth reached Google credential prompt but no signed-in baseline exists.
- Live incremental pull remains NOT RUN / BLOCKED_APP_AUTH. Evidence: `25-live-incremental-pull-smoke.md`.

Post-TASK-108 targeted FIX update 2026-05-14 00:38 -0400:
- A signed-in iOS simulator session was available for one global `Sync now` attempt.
- The run populated local catalog/ProductPrice data, but baseline records stayed `0`, so a true incremental delta pull after valid baseline was not verified.
- No remote mutation was created with `TASK108_SYNC_*`, and no remote delta was pulled back on launch/foreground.
- Current status for real incremental pull: NOT VERIFIED / BLOCKED BY INVALID BASELINE + missing controlled remote delta.
