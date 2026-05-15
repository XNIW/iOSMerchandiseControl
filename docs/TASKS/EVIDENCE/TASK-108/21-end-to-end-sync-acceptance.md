# TASK-108 Evidence 21 — End-to-End Sync Acceptance

Status: REVIEW-READY WITH BLOCKER / PARTIAL-LIVE. Do not declare final PASS or DONE until live app-auth E2E and History/session read-back are executed successfully or explicitly accepted as blocked.

Required coverage:
- Options signed-out/signed-in/baseline/pending/review/error.
- Bootstrap full pull.
- Auto incremental pull.
- Database edit to push.
- Generated apply to DB/prices/history/pending/push.
- History/session sync.
- Offline/local-first/account switch/retry/tombstone/performance/accessibility.

Executed:
- ✅ Full iOS XCTest suite PASS: 659 passed / 0 failed / 21 skipped.
- ✅ Debug simulator build PASS, warning 0.
- ✅ Release simulator build PASS.
- ✅ Options signed-out simulator smoke PASS.
- ✅ History cloud signed-out simulator smoke PASS.
- ✅ Dynamic Type XXXL Options smoke PASS.
- ✅ Foreground relaunch smoke PASS.
- ✅ Reducer/presenter, lifecycle, bootstrap/apply, pending, ProductPrice, Generated, History/session fake/local tests PASS.
- ✅ Android `assembleDebug` PASS.
- ✅ Android launch smoke PASS on connected device.
- ✅ Supabase schema/RLS read-only audit PASS for `shared_sheet_sessions`; no migration required for core direct session sync.
- ✅ Privacy/secret scan PASS; no raw token/API key/email evidence added.

Not run:
- ❌ Live Supabase app-auth bootstrap full pull/apply: no authenticated app session available.
- ❌ Live Supabase app-auth incremental push/read-back: same reason.
- ❌ Live Supabase app-auth Generated push/read-back: same reason.
- ❌ Live Supabase app-auth History/session read-back: same reason.
- ❌ Physical iOS install/smoke: device detected but not used for signing/install in this pass.
- ❌ Large live dataset/performance matrix: live gated; medium synthetic tests in suite passed, large gated tests skipped.

Blocked:
- No client-side wave is blocked for core functionality.
- Supabase local Docker stack was unavailable; live app-auth E2E requires either a signed-in test account in the app or a running local/dev environment.

Final acceptance note:
- TASK-108 should move to REVIEW, not DONE.
- Recommended technical verdict is PARTIAL / BLOCKED_LIVE until live app-auth E2E, History/session read-back and cross-platform sync are completed or accepted as blockers.

Targeted Options cleanup FIX update 2026-05-13 20:45 -0400:
- Options cleanup is verified with before/after screenshots: `22-options-cleanup-audit.md`.
- App-auth initiation is verified through ASWebAuthenticationSession and Google OAuth prompt: `23-app-auth-login-options-smoke.md`.
- Live bootstrap/full pull, incremental pull, Database push, Generated sync, and History/session sync are still NOT RUN because no authenticated app session was obtained.
- Current E2E acceptance status for this targeted FIX: OPTIONS_CLEANUP_PASS, APP_AUTH_TO_GOOGLE_PROMPT_PASS, LIVE_SYNC_MATRIX_BLOCKED_APP_AUTH.

Large ProductPrice bootstrap FIX update 2026-05-13 22:45 -0400:
- Authenticated remote preview was observed after the user completed OAuth manually: 19,888 products / 101 suppliers / 64 categories / ProductPrice sample 1,000, no source errors.
- Large ProductPrice apply no longer stops at a fixed row cap; local SwiftData reached 53,022 ProductPrice rows and 0 duplicate logical ProductPrice groups.
- Baseline was not valid after that first live run; the baseline writer was then fixed to batch baseline records and verified by unit test.
- Fresh live app-auth rerun after the baseline fix is NOT RUN because the simulator returned to OAuth/Google credential flow after rebuild.

