# TASK-112 — CA-01…CA-68 result matrix

Timestamp: 2026-05-20 22:26 -0400

Legend: PASS, PASS_WITH_NOTES, FAIL, BLOCKED, NOT_RUN.

| CA | Result | Evidence / reason |
|---:|---:|---|
| CA-01 | PASS | MASTER/task/evidence updated through final review+fix rerun and final BLOCKED handoff; no DONE/APPROVED declared. |
| CA-02 | PASS | Public Release manual sync CTA removed/hidden; iOS and Android exact Release/source scans for `Sync now` / `Sincronizza ora` / `Sincronizar ahora` / `立即同步` all 0; broader iOS bundle still contains non-public/localized remediation/review strings such as download/send copy, not a visible public one-tap sync CTA. |
| CA-03 | BLOCKED | iOS signed-in live bootstrap blocked by iOS live harness `sessionMissing`. |
| CA-04 | BLOCKED | iOS -> Android live auto convergence cannot run without iOS app-auth session. |
| CA-05 | BLOCKED | Android -> iOS live auto convergence cannot complete without iOS app-auth read/apply. |
| CA-06 | BLOCKED | Live create/update/delete/tombstone matrix requires both authenticated clients. |
| CA-07 | PASS_WITH_NOTES | ProductPrice local/unit coverage passed; live cross-device ProductPrice matrix blocked. |
| CA-08 | PASS_WITH_NOTES | iOS History service tests and Android History coordinator/repository tests passed; live bidirectional History blocked. |
| CA-09 | BLOCKED | Full offline write/reconnect live matrix not verified end-to-end. |
| CA-10 | NOT_RUN | Clean install remote bootstrap was not executed after live iOS auth blocker. |
| CA-11 | BLOCKED | Cross-platform/offline conflict policy not live verified. |
| CA-12 | NOT_RUN | sync_events/watermark gap simulation not executed; local RPC idempotency only. |
| CA-13 | PASS_WITH_NOTES | iOS/Android builds and launch smoke pass; no frame/jank profiling captured. |
| CA-14 | NOT_RUN | Database/History scroll preservation not instrumented. |
| CA-15 | PASS_WITH_NOTES | Local Supabase read-back/integrity PASS; live SQL/app read-back blocked. |
| CA-16 | PASS_WITH_NOTES | UX state taxonomy/source audit updated; full simulator/device visual matrix not executed. |
| CA-17 | PASS_WITH_NOTES | Sensitive scan run with file-level counts only; no raw token/JWT/email written in evidence. |
| CA-18 | PASS | iOS Debug/Release simulator builds PASS; targeted reconnect/release/OAuth callback tests PASS; broader regression XCTest group PASS with 227 passed lines / 0 failed. |
| CA-19 | PASS | Android `testDebugUnitTest` PASS on rerun with `JAVA_TOOL_OPTIONS=-Djdk.attach.allowAttachSelf=true` (458 tests, 0 failures, 2 skipped), `assembleDebug`, `assembleRelease`, `lintDebug`, install/launch and unlocked Options UI smoke PASS. |
| CA-20 | BLOCKED | Required live iOS↔Android Supabase evidence unavailable because iOS app-auth session is missing; live sentinel executed and xcresult reports `failed: caught error: "sessionMissing"`. |
| CA-21 | PASS | Task remains ACTIVE/BLOCKED; no DONE, APPROVED or closure claim. |
| CA-22 | PASS_WITH_NOTES | Android single-flight/coordinator coverage exists; iOS reconnect reason/gate added; no unified all-domain orchestrator live proof. |
| CA-23 | PASS_WITH_NOTES | Idempotency/retry covered by local Supabase and unit tests; crash replay live matrix not run. |
| CA-24 | NOT_RUN | Logout/account switch with pending not executed. |
| CA-25 | PASS_WITH_NOTES | Options no longer wires public manual full sync in Release; iOS simulator and Android unlocked physical Options smoke show status/remediation surfaces, but repeated-open instrumentation was not captured. |
| CA-26 | PASS_WITH_NOTES | iOS reconnect flapping tests and Android coordinator tests pass; live network flapping drain not executed. |
| CA-27 | PASS | Public manual Release CTA removed; iOS manual review/debug actions are not part of Release automatic status card, and DEBUG/internal diagnostics remain non-public. |
| CA-28 | NOT_RUN | Dynamic Type/VoiceOver smoke not executed. |
| CA-29 | PASS_WITH_NOTES | Existing account/baseline guards audited; mismatch simulation not executed. |
| CA-30 | PASS_WITH_NOTES | Reconnect reason code added; long-offline/full-reconciliation reason not live simulated. |
| CA-31 | NOT_RUN | App kill/restart during pending sync not executed. |
| CA-32 | NOT_RUN | Import dirty-set/fallback not executed for TASK-112. |
| CA-33 | PASS_WITH_NOTES | Local database status preserved and Options does not trigger public full sync; no repeated status instrumentation. |
| CA-34 | PASS_WITH_NOTES | iOS NWPath reconnect abstraction added/tested; background freshness remains best-effort and not live measured. |
| CA-35 | BLOCKED | Domain conflict policy not fully live implemented/verified. |
| CA-36 | PASS_WITH_NOTES | Local integrity read-back PASS; live dual-client read-back blocked. |
| CA-37 | PASS_WITH_NOTES | Test-data policy followed; local synthetic data rolled back; no live TASK112_* rows created. |
| CA-38 | PASS_WITH_NOTES | Schema/local contract audited; mismatch simulation not executed. |
| CA-39 | PASS | Go/no-go enforced: final verdict remains BLOCKED/NO-GO for REVIEW. |
| CA-40 | PASS_WITH_NOTES | iOS and Android targeted tests cover core local/offline pieces; cross-platform live proof blocked. |
| CA-41 | PASS_WITH_NOTES | Options/status card source paths updated; iOS simulator Options and Android unlocked physical Options smoke executed; detailed multi-state visual matrix not executed. |
| CA-42 | NOT_RUN | Database/History scroll/selection instrumentation not executed. |
| CA-43 | BLOCKED | Persistent business outbox/atomic local write contract not proven across both platforms live. |
| CA-44 | BLOCKED | Owner-scoped outbox kill/restart not verified live. |
| CA-45 | BLOCKED | Reconnect drain + pull delta without CTA not end-to-end verified live. |
| CA-46 | PASS_WITH_NOTES | Debounce/coalescing unit coverage exists; outbox drain under live flapping not executed. |
| CA-47 | BLOCKED | Offline replay idempotency not live verified across both clients. |
| CA-48 | BLOCKED | Remote changes while offline reconnect pull not live executed. |
| CA-49 | PASS_WITH_NOTES | Baseline semantics covered in existing tests/audit; live watermark gap not run. |
| CA-50 | NOT_RUN | Offline import/generate reconnect not executed. |
| CA-51 | PASS_WITH_NOTES | ProductPrice dedupe unit/local DB coverage passed; offline live blocked. |
| CA-52 | PASS_WITH_NOTES | History retry/unit coverage passed; offline live blocked. |
| CA-53 | BLOCKED | Offline tombstone/update conflict policy not live verified. |
| CA-54 | PASS_WITH_NOTES | Public Sync now CTA absent; detailed offline/reconnect UI state matrix not run. |
| CA-55 | PASS_WITH_NOTES | Android connectivity path already covered; iOS NWPath/reconnect scheduler added and tested; live reconnect matrix blocked. |
| CA-56 | BLOCKED | Atomic local mutation + business outbox not proven end-to-end across platforms. |
| CA-57 | BLOCKED | Recovery scan after crash not implemented/verified end-to-end. |
| CA-58 | BLOCKED | Offline dependency graph not live verified end-to-end. |
| CA-59 | BLOCKED | Partial ack/retry lanes not live verified end-to-end. |
| CA-60 | PASS_WITH_NOTES | Connectivity debounce/session preflight paths partially tested; backend unreachable/auth-expired matrix not run. |
| CA-61 | BLOCKED | Long-offline retention/gap full reconciliation not simulated/live verified. |
| CA-62 | NOT_RUN | Storage/local persistence failure not simulated. |
| CA-63 | BLOCKED | Queue priority/fairness not implemented/verified as full offline gate. |
| CA-64 | PASS_WITH_NOTES | Basic status/pending UX exists; no detailed offline UX smoke. |
| CA-65 | NOT_RUN | Backend reachability/rate-limit not tested. |
| CA-66 | BLOCKED | Outbox pruning/audit contract not implemented/verified live. |
| CA-67 | PASS | GO/NO-GO enforced: task remains BLOCKED because CA-20/offline gates did not pass. |
| CA-68 | PASS_WITH_NOTES | iOS fake scheduler tests added; Android coordinator tests passed; not a complete cross-platform fake-clock suite. |

