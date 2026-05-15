# TASK-110 Fix Completion — Migration Ledger Before/After

Timestamp: 2026-05-15 13:02 -0400.

## Before repair

`supabase migration list --linked` showed:

| Local | Remote | Classification |
|---|---|---|
| `20260416` | `20260416` | aligned |
| `20260417120000` | `20260417120000` | aligned |
| `20260417200000` | `20260417200000` | aligned |
| `20260417` | blank | local malformed 8-digit timestamp; live effects present |
| `20260418200000` | `20260418200000` | aligned |
| `20260421120000` | `20260421120000` | aligned |
| `20260422120000` | `20260422120000` | aligned |
| `20260424021936` | blank | local duplicate/equivalent of remote `task045_sync_events` |
| blank | `20260424145010` | remote `task045_sync_events`; local file missing before fetch |
| `20260509120000` | blank | live effects present from TASK-086 manual apply |
| `20260511030000` | blank | live effects present from TASK-101 hardening |
| blank | `20260514213110` | remote TASK-108 backup migration; local file missing before fetch |
| `20260515161500` | blank | new TASK-110 migration pending |

## Actions taken

- Ran `supabase migration fetch --linked`; reconstructed missing remote files:
  - `20260424145010_task045_sync_events.sql`
  - `20260514213110_task108_backup_20260514173049.sql`
- Renamed malformed local file:
  - from `20260417_task012_ownership_rls.sql`
  - to `20260417000000_task012_ownership_rls.sql`
- Repaired migration ledger after evidence that live effects already existed:
  - `supabase migration repair --linked --status applied 20260417 20260424021936 20260509120000 20260511030000`
  - `supabase migration repair --linked --status reverted 20260417`
  - `supabase migration repair --linked --status applied 20260417000000`

## After repair, before apply

`supabase migration list --linked` now shows all historical migrations aligned and only TASK-110 pending:

| Local | Remote |
|---|---|
| `20260416` | `20260416` |
| `20260417000000` | `20260417000000` |
| `20260417120000` | `20260417120000` |
| `20260417200000` | `20260417200000` |
| `20260418200000` | `20260418200000` |
| `20260421120000` | `20260421120000` |
| `20260422120000` | `20260422120000` |
| `20260424021936` | `20260424021936` |
| `20260424145010` | `20260424145010` |
| `20260509120000` | `20260509120000` |
| `20260511030000` | `20260511030000` |
| `20260514213110` | `20260514213110` |
| `20260515161500` | blank pending TASK-110 |

## After TASK-110 apply

`supabase db push --linked --yes` applied `20260515161500_task110_history_tombstone_grants.sql`.

Latest `supabase migration list --linked` shows the ledger aligned locally/remotely:

| Local | Remote |
|---|---|
| `20260416` | `20260416` |
| `20260417000000` | `20260417000000` |
| `20260417120000` | `20260417120000` |
| `20260417200000` | `20260417200000` |
| `20260418200000` | `20260418200000` |
| `20260421120000` | `20260421120000` |
| `20260422120000` | `20260422120000` |
| `20260424021936` | `20260424021936` |
| `20260424145010` | `20260424145010` |
| `20260509120000` | `20260509120000` |
| `20260511030000` | `20260511030000` |
| `20260514213110` | `20260514213110` |
| `20260515161500` | `20260515161500` |

## Notes

- The fetched TASK-108 backup migration contains owner-scoped backup DDL. Owner UUID is redacted from reporting and must not be copied to final output.
- `20260424021936_task045_sync_events.sql` and `20260424145010_task045_sync_events.sql` differ only by wrapper punctuation/transaction formatting; both are now represented in the ledger to avoid a pending duplicate apply.
