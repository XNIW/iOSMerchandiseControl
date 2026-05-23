# TASK-117 - Live Device Supabase Results

Date: 2026-05-23 17:48:36 -0400

## Supabase
| Gate | Result | Evidence |
|---|---:|---|
| status redacted | PASS | `20260523T213025Z-supabase-status-redacted-task-TASK-117-p67591` |
| verify RLS linked | PASS | `20260523T213025Z-supabase-verify-rls-profile-linked-task-TASK-117-p67615` |
| verify grants linked | BLOCKED | `20260523T213025Z-supabase-verify-grants-profile-linked-task-TASK-117-p67617` |

## Live/device
| Gate | Result | Evidence |
|---|---:|---|
| iOS auth preflight live | BLOCKED | `20260523T213348Z-ios-auth-preflight-live-task-TASK-117-p70112` |
| iOS physical auth/store diagnostics | BLOCKED | `20260523T213446Z-ios-physical-auth-store-diagnostics-live-task-TASK-117-p72803` |
| iOS physical sync acceptance | BLOCKED | `20260523T213555Z-ios-physical-sync-acceptance-live-task-TASK-117-p73555` |
| Android auth preflight live | BLOCKED | `20260523T213737Z-android-auth-preflight-live-task-TASK-117-p74493` |
| runtime parity | BLOCKED | `20260523T213747Z-live-runtime-parity-task-TASK-117-prefix-TASK117_RUNTIME_-p74941` |
| near-realtime | BLOCKED | `20260523T213853Z-live-mutation-near-realtime-task-TASK-117-prefix-TASK117_REALTIME_-p78371` |
| offline reconnect | BLOCKED | `20260523T213858Z-live-offline-reconnect-sync-task-TASK-117-prefix-TASK117_OFFLINE_-p78829` |
| account matrix | BLOCKED | `20260523T213902Z-live-account-merge-policy-matrix-task-TASK-117-prefix-TASK117_ACCOUNT_-p79285` |
| sync performance budget | PASS | `20260523T214233Z-live-sync-performance-budget-task-TASK-117-prefix-TASK117_PERF_-p81379` |

## External next actions
- Open/login iOS physical app and verify session restore.
- Set `MC_ANDROID_DEVICE_SERIAL` to physical/emulator Android target.
- Link/start Supabase DB where required for linked grants/residue checks.

