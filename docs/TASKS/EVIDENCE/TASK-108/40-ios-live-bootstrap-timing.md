# TASK-108 Evidence 40 — iOS Live Bootstrap Timing

Timestamp: 2026-05-14 12:34 -0400.

Status: **PASS for iOS ProductPrice full bootstrap/apply and baseline commit**. Not a global cross-platform TASK-108 PASS.

## Environment

- iOS simulator: iPhone 15 Pro Max.
- App-auth: signed in, account displayed masked in Options.
- Supabase project: development project already linked in app config.
- Client auth: app-auth only; no `service_role`, token injection or RLS bypass.

## Flow

1. Opened Options.
2. Started `Sincronizza ora`.
3. Review sheet showed safe update path.
4. Confirmed `Aggiorna questo dispositivo`.
5. Observed ProductPrice progress and local SQLite counts until completion.

## Phase Results

| Phase | Result |
| --- | --- |
| Auth/access check | PASS, app-auth session available |
| Remote ProductPrice count | `290,955` |
| Page size | `900` |
| ProductPrice pages | keyset stream completed |
| Tombstoned products | 2 ProductPrice rows skipped explicitly |
| ProductPrice apply | PASS |
| Baseline commit | PASS |
| UI progress | PASS, visible and advancing |
| UI responsiveness | PASS, Options scroll worked during apply |
| Crash/freeze | None observed |

## Timing Samples

| Time | Visible / measured state |
| --- | --- |
| 12:10 | apply confirmed from review |
| 12:12 | progress visible, `135,900 / 290,955` |
| 12:17 | progress visible, local ProductPrice `225,178` |
| 12:28 | progress visible, `262,800 / 290,955` |
| 12:30 | progress visible, `274,500 / 290,955` |
| 12:33 | local remote-linked ProductPrice `290,953` |
| 12:33 | baseline committed |
| 12:34 | app idle after completion |

Approximate duration from confirmation to idle completion: `~25m 50s`.

## Final Local State

- Products: `19,886`.
- Suppliers: `79`.
- Categories: `47`.
- ProductPrice total rows: `328,589`.
- ProductPrice remote-linked rows: `290,953`.
- Baseline runs: `1`.
- Baseline records: `20,012`.

## Verdict

iOS live bootstrap/full ProductPrice pull no longer exits silently and no longer leaves baseline at `0`.

Remaining TASK-108 global gaps:
- Android signed-in rerun not repeated in this focused pass.
- Cross-platform E2E not completed in this focused pass.
- Controlled incremental pull/push, Generated live and History/session live still need final acceptance evidence.
