# TASK-108 Evidence 09 — Wave Gates

Status: ACTIVE / REVIEW-READY WITH LIVE BLOCKER. Do not declare final PASS or DONE until live app-auth E2E, History/session sync, and cross-platform read-back are actually verified.

| Wave | Implemented | Fixed during completion | Not implemented yet | Blocked | Evidence |
|------|-------------|-------------------------|---------------------|---------|----------|
| Wave 1 | Cloud overview reducer/presenter, Release CTA states, DEBUG diagnostics, localizations, unit tests, Options smoke | Removed forbidden baseline jargon and moved baseline writer behind dedicated committer boundary | Complete authenticated screenshot matrix | — | `00`, `01`, `02`, `14`, `15`, `16`, `06` |
| Wave 2 | Bootstrap/full pull preview/apply path, baseline commit after successful local apply, no silent wipe | Boundary refactor preserved TASK-071 source-scope checks | Live app-auth bootstrap full pull scoped | — | `03`, `11`, `06` |
| Wave 3 | Launch/foreground policy covered by lifecycle tests, safe auto apply gate, cooldown/dedupe tests, foreground smoke | Foreground relaunch smoke added | Live signed-in incremental pull scoped | — | `17`, `08`, `06` |
| Wave 4 | Database/catalog/ProductPrice pending and push architecture preserved; read-back/retry contracts covered by existing suite | History pending is not mixed into catalog planner; Options pending total includes it | Live app-auth Database push/read-back scoped | — | `04`, `18`, `06` |
| Wave 5 | Generated guided apply, local SwiftData apply, ProductPrice idempotence, stock/history status, catalog/price pending | Generated now records history/session pending when sheet payload changes | Live Generated push/read-back scoped | — | `05`, `19`, `06` |
| Wave 6 | Core History/session push/pull/reconcile via `shared_sheet_sessions`, remote identity bridge, payload fingerprint, pending/ack, owner safety | Implemented after schema audit showed direct table sync is enough for Android-style core parity | `sync_events` history/session event domain, remote export flag, remote tombstone semantics | — | `20`, `10`, `06`, `21` |
| Wave 7 | Full XCTest, Debug/Release build, simulator smoke, Dynamic Type basic, privacy scan, Android assemble/smoke | Evidence reconciled and task moved to REVIEW | Live Supabase app-auth E2E, iOS physical smoke, live large dataset matrix | — | `21`, `06`, `07`, `08` |

Verdict:
- No wave is left `BLOCKED_SCHEMA_OR_POLICY` for core TASK-108 functionality.
- Remaining gaps are evidence/environment notes or backend/policy follow-ups, not client-side blockers.

Targeted Options cleanup FIX update 2026-05-13 20:45 -0400:

| Wave | Implemented | Fixed during cleanup | Not implemented yet | Blocked | Evidence |
|------|-------------|----------------------|---------------------|---------|----------|
| Wave 1 | Existing reducer/presenter and Release state model remain implemented | Options public surface cleaned; Sign in restored as primary signed-out action; technical DEBUG/manual sections moved under one collapsed Developer diagnostics section; local DB state made public | Signed-in screenshot/sign-out matrix | Live app-auth sign-in completion requires credentials | `22`, `23`, `06` |
| Wave 2 | Bootstrap/full pull code remains implemented | Public local DB empty/baseline state now visible without debug panels | Live app-auth full pull/apply | BLOCKED_APP_AUTH in this pass | `24`, `03`, `06` |
| Wave 3 | Auto incremental pull code/tests remain implemented | Options cleanup does not add duplicate lifecycle triggers | Live signed-in incremental pull smoke | BLOCKED_APP_AUTH in this pass | `25`, `17`, `06` |
| Wave 4 | Database incremental push code/tests remain implemented | Options pending count remains public via Local database status | Live Database push/read-back | BLOCKED_APP_AUTH in this pass | `26`, `18`, `04`, `06` |
| Wave 5 | Generated sync code/tests remain implemented | Generated tab smoke remains stable after Options cleanup | Live Generated push/read-back | BLOCKED_APP_AUTH in this pass | `27`, `19`, `05`, `06` |
| Wave 6 | Core History/session sync code/tests remain implemented | History signed-out smoke remains stable after Options cleanup | Live History/session push/read-back | BLOCKED_APP_AUTH in this pass | `28`, `20`, `06` |
| Wave 7 | Debug/Release build, targeted tests, simulator UI smoke, Dynamic Type, Android assemble, privacy scan | Evidence updated to avoid claiming live PASS | Live app-auth E2E and iOS physical smoke | BLOCKED_APP_AUTH / NOT RUN | `21`, `22`-`29`, `06`, `07`, `08` |

