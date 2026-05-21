# TASK-112 — Test matrix 1…62 results

Timestamp: 2026-05-20 22:26 -0400

Legend: PASS, PASS_WITH_NOTES, FAIL, BLOCKED, NOT_RUN.

| Scenario | Result | Evidence / reason |
|---:|---:|---|
| 1 | BLOCKED | iOS clean install signed-in live bootstrap blocked by `sessionMissing`. |
| 2 | NOT_RUN | Android clean/local empty bootstrap from remote not executed; only app-auth live smoke ran. |
| 3 | BLOCKED | iOS live create/push to Android requires iOS app-auth session. |
| 4 | BLOCKED | Android live create/push to iOS requires iOS app-auth read/apply. |
| 5 | BLOCKED | iOS live History to Android requires iOS app-auth session. |
| 6 | BLOCKED | Android live History to iOS requires iOS app-auth read/apply. |
| 7 | BLOCKED | iOS live edit convergence requires both authenticated clients. |
| 8 | BLOCKED | Android live edit convergence requires both authenticated clients. |
| 9 | BLOCKED | iOS live delete/tombstone requires iOS app-auth session. |
| 10 | BLOCKED | Android live delete/tombstone requires iOS app-auth read/apply. |
| 11 | BLOCKED | Offline conflict live matrix depends on dual authenticated clients. |
| 12 | NOT_RUN | sync_events gap simulation not executed. |
| 13 | PASS_WITH_NOTES | iOS ProductPrice large/paging tests and Android targeted tests passed; live large ProductPrice not run. |
| 14 | PASS_WITH_NOTES | Options CTA source/static checks pass; iOS simulator Options and Android unlocked physical Options smoke recorded; no full visual walkthrough for every state. |
| 15 | PASS | iOS Release app and Android Release APK/source exact forbidden `Sync now` / localized sync-now scans all 0; broad iOS bundle strings for download/send are retained as localization/remediation/review copy, not a visible public sync-now CTA. |
| 16 | PASS_WITH_NOTES | iOS simulator launch/Options smoke and Android unlocked physical launch/Options smoke PASS; no jank instrumentation. |
| 17 | NOT_RUN | Logout during push not executed. |
| 18 | NOT_RUN | Account switch with pending not executed. |
| 19 | NOT_RUN | Kill/restart during ProductPrice apply not executed. |
| 20 | PASS_WITH_NOTES | iOS reconnect flapping tests and Android coordinator tests pass; realtime burst/live drain not executed. |
| 21 | PASS_WITH_NOTES | Options no longer wires public sync refresh; repeated-open instrumentation not executed. |
| 22 | NOT_RUN | Schema/version mismatch not simulated. |
| 23 | PASS_WITH_NOTES | Local Supabase idempotency and client unit tests cover parts; full batch replay live not executed. |
| 24 | PASS_WITH_NOTES | ProductPrice pull replay/dedupe tests and local DB dedupe pass; cross-platform live blocked. |
| 25 | NOT_RUN | Large import dirty-set not executed. |
| 26 | NOT_RUN | Large import unsafe dirty-set/fallback not executed. |
| 27 | NOT_RUN | Dynamic Type/VoiceOver not executed. |
| 28 | PASS | Forbidden public sync-now CTA Release scan pass in iOS bundle/source and Android APK/source; Android physical Options UI shows automatic sync card only. |
| 29 | NOT_RUN | Long background foreground delta not executed. |
| 30 | NOT_RUN | Product conflict live policy not executed. |
| 31 | NOT_RUN | Tombstone/update concurrent live not executed. |
| 32 | PASS_WITH_NOTES | History retry/no duplicate unit coverage exists; crash scenario not executed. |
| 33 | PASS | Cleanup policy followed; local TASK112 data rolled back and no live TASK112 rows created. |
| 34 | PASS_WITH_NOTES | Existing iOS/Android tests cover parts; cross-platform not complete. |
| 35 | NOT_RUN | Scroll preservation not executed. |
| 36 | PASS | Go/no-go current verdict: NO-GO/BLOCKED for REVIEW. |
| 37 | BLOCKED | iOS offline catalog push live not executed due missing iOS app-auth session. |
| 38 | BLOCKED | Android offline catalog push to iOS blocked by missing iOS app-auth read/apply. |
| 39 | BLOCKED | iOS offline ProductPrice live not executed. |
| 40 | BLOCKED | Android offline ProductPrice live cannot be read/applied by iOS. |
| 41 | BLOCKED | iOS offline History live not executed. |
| 42 | BLOCKED | Android offline History live cannot be read/applied by iOS. |
| 43 | NOT_RUN | Offline large import reconnect not executed. |
| 44 | BLOCKED | Offline pending kill/restart drain not verified end-to-end. |
| 45 | PASS_WITH_NOTES | Network reconnect debounce/coalescing tests pass, including iOS scheduler/observer paths; live outbox drain flapping not executed. |
| 46 | BLOCKED | Remote change while device offline reconnect pull requires live iOS↔Android matrix. |
| 47 | BLOCKED | Tombstone/update offline policy not live verified. |
| 48 | BLOCKED | Dual-offline product conflict not live verified. |
| 49 | NOT_RUN | Offline logout/account boundary not executed. |
| 50 | PASS_WITH_NOTES | Options public CTA absent, reconnect state path added, iOS/Android Options smoke observed; detailed offline UI state matrix not run. |
| 51 | BLOCKED | Local commit/outbox crash recovery not verified end-to-end. |
| 52 | BLOCKED | ProductPrice dependency wait/no orphan not verified end-to-end. |
| 53 | BLOCKED | History dependency wait not verified end-to-end. |
| 54 | BLOCKED | Partial ack/retry lanes not verified end-to-end. |
| 55 | NOT_RUN | Network path available/backend unreachable not simulated. |
| 56 | NOT_RUN | Auth expired during reconnect drain not simulated. |
| 57 | BLOCKED | Long-offline retention live requires authenticated cross-platform environment. |
| 58 | NOT_RUN | Storage/outbox write failure not simulated. |
| 59 | BLOCKED | Queue fairness/priority lanes not verified end-to-end. |
| 60 | PASS_WITH_NOTES | Basic pending/status UX exists; detailed offline UX smoke not executed. |
| 61 | BLOCKED | Outbox pruning/audit not verified end-to-end. |
| 62 | PASS_WITH_NOTES | iOS reconnect fake scheduler tests added and Android coordinator tests passed; not a complete two-platform fake-clock suite. |