Current E2E acceptance status:
- Options cleanup: PASS.
- Large ProductPrice fixed-cap blocker: CODE/TEST PASS, PARTIAL LIVE.
- Bootstrap/full pull with valid baseline: NOT PASS / BLOCKED_APP_AUTH for rerun.
- Incremental pull/push, Generated live sync, History live sync: still NOT RUN / BLOCKED_APP_AUTH.

FIX/PARITY pass update 2026-05-13 23:45 -0400:
- Android parity audit completed against real code: `31-android-sync-progress-parity-audit.md`.
- MainActor/performance audit completed: `32-mainactor-performance-sync-audit.md`.
- iOS simulator smoke completed: root progress banner, Options progress, `Sync now` CTA and scroll during cloud count fetch: `33-ios-unified-sync-live-smoke.md`.
- Android device smoke completed on OnePlus IN2013: one public sync action only, `assembleDebug`, targeted catalog tests and install/launch passed: `34-android-sync-parity-live-smoke.md`.
- Cross-platform live E2E remains NOT RUN / BLOCKED_APP_AUTH: `35-cross-platform-unified-sync-e2e.md`.

Updated acceptance status:
- ✅ Android vs iOS comparison: executed.
- ✅ Single public sync action: verified on iOS simulator and Android device.
- ✅ Progress UI: verified on iOS root banner and Options during active cloud check.
- ✅ Main-thread mitigation: code is batched/yielding; simulator scroll during fetch was responsive.
- ❌ Live app-auth bootstrap/push/read-back: NOT RUN.
- ❌ Cross-platform Supabase E2E with `TASK108_SYNC_*` data: NOT RUN, no data created.

Post-TASK-108 targeted FIX update 2026-05-14 00:38 -0400:
- ✅ UX — History cloud card cleanup passed: no public History `Send` / `Download`, read-only status and Options sync hint present.
- ✅ UX/STATIC — Options remains the single public cloud sync surface with `Sincronizza ora`.
- ✅ STATIC/TEST — Global pending snapshot now includes dirty History entries without requiring a separate History button path.
- ✅ LIVE PARTIAL — iOS app-auth session was available and `Sync now` was executed through the public Options flow.
- ✅ LIVE PARTIAL — Local iOS simulator DB populated to 19,886 products / 81 suppliers / 49 categories / 15,386 ProductPrice rows.
- ❌ LIVE FAIL/BLOCKED — Baseline records stayed `0`; UI still showed database-not-downloaded style state after local data existed.
- ❌ LIVE FAIL/BLOCKED — Two History entries remained dirty after global sync; no confirmed History/session remote id/read-back.
- ❌ NOT EXECUTED — Controlled incremental pull from a remote `TASK108_SYNC_*` delta.
- ❌ NOT EXECUTED — Controlled Database/ProductPrice push/read-back with `TASK108_SYNC_*` data.
- ❌ NOT EXECUTED — Cross-platform signed-in Android/iOS E2E; Android device was signed out.
- ✅ ANDROID — Local database status card implemented and smoke-tested on OnePlus IN2013.

Current E2E acceptance status:
- REVIEW_READY_WITH_CHANGES_REMAINING.
- TASK-108 remains ACTIVE / REVIEW, not DONE.
- No `PASS_WITH_NOTES` is proposed for the live E2E surface because the live run exposed unresolved baseline/History blockers.

Final ProductPrice keyset FIX update 2026-05-14 12:34 -0400:
- ✅ LIVE PASS — iOS app-auth ProductPrice full pull/apply completed through public Options `Sincronizza ora`.
- ✅ LIVE PASS — remote ProductPrice total `290,955`, page size `900`, keyset stream completed.
- ✅ LIVE PASS — local ProductPrice remote-linked rows `290,953`; `2` remote rows skipped explicitly because linked products are tombstoned.
- ✅ LIVE PASS — baseline written: `1` run / `20,012` records.
- ✅ LIVE PASS — Options final state refreshed to `Database locale aggiornato`, not baseline absent.
- ✅ LIVE PASS — UI progress visible and scroll responsive during apply.
- ✅ TEST PASS — ProductPrice keyset/apply/progress/baseline targeted suite passed after fix.