Current targeted FIX verdict:
- Options cleanup: PASS.
- App-auth initiation: PASS_TO_GOOGLE_PROMPT.
- Live app-auth sync matrix: NOT RUN / BLOCKED_APP_AUTH.
- Recommended task state remains ACTIVE / FIX unless a human completes app-auth and reruns live sync, or the reviewer accepts this as an external test-account blocker.

Large ProductPrice bootstrap FIX update 2026-05-13 22:45 -0400:

| Wave | Implemented | Fixed during large-history pass | Not implemented yet | Blocked | Evidence |
|------|-------------|----------------------------------|---------------------|---------|----------|
| Wave 1 | Options public surface and Sign in/Sign out remain implemented | Baseline-absent review CTA now uses user-facing `Scarica database dal cloud` copy | Fresh signed-in screenshot after rebuild | App-auth needed again | `30`, `06` |
| Wave 2 | Bootstrap preview/apply path remains implemented | ProductPrice preview sample no longer hard-blocks large history; ProductPrice full apply is paged; baseline writer batches records | Fresh live rerun proving valid baseline after fixed writer | BLOCKED_APP_AUTH for rerun | `03`, `24`, `30`, `06` |
| Wave 3 | Incremental pull code/tests remain implemented | No change in this pass | Live signed-in incremental pull smoke | BLOCKED_APP_AUTH | `17`, `06` |
| Wave 4 | Database incremental push code/tests remain implemented | No change in this pass | Live Database push/read-back | BLOCKED_APP_AUTH | `18`, `06` |
| Wave 5 | Generated sync code/tests remain implemented | No change in this pass | Live Generated push/read-back | BLOCKED_APP_AUTH | `19`, `06` |
| Wave 6 | History/session sync code/tests remain implemented | No change in this pass | Live History/session push/read-back | BLOCKED_APP_AUTH | `20`, `06` |
| Wave 7 | Build/test/privacy checks remain passing | Large-history targeted tests and partial live apply evidence added | Fresh app-auth full E2E with valid baseline | BLOCKED_APP_AUTH | `21`, `30`, `06`, `07` |

Current large-history verdict:
- Fixed total ProductPrice caps: REMOVED from Release bootstrap decision path.
- Large ProductPrice apply: CODE PASS + UNIT PASS + PARTIAL LIVE (53,022 local rows).
- Full bootstrap PASS: NOT CLAIMED until a fresh app-auth run verifies valid baseline after the batched writer fix.

FIX/PARITY pass update 2026-05-13 23:45 -0400:

| Wave | Implemented | Fixed during parity pass | Not implemented yet | Blocked | Evidence |
|------|-------------|--------------------------|---------------------|---------|----------|
| Wave 1 | Options public surface, reducer/presenter, banner and review states | Public review/bootstrap CTA now shows `Sync now`; root banner shows active progress | Authenticated screenshot matrix | App-auth session needed | `31`, `33`, `06` |
| Wave 2 | Bootstrap/full pull code path remains implemented | ProductPrice progress/state integrated into structured progress | Fresh authenticated valid-baseline rerun | BLOCKED_APP_AUTH | `32`, `33`, `30`, `06` |
| Wave 3 | Auto foreground check code/tests remain implemented | Banner/Options now expose active checking/fetching progress and local work remains possible | Signed-in live incremental pull | BLOCKED_APP_AUTH | `32`, `33`, `17`, `06` |
| Wave 4 | Database/pending/outbox push architecture remains implemented | Progress model now includes sending local changes and draining sync events | Live Database push/read-back | BLOCKED_APP_AUTH | `31`, `33`, `35`, `18` |
| Wave 5 | Generated sync code/tests remain implemented | Unified progress model includes pending/history domains for the same public sync entry | Live Generated push/read-back | BLOCKED_APP_AUTH | `31`, `35`, `19` |
| Wave 6 | History/session core sync code/tests remain implemented | History/session progress integrated into iOS unified flow; Android audit confirms full refresh includes history | Live History/session push/read-back | BLOCKED_APP_AUTH | `31`, `32`, `33`, `35`, `20` |
| Wave 7 | iOS Debug/Release build, targeted tests, simulator smoke, Android build/test/device smoke | Android public Options now exposes only one cloud sync action | Cross-platform Supabase E2E | BLOCKED_APP_AUTH / NOT RUN | `31`-`35`, `06`, `07`, `21` |

