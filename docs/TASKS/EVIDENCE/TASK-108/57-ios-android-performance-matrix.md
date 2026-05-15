# TASK-108 Evidence 57 - iOS / Android performance matrix

Timestamp: 2026-05-14 13:23 -0400

Important: this matrix separates measured values from missing live values. No "faster" verdict is claimed without a comparable live rerun.

| Phase | iOS duration | iOS rows/sec | iOS peak memory | Android duration | Android rows/sec | Android memory | Better | Notes |
|---|---:|---:|---:|---:|---:|---:|---|---|
| auth/access check | N/D post-patch | N/D | N/D | N/D | N/D | N/D | N/D | Fresh app-auth rerun not completed. |
| remote count | Previous live included ProductPrice count `290,955`; time not isolated | N/D | N/D | N/D | N/D | N/D | N/D | Android live count not rerun. |
| suppliers/categories | N/D post-patch | N/D | N/D | N/D | N/D | N/D | N/D | No fresh live matrix. |
| products | N/D post-patch | N/D | N/D | N/D | N/D | N/D | N/D | Prior baseline records `20,012`; no fresh post-patch phase timing. |
| ProductPrice | Previous live `25m50s` for `290,953` applied/linked | `~187.7` previous live | Previous live peak roughly `~3.5GB`; post-patch peak not measured | NOT EXECUTED live | N/D | Idle launch RSS `233,876 KB`; sync peak not measured | N/D | iOS code now page-scoped; Android code now keyset/page-streamed. Comparable live rerun still required. |
| History/session | NOT EXECUTED | N/D | N/D | NOT EXECUTED | N/D | N/D | N/D | No fresh cross-platform run. |
| pending push | NOT EXECUTED | N/D | N/D | NOT EXECUTED | N/D | N/D | N/D | No scoped pending data created. |
| outbox/sync_events | NOT EXECUTED | N/D | N/D | NOT EXECUTED | N/D | N/D | N/D | Static audit only. |
| total sync | NOT EXECUTED | N/D | N/D | NOT EXECUTED | N/D | N/D | N/D | Missing live app-auth/cross-platform matrix. |
| UI responsiveness | Previous iOS full pull scrollable/no crash/freeze | N/D | N/D | Android launch successful | N/D | Android idle PSS `151,044 KB` | N/D | No live sync UI responsiveness observed post-patch. |

## Static alignment result

- iOS ProductPrice apply no longer retains global full ProductPrice/current-price lookup objects across pages.
- Android ProductPrice pull no longer materializes the whole remote price table before apply.
- Both platforms now use bounded ProductPrice remote pages with page size `900`.

## Missing for final PASS

- Fresh iOS full live ProductPrice profile after patch.
- Fresh Android signed-in ProductPrice live profile.
- Cross-platform E2E live matrix.
- Incremental pull/push, Generated, and History/session live profiles.

