# TASK-108 Evidence 60 - Final performance test run

Timestamp: 2026-05-14 13:23 -0400

## iOS checks

| Check | Status | Evidence |
|---|---|---|
| `git diff --check` | PASS | No output. |
| Debug build | PASS | `xcodebuild build -configuration Debug -destination id=240F400E-5EFA-486A-9137-FFBBE70F604D` succeeded after rerun sequentially. First parallel attempt failed only with build DB lock. |
| Release build | PASS | `xcodebuild build -configuration Release -destination id=240F400E-5EFA-486A-9137-FFBBE70F604D` succeeded. |
| Targeted ProductPrice/keyset/baseline tests | PASS | 3 ProductPrice apply/keyset tests, 0 failures, `133.470s` after the final lookup-context patch. |
| Full XCTest | NOT EXECUTED | Not run in this pass. |
| Simulator smoke Options/Database/Generated/History | PARTIAL | App installed/launched on simulator; no full screen-by-screen smoke. Idle RSS sampled. |
| iOS physical smoke | NON ESEGUIBILE | Physical iPhone listed offline. |
| Dynamic Type XXL | NOT EXECUTED | No UI layout changes in this pass. |
| Privacy scan | PASS | Diff grep for `service_role`, token/JWT/email patterns returned no hits in changed iOS file. |
| `plutil` localizations | PASS | `zh-Hans`, `en`, `es`, `it` `Localizable.strings` OK. |

## Android checks

| Check | Status | Evidence |
|---|---|---|
| `git diff --check` | PASS | No output. |
| `assembleDebug` | PASS | BUILD SUCCESSFUL in `15s`. |
| Targeted ProductPrice paging test | PASS | New test `product price full pull streams remote prices by page` passed; BUILD SUCCESSFUL in `36s`. |
| `DefaultInventoryRepositoryTest` class | PASS | BUILD SUCCESSFUL in `17s`. |
| `CatalogSyncViewModelTest` class | BLOCKED_ENV | 25 failures caused by `ExceptionInInitializerError -> AttachNotSupportedException` during MockK attach at mock creation; not a ProductPrice paging assertion. |
| Install/launch physical device | PASS | APK installed and launched on OnePlus IN2013. |
| Android memory sample | PASS | After launch: TOTAL PSS `151,044 KB`, TOTAL RSS `233,876 KB`, swap PSS `248 KB`. |
| Logcat sensitive-token scan | PASS | Last 500 logcat lines produced 0 matches for token/JWT/email keywords. |

## Supabase checks

| Check | Status | Evidence |
|---|---|---|
| Read-back scoped | NOT EXECUTED | No scoped live mutations created. |
| Cleanup scoped | NOT NEEDED | No `TASK108_PERF_*` data created/modified/deleted. |
| No service_role client / no RLS bypass | PASS | Code changes use existing client data sources only; no service_role or policy bypass introduced. |

## Final TASK-108 status recommendation

Return to `ACTIVE / REVIEW`, not DONE. Verdict candidate: `REVIEW_READY_WITH_PERFORMANCE_FIXES_AND_LIVE_GAPS`.

Open live gaps:

- Android signed-in app-auth rerun.
- Cross-platform E2E.
- Incremental pull/push live.
- Generated live matrix.
- History/session live matrix.
- Fresh iOS/Android full ProductPrice live performance comparison after the memory fixes.