Current parity verdict:
- Android comparison: DONE.
- iOS progress/non-blocking UX: CODE + SIM PASS, large live jank NOT RUN.
- Single public action: iOS SIM PASS and Android DEVICE PASS.
- Live cross-platform E2E: NOT RUN / BLOCKED_APP_AUTH.

Post-TASK-108 targeted FIX update 2026-05-14 00:38 -0400:

| Wave | Implemented | Fixed during targeted post-pass | Not implemented yet | Blocked | Evidence |
|------|-------------|----------------------------------|---------------------|---------|----------|
| Wave 1 | Options remains the single public sync surface | History cloud card no longer exposes public `Send` / `Download`; read-only History status points to Options `Sync now` | Full signed-in screenshot matrix | — | `36`, `33`, `06` |
| Wave 2 | Bootstrap/full pull code path remains implemented | Current live app-auth run populated local products/suppliers/categories/ProductPrice | Valid baseline commit remains unverified; local baseline records stayed `0` | BASELINE/LIVE PARTIAL | `33`, `21`, `37` |
| Wave 3 | Auto foreground/incremental pull code/tests remain implemented | No new duplicate trigger added | Real remote delta pull after baseline | NOT VERIFIED | `17`, `21` |
| Wave 4 | Pending/push architecture remains implemented | Dirty History entries now contribute to global pending count in Options | Real Database/ProductPrice push/read-back | NOT VERIFIED | `18`, `36` |
| Wave 5 | Generated code path remains implemented | No separate History CTA introduced from Generated/History | Live Generated push/read-back | NOT VERIFIED | `21`, `35` |
| Wave 6 | History/session core code remains wired into global sync | Public History-only Send/Download path removed; pending status is read-only | Live History push/pull/read-back clears dirty entries | LIKELY SHARED_SESSION_POLICY_OR_BASELINE BLOCKER; dirty entries remained dirty | `20`, `33`, `36` |
| Wave 7 | iOS build/test/smoke and Android build/test/device smoke executed | Android `Local database status` card added and device-smoked | Cross-platform signed-in E2E with `TASK108_SYNC_*` rows | NOT VERIFIED / ANDROID SIGNED OUT / iOS HISTORY BLOCKED | `21`, `34`, `35`, `37` |

Current targeted post-pass verdict:
- History UX cleanup: PASS.
- Global pending visibility for History: PASS.
- iOS live app-auth sync: PARTIAL; catalog/ProductPrice local data populated, but baseline stayed invalid and History/session dirty entries remained dirty.
- Android local database status parity: PASS by build/test/device smoke.
- Cross-platform E2E/performance: BLOCKED / NOT VERIFIED.

Final ProductPrice keyset FIX update 2026-05-14 12:34 -0400:

| Wave | Implemented | Fixed during keyset pass | Not implemented yet | Blocked | Evidence |
|------|-------------|--------------------------|---------------------|---------|----------|
| Wave 1 | Options public sync surface remains implemented | Baseline status refresh after manual apply; final card shows `Database locale aggiornato` | Full signed-in visual matrix | — | `51`, `40` |
| Wave 2 | Bootstrap/full pull code path implemented | ProductPrice keyset flow completes live, no silent idle; baseline writes after full apply | Physical iOS smoke | — | `30`, `40`, `48`, `51` |
| Wave 3 | Auto foreground/incremental pull code/tests remain implemented | Failure/cancel state no longer collapses to idle | Controlled remote delta incremental pull | NOT VERIFIED in this focused pass | `17`, `51` |
| Wave 4 | Pending/push architecture remains implemented | ProductPrice tombstoned remote rows skipped explicitly during pull | Controlled Database/ProductPrice push/read-back | NOT VERIFIED | `18`, `51` |
| Wave 5 | Generated code path remains implemented | No change in this focused pass | Live Generated push/read-back | NOT VERIFIED | `19` |
| Wave 6 | History/session core code remains wired into global sync | No change in this focused pass | Live History push/pull/read-back clears dirty entries | NOT VERIFIED | `20`, `21` |
| Wave 7 | Debug/Release build, targeted tests, iOS live ProductPrice performance evidence | Large ProductPrice live performance measured | Android signed-in performance rerun, cross-platform E2E | NOT VERIFIED | `47`, `48`, `51` |

Current keyset pass verdict:
- iOS ProductPrice full pull/apply/baseline: PASS live.
- Silent idle bug: FIXED.
- TASK-108 global cross-platform/live E2E: still not DONE / not PASS.
