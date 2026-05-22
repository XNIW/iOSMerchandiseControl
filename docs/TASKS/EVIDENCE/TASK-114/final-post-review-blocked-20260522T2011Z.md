# TASK-114 final post-review override — BLOCKED_EXTERNAL_DEVICE

Date: 2026-05-22 16:11 -0400
Agent: Codex

## Verdict
**BLOCKED_EXTERNAL_DEVICE / CHANGES_REQUIRED, non DONE.**

The final code/harness cleanup pass is complete and the critical sync evidence is green, but the required Android-dependent rerun after the last iOS recovery fix could not complete because the physical device `8ac48ff0` is on keyguard and the emulator is signed out.

## Fixes applied
- Confined TASK-114 runtime diagnostics to DEBUG in `ContentView` and `SupabaseSyncEventIncrementalApplyService`.
- Recorded the last actual event apply sync type in `SupabaseManualSyncViewModel`.
- Updated `live mutation-near-realtime` reporting to prefer the last applied event type over later light reconcile/checkpoint diagnostics.
- Preserved the TASK-114 default-task inference fix in `tools/agent/lib/common.sh`.
- Preserved Android ES/ZH translations for `local_database_status_reconcile`.
- Made iOS full-pull recovery safer by detaching and saving Product -> Supplier/Category relationships before hard-deleting clean unreferenced lookup rows.

## Green gates
| Gate | Evidence | Result |
|---|---|---|
| Supabase verify-grants linked | `20260522T193037Z-supabase-verify-grants-task-TASK-114-profile-linked-p74485` | PASS |
| Near-realtime online | `20260522T193948Z-live-mutation-near-realtime-task-TASK-114-prefix-TASK114_REALTIME_-p88360` | PASS |
| Offline reconnect | `20260522T194316Z-live-offline-reconnect-sync-task-TASK-114-prefix-TASK114_OFFLINE_-p93884` | PASS |
| Cleanup/residue `TASK114_REALTIME_` | dry `p99254`, execute `p99832`, residue `p563` | PASS/0 |
| Cleanup/residue `TASK114_OFFLINE_` | dry `p1299`, execute `p1854`, residue `p2387` | PASS/0 |
| Cleanup/residue `TASK114_REVIEW_` | dry `p2926`, execute `p3490`, residue `p4046` | PASS/0 |
| Reconcile post-cleanup | `20260522T195315Z-live-reconcile-counts-task-TASK-114-prefix-TASK114_RECON_-p13640` | PASS |
| Runtime parity post-cleanup | `20260522T195333Z-live-runtime-parity-task-TASK-114-prefix-TASK114_RUNTIME_-p14356` | PASS |
| iOS runtime counts after final fix | `20260522T200353Z-ios-runtime-ui-counts-live-task-TASK-114-p78185` | PASS |
| iOS targeted prune tests | raw xcodebuild `SupabasePullApplyServiceTests`, 36/36 | PASS |
| iOS build/test after final fix | Debug `p80679`, Release `p81342`, sync `p82043` | PASS |
| Android build/test/lint | Debug `p22860`, Release `p23393`, sync `p23856`, `./gradlew :app:lintDebug` | PASS |
| Scans/report before tracking update | sensitive `p24430`, evidence `p24756`, report `p77585` | PASS |

## Sync timings
| Direction | Receiver time | Sync type | Full pull used |
|---|---:|---|---|
| iOS -> Android online | 3660 ms | EVENT_INCREMENTAL | false |
| Android -> iOS online | 524 ms | EVENT_INCREMENTAL | false |
| iOS offline -> online -> Android | 3495 ms apply after reconnect | EVENT_INCREMENTAL | false |
| Android offline -> online -> iOS | 507 ms apply after reconnect | EVENT_INCREMENTAL | false |

## Domain coverage
Product, Supplier, Category, ProductPrice, and HistoryEntry/shared_sheet_sessions are covered by the online and offline gates. ProductPrice uses targeted `price_ids`; History uses targeted `session_ids`; changed catalog events include targeted product/supplier/category IDs. `FULL_PULL_*` is not used in the normal mutation/reconnect path.

## Blocker
- `20260522T201046Z-live-reconcile-counts-task-TASK-114-prefix-TASK114_RECON_-p82875`: **BLOCKED_DEVICE_LOCKED**, Android physical target appears screen-off/asleep.
- Safe wake/dismiss attempted; device remains `mDreamingLockscreen=true`.
- `20260522T201119Z-android-auth-preflight-live-task-TASK-114-p83646`: emulator fallback **AUTH_BLOCKED** / signed out.

## Next commands
```bash
cd /Users/minxiang/Desktop/iOSMerchandiseControl
MC_ALLOW_LIVE=1 MC_ANDROID_DEVICE_SERIAL=8ac48ff0 ./tools/agent/mc-agent.sh android auth-preflight --live --task TASK-114
MC_ALLOW_LIVE=1 MC_IOS_SIMULATOR_ID=459C668B-7CE8-443B-BAB3-7D3D5FFC9143 MC_ANDROID_DEVICE_SERIAL=8ac48ff0 ./tools/agent/mc-agent.sh live reconcile-counts --task TASK-114 --prefix TASK114_RECON_
MC_ALLOW_LIVE=1 MC_IOS_SIMULATOR_ID=459C668B-7CE8-443B-BAB3-7D3D5FFC9143 MC_ANDROID_DEVICE_SERIAL=8ac48ff0 ./tools/agent/mc-agent.sh live runtime-parity --task TASK-114 --prefix TASK114_RUNTIME_
./tools/agent/mc-agent.sh scan sensitive --task TASK-114
./tools/agent/mc-agent.sh scan evidence --task TASK-114
./tools/agent/mc-agent.sh report --latest --task TASK-114
git diff --check
cd /Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView && git diff --check
```