## Matrix verdict

The matrix is **not passable** in this execution. There are no newly observed blocking FAIL rows, but the required live/offline rows remain **BLOCKED/NOT_RUN**, especially CA-20 and the critical offline-first scenarios.

## CA-20 app-auth rerun update — 2026-05-20 23:15 -0400

| Test row | Updated result | Evidence |
|---:|---:|---|
| 1 | PASS | iOS app-auth restore/preflight PASS after cold launch; Android auth preflight PASS via persistent `am instrument`. |
| 2 | PASS | iOS -> Supabase -> Android catalog/ProductPrice canary PASS. |
| 3 | PASS | Android -> Supabase -> iOS catalog/ProductPrice canary PASS. |
| 5 | PASS | Medium ProductPrice import/export/read-back PASS: 50 products, 102 prices, Android medium pull PASS. |
| 10 | PASS_WITH_NOTES | iOS offline retry/drain PASS; Android offline live write harness not present. |
| 20 | BLOCKED | Cleanup scoped attempted and failed with RLS `42501` on `inventory_product_prices`. |
| 36 | PASS | Go/no-go enforced: task remains BLOCKED, not DONE. |

Updated matrix verdict: **BLOCKED_BY_RLS_CLEANUP**. The live CA-20 test rows passed, but cleanup and full offline parity are not complete.

## Final closure update — 2026-05-21 00:01 -0400

Supersedes the cleanup blocker.

| Test row | Final result | Evidence |
|---:|---:|---|
| 1 | PASS | iOS and Android app-auth preflights PASS. |
| 2 | PASS | iOS -> Supabase -> Android final canary PASS. |
| 3 | PASS | Android -> Supabase -> iOS final canary PASS. |
| 5 | PASS | Medium ProductPrice final rerun PASS: 50 products, 102 ProductPrice, Android medium pull PASS. |
| 10 | PASS_WITH_NOTES | iOS offline retry/drain PASS; no Android equivalent live offline harness exists. |
| 14 | PASS | iOS Options smoke via XcodeBuildMCP hierarchy/screenshot PASS; Android Options smoke via adb UI dump/screenshot PASS. |
| 15 | PASS | Exact forbidden manual sync CTA source scans PASS on iOS and Android. |
| 20 | PASS | Scoped cleanup completed via admin/postgres backend CLI; final SQL read-back zero for all TASK112 prefixes. |
| 36 | PASS | Go/no-go final verdict updated to DONE only after final cleanup/build/test gates passed. |
| 45 | PASS_WITH_NOTES | iOS reconnect scheduler/lifecycle and Android coordinator/single-flight paths verified by targeted tests/static review. |
| 50 | PASS | Public Options sync-now CTA absent; automatic status/remediation UI remains. |
| 62 | PASS_WITH_NOTES | iOS fake scheduler/lifecycle tests and Android coordinator tests pass; not a full two-platform fake-clock suite. |

Final matrix verdict: **DONE**.