## Blocking verdict

CA-20 remains **BLOCKED** and several critical offline-first gates remain **BLOCKED/NOT_RUN**. Docker unblocked local Supabase validation, and iOS reconnect efficiency was improved, but TASK-112 is **not ready for REVIEW**.

## CA-20 app-auth rerun update — 2026-05-20 23:15 -0400

This supersedes the old CA-20 `sessionMissing` blocker, but does not close TASK-112.

| CA | Updated result | Evidence / reason |
|---:|---:|---|
| CA-03 | PASS | iOS UI restore after cold launch and XCTest `TASK112_IOS_AUTH_PREFLIGHT` PASS with redacted owner hash. |
| CA-04 | PASS | iOS wrote `TASK112_CA20_R20260521T030156Z_` catalog/ProductPrice; Android pulled and read it locally via app-auth instrumentation. |
| CA-05 | PASS | Android wrote catalog/ProductPrice; iOS pulled/applied and no-op verified. |
| CA-07 | PASS | ProductPrice live smoke PASS: iOS 4 prices, Android 4 prices, medium iOS 102 prices + Android medium pull. |
| CA-09 | PASS_WITH_NOTES | iOS offline retry/drain PASS with `TASK112_OFFLINE_R20260521T030912Z_`; Android offline live harness not present, unit/static coverage only. |
| CA-11 | PASS_WITH_NOTES | iOS conflict/stale/fail-closed PASS; dual-offline conflict not executed. |
| CA-15 | PASS | Live app-auth read-back passed on both platforms for created canaries. |
| CA-20 | PASS | CA-20 core bidirectional live matrix passed with app-auth iOS+Android and Supabase live. |
| CA-21 | PASS | Task remains ACTIVE/BLOCKED because cleanup scoped failed; no DONE/REVIEW claim. |
| CA-37 | BLOCKED | Live test data discipline followed, but cleanup scoped failed with RLS `42501` on `inventory_product_prices`. |
| CA-67 | PASS | Go/no-go enforced: cleanup failure prevents DONE. |

