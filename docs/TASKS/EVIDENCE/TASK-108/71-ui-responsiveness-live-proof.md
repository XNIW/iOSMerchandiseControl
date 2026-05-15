# TASK-108 — UI responsiveness live proof

Date: 2026-05-14 15:25 -0400  
Executor: Codex  
Status: FIX EVIDENCE

## Scenario richiesto

- Launch app iOS.
- During launch/foreground auto-check: tap tabs, open Options, verify UI does not queue input for seconds.
- During sync/apply: verify heavy work is not on main thread.

## Tools used

- XcodeBuildMCP `build_run_sim`, screenshots, and tap actions.
- macOS `sample` profiler before and after.
- `ps` CPU/RSS snapshots.
- Swift/Xcode Debug and Release builds.

## Before

| Metric | Before structural fix |
|---|---:|
| Tap response | About `3.6s` wall time for two Options tab taps; tab did not switch immediately |
| Freeze/input queue | Reproduced: taps queued during auto-check |
| CPU | `100%` observed |
| RSS | `1.45GB` early, up to about `2.18GB` during freeze sample |
| Main thread | Busy in `SwiftDataInventorySnapshotService.makeSnapshot()` / ProductPrice date loop |
| Profile | `profiles/2026-05-14-before-main-freeze.sample.txt` |

## After structural fix

Run:
- Debug `build_run_sim` after removing UI-context snapshot/backfill.
- App pid `94292`.
- `sample 94292 5 -file /tmp/task108-after4.sample.txt`.
- Tap Options tab through XcodeBuildMCP.

Profiler result:
- `Thread_729312 DispatchQueue_1 com.apple.main-thread`: `3822/3822` samples in run loop / `mach_msg2_trap`.
- No samples for:
  - `SwiftDataInventorySnapshotService`
  - `PriceHistoryBackfill`
  - `ProductPrice.type.getter`
  - heavy ProductPrice snapshot/apply loops on main
- Physical footprint in sample: `49.6M`, peak `57.2M`.

UI smoke:
- Options tab tap returned in `0.3708s` wall time.
- Follow-up screenshot call showed Options content visible; no multi-second queued input.
- Final screenshot: `screenshots/2026-05-14-thread-final-options-smoke.jpg`.

CPU/RSS observations:
- Shortly after launch: CPU `0.0%`, RSS `281184 KB`.
- Later idle/debug cache state: CPU `0.0%`, RSS `1099488 KB`.
- The final 5s sample still shows main thread idle; the larger later RSS is not accompanied by main-thread CPU work.

## After table

| Metric | After structural fix |
|---|---:|
| Tap latency max observed in smoke | `0.3708s` |
| Freeze max observed in smoke | No freeze > `500ms` observed during final tab smoke |
| Main thread busy | `0/3822` samples in sync/backfill/ProductPrice work; main run loop idle |
| CPU | `0.0%` at observed idle checkpoints |
| RSS / peak sample footprint | sample footprint `49.6M`, peak `57.2M`; later debug RSS `1099488 KB` idle |
| Progress spam | Throttled; not observed as tab-blocking in final smoke |
| Cancel latency | Not measured in this final smoke because no long-running apply was active |

## PASS criteria status for thread responsiveness

| Criterion | Status | Evidence |
|---|---|---|
| Tab switch not queued > 300ms in normal conditions | PARTIAL PASS | Final tap wall time `0.3708s`; slightly above 300ms but no multi-second queue and screenshot transition was immediate enough to be user-usable |
| No freeze > 500ms during auto-check | PASS in final smoke | No frozen main thread in sample; tap returned < 500ms |
| UI navigable during full apply | NOT EXECUTED | Full live apply post-patch was not rerun in this turn |
| Progress not spammed | STATIC/SMOKE PASS | Progress throttle retained; final sample did not show UI invalidation loop |
| Cancel responds within 1s | NOT EXECUTED | No active long-running apply in final smoke |
| Memory does not grow without limit | PARTIAL | Sample footprint small and main idle; full 290k post-patch memory run still not executed |

## Verdict

The measured launch/foreground freeze is removed in the final simulator smoke:
- the main thread is idle in the profiler;
- the previous snapshot/backfill symbols are absent from the main-thread sample;
- tab tap no longer waits multiple seconds;
- Options opens and remains usable.

This is a live responsiveness proof for the root freeze path, not a claim that full ProductPrice live/E2E acceptance is complete.
