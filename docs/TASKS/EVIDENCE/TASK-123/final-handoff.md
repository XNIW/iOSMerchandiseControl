# TASK-123 Handoff — ACTIVE / EXECUTION

- **Task**: TASK-123
- **Status**: ACTIVE / EXECUTION
- **Timestamp**: 2026-05-25T03:22Z
- **Executor**: CODEX

## Current Verdict
The original auth blocker is resolved and the same-account simulator/emulator autosync path is working. The task is **not final accepted** yet because the strict speed matrix requested by TASK-123 was not fully run.

## What Passed
- iOS Simulator auth preflight PASS after user login.
- Android Emulator auth preflight PASS.
- iOS Options Review gate resolved safely through the existing Review flow, no real data deletion.
- iOS -> Android and Android -> iOS live mutation-near-realtime smoke passed 5/5 post-tuning runs.
- Receiver/apply latency is fast: iOS -> Android p95 1.015s, Android -> iOS p95 0.444s.
- `TASK123_*` cleanup/residue final: Supabase 0, Android local 0, iOS local 0.
- No Supabase schema/RLS/grant/RPC migration was applied.

## Fixes Applied
- Persist same-account Review binding on iOS.
- Avoid false bootstrap/recovery gate for confirmed same-account binding without baseline.
- Allow `TASK123_` in iOS/Android live harness.
- Advance iOS sync-event watermark on unrecoverable old gap to avoid starvation.
- Reduce Android foreground catalog/history auto-push debounce from 2.0s to 0.5s.
- Allow and evidence Android local cleanup for `TASK123_`.

## What Is Still Not Final
- Required 20 warm iterations per direction were not completed.
- Required 5 cold-ish restart iterations per side were not completed.
- Required 3 no-op checks per side were not completed.
- Required burst-10 scenario was not completed.
- Available batch timing still includes multiple serial matrix writes; strict single-propagation p50/p95 acceptance is not proven.

## NEXT_ACTION
Run a dedicated TASK-123 in-process warm latency harness that keeps both apps authenticated/running, performs isolated local writes, records local save/remote push/remote detect/local apply phases per mutation, then executes:
- 20 warm iOS -> Android iterations.
- 20 warm Android -> iOS iterations.
- 5 cold-ish restart iterations per side.
- 3 no-op checks per side.
- burst-10 small changes.

Only after that should TASK-123 move to REVIEW or claim “100% PASS nel perimetro TASK-123 simulator same-account autosync speed”.