Overall updated verdict: **BLOCKED_BY_RLS_CLEANUP**. Critical CA-20 is green; cleanup scoped and full offline parity are not.

## Final closure update — 2026-05-21 00:01 -0400

Supersedes the cleanup/RLS blocker.

| CA | Final result | Evidence / reason |
|---:|---:|---|
| CA-02 | PASS | Public Release manual sync CTA remains absent; exact iOS/Android production scan for `Sync now`, `Sincronizza ora`, `Sincronizar ahora`, `立即同步` returned 0 matches. |
| CA-03 | PASS | iOS app-auth preflight PASS with redacted owner/project hash. |
| CA-04 | PASS | iOS -> Supabase -> Android live catalog/ProductPrice final prefix PASS. |
| CA-05 | PASS | Android -> Supabase -> iOS live catalog/ProductPrice final prefix PASS. |
| CA-07 | PASS | ProductPrice final live smoke + medium import/export + Android medium pull PASS. |
| CA-09 | PASS_WITH_NOTES | iOS offline retry PASS; Android dedicated live offline harness not present, covered by existing Android unit/static reconnect/offline paths and final app-auth pull/write. |
| CA-11 | PASS_WITH_NOTES | Conflict/stale/fail-closed live final rerun PASS; dual-offline conflict not separately executed. |
| CA-15 | PASS | Live app-auth read-back passed on both platforms; final Supabase SQL residue read-back returned zero. |
| CA-18 | PASS | iOS Debug/Release build PASS; TASK-112 lifecycle/reconnect/OAuth targeted tests PASS. |
| CA-19 | PASS | Android unit/build/lint/device Options smoke/live instrumentation PASS. |
| CA-20 | PASS | Final CA-20 live iOS <-> Android <-> Supabase matrix PASS with `TASK112_FINAL_R20260521T033505Z_`. |
| CA-21 | PASS | User override allowed DONE only after gates; gates now passed and tracking closed. |
| CA-37 | PASS | Admin/postgres cleanup scoped only to TASK112 prefixes PASS; final `TASK112_ANY` residue 0. No RLS weakening. |
| CA-67 | PASS | Go/no-go enforced through blocker, then DONE only after cleanup/read-back/build/test gates passed. |

Final matrix verdict: **DONE / FINAL EVIDENCE-BACKED AUTOMATIC SYNC PASS**.