Remaining E2E status:
- ❌ NOT EXECUTED in this focused pass — Android signed-in rerun.
- ❌ NOT EXECUTED in this focused pass — iOS ↔ Supabase ↔ Android cross-platform scenarios.
- ❌ NOT EXECUTED in this focused pass — controlled incremental pull/push and Generated/History live matrix.

Updated acceptance status:
- ProductPrice/bootstrap blocker is resolved.
- TASK-108 remains ACTIVE / REVIEW and NON DONE until the remaining live E2E surfaces are completed or reviewed as explicit blockers.

UI responsiveness FIX update 2026-05-14 14:24 -0400:
- ✅ STATIC/FIX — ProductPrice apply remains `@MainActor` because SwiftData `ModelContext` is actor-bound, but page-local loop now yields every 150 rows and records `fetchMs` / `applyMs` / `saveMs`.
- ✅ STATIC/FIX — `SupabaseManualSyncViewModel` throttles catalog/ProductPrice/History progress UI publishing; completion/failure/cancel remain immediate.
- ✅ STATIC/FIX — Options automatic check waits 700 ms after appear/active before starting, so first render and initial scroll get a quiet window.
- ✅ UI/SMOKE — Options signed-out account card polished; after screenshot saved as `screenshots/2026-05-14-options-account-polish-after.jpg`.
- ✅ BUILD — iOS Debug build/run PASS; iOS Release build PASS; Android `assembleDebug` PASS; Android ProductPrice paging test PASS.
- ✅ DEVICE — Android install/launch PASS; memory TOTAL PSS `182,569 KB`, TOTAL RSS `281,960 KB`.
- ⚠️ TEST_RUNNER_BLOCKED — iOS targeted XCTest runner failed to launch simulator clone with `FBSOpenApplicationServiceErrorDomain Code=1 RequestDenied`; build itself passes.
- ❌ NOT EXECUTED — new full iOS app-auth post-patch run with checkpoints 0/9k/53k/90k/150k/completion.
- ❌ NOT EXECUTED — incremental pull/push live, Generated live, History/session live and cross-platform E2E.

Current acceptance status:
- REVIEW_READY_WITH_RESPONSIVENESS_FIXES.
- TASK-108 remains NON DONE.

Definitive thread/MainActor FIX update 2026-05-14 15:25 -0400:
- ✅ PROFILE/ROOT_CAUSE — Before sample reproduced queued tab taps and showed main thread busy in `SwiftDataInventorySnapshotService.makeSnapshot()` through launch/foreground auto-check.
- ✅ PROFILE/ROOT_CAUSE — Second sample found automatic `PriceHistoryBackfillRunner` / `PriceHistoryBackfillService` running from `ContentView` lifecycle on the UI context.
- ✅ FIX — Preview local snapshot now runs in a detached worker context created from `ModelContainer`.
- ✅ FIX — ProductPrice/catalog/history apply paths are no longer wired to the View/UI `ModelContext` through the Release adapter for heavy work.
- ✅ FIX — Automatic launch price-history backfill was removed from View lifecycle.
- ✅ PROFILE/AFTER — Final sample shows main thread idle: `3822/3822` samples in run loop / `mach_msg2_trap`, no snapshot/backfill/ProductPrice heavy symbols on main.
- ✅ UI/SMOKE — Final Options tab tap returned in `0.3708s`; no multi-second queued input observed.
- ✅ BUILD/TEST — iOS Debug build PASS; iOS Release build PASS; targeted iOS tests PASS via direct `xcodebuild`; Android `assembleDebug` PASS; Android repository tests PASS.
- ⚠️ ANDROID_ENV — Android ViewModel test group hit MockK/attach infrastructure failure; `adb` not found, so device/logcat smoke was not executable in this pass.
- ❌ NOT EXECUTED — full ProductPrice live post-patch rerun, incremental pull/push live, Generated live, History/session live, and cross-platform E2E.

Updated acceptance status:
- Thread/MainActor responsiveness fix: PASS for the measured launch/foreground freeze path.
- Full TASK-108 E2E acceptance: still NOT DONE / NOT PASS.
