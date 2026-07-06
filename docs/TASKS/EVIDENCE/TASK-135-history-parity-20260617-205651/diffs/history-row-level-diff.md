# TASK-135 History Row-Level Diff

Status: PARTIAL / STATIC ONLY

Live row-level snapshots were not collected because Android runtime and Supabase local/linked CLI access were unavailable in this workspace.

## Evidence

- iOS simulator booted: `raw/ios-simulator-booted.txt`
- Android ADB: `raw/android-adb-devices.txt` -> `zsh:1: command not found: adb`
- Supabase status: `raw/supabase-status-redacted.txt` -> missing local container

## Static Classification

| category | status | evidence |
|---|---|---|
| Same logical payload, different remote id | RISK FOUND / PATCHED iOS | iOS apply matched only `remoteID/uid`; fix adds logical fingerprint link |
| Duplicate same remote_id | NOT RUN live | Requires iOS/Android/Supabase snapshots |
| Duplicate same fingerprint | NOT RUN live | Requires row-level snapshots |
| TASK135 fixture rows in UI | MITIGATED iOS count | user-visible count excludes `TASK*`; History UI already filters |
| Same title/timestamp payload mismatch | NOT RUN live | Requires row-level snapshots |
| Tombstone parity | STATIC iOS support present | `remoteDeletedAt` / `deleted_at` apply and push supported |

