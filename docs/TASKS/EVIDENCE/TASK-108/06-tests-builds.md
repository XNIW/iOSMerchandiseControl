# TASK-108 Evidence 06 — Tests and Builds

Status: EXECUTED / REVIEW-READY WITH NOTES.

Initial audit:
- Branch: `main`.
- Local HEAD at preflight: `27aa4a588430c07871aa02ea3cb7b7abf7821101`.
- Working tree was already dirty with TASK-108 planning/evidence plus TASK-108 execution files; no unrelated revert was performed.
- iOS simulator used: `iPhone 17 Pro` via XcodeBuildMCP.
- iOS physical device was detected, but physical install/smoke was NOT RUN.
- Android physical device was detected and used for assemble/launch smoke.
- Supabase CLI version: `2.98.2`; local Docker Supabase status was NOT RUN because Docker daemon was unavailable.

Final checks:
- ✅ ESEGUITO — `git diff --check`: PASS.
- ✅ ESEGUITO — `plutil -lint` Localizable strings EN/IT/ES/ZH: PASS.
- ✅ ESEGUITO — Debug simulator build: PASS, warning 0. Log: `build_sim_2026-05-13T23-58-06-460Z_pid92627_5cd8698c.log`.
- ✅ ESEGUITO — Release simulator build: PASS via `xcodebuild`. Warning observed: AppIntents metadata skipped because the app has no AppIntents.framework dependency.
- ✅ ESEGUITO — Full XCTest simulator suite: PASS, 659 passed / 0 failed / 21 skipped. Result bundle: `test_sim_2026-05-13T23-57-03-199Z_pid92627_60a54ead.xcresult`.
- ✅ ESEGUITO — TASK-108 targeted tests: PASS, 26 passed / 0 failed. Result bundle: `test_sim_2026-05-13T23-45-26-326Z_pid92627_6cdb119a.xcresult`.
- ✅ ESEGUITO — Simulator smoke Options signed-out: PASS, screenshot `screenshots/2026-05-13-options-release-signed-out.jpg`.
- ✅ ESEGUITO — Simulator smoke History cloud signed-out: PASS, screenshot `screenshots/2026-05-13-history-cloud-signed-out.jpg`.
- ✅ ESEGUITO — Simulator Dynamic Type XXXL smoke Options: PASS, screenshot `screenshots/2026-05-13-options-dynamic-type-xxxl.jpg`.
- ✅ ESEGUITO — Simulator foreground relaunch smoke: PASS, no crash observed.
- ✅ ESEGUITO — Android `assembleDebug`: PASS in reference repo.
- ✅ ESEGUITO — Android physical launch smoke: PASS, app process observed after launch.
- ⚠️ NON ESEGUIBILE — Supabase local stack: Docker daemon unavailable.
- ❌ NON ESEGUITO — live Supabase app-auth E2E full pull/push/read-back: no authenticated app session was available; no token/service_role workaround used.
- ❌ NON ESEGUITO — iOS physical device smoke: detected but not installed/launched in this pass.

Notes:
- Full suite skip count is expected for live-gated and hardware-gated tests.
- No Supabase test rows were created/modified/deleted during this FIX pass.

Targeted Options cleanup FIX update 2026-05-13 20:45 -0400:
- ✅ ESEGUITO — `git diff --check`: PASS.
- ✅ ESEGUITO — `plutil -lint` Localizable strings EN/IT/ES/ZH: PASS.
- ✅ ESEGUITO — Debug simulator build/run after Options cleanup: PASS via XcodeBuildMCP, warning 0. Log: `build_run_sim_2026-05-14T00-32-06-325Z_pid92627_5bfe0662.log`.
- ✅ ESEGUITO — Release simulator build after Options cleanup: PASS via `xcodebuild build -configuration Release`.
- ✅ ESEGUITO — TASK-108 targeted XCTest after Options cleanup: PASS, 172 passed / 0 failed. Result bundle: `Test-iOSMerchandiseControl-2026.05.13_20-41-20--0400.xcresult`.
- ✅ ESEGUITO — Simulator smoke Options signed-out cleanup: PASS. Screenshots: `screenshots/2026-05-13-options-after-public-cloud-local.jpg`, `screenshots/2026-05-13-options-after-diagnostics-collapsed.jpg`.
- ✅ ESEGUITO — Simulator smoke app-auth launch: PARTIAL; ASWebAuthenticationSession and Google login page reached. Screenshot: `screenshots/2026-05-13-options-signin-google-credential-required.jpg`.
- ✅ ESEGUITO — Simulator smoke Database signed-out/empty: PASS. Screenshot: `screenshots/2026-05-13-database-smoke-empty-after-fix.jpg`.
- ✅ ESEGUITO — Simulator smoke Generated/Inventory signed-out: PASS. Screenshot: `screenshots/2026-05-13-generated-inventory-smoke-after-fix.jpg`.
- ✅ ESEGUITO — Simulator smoke History signed-out: PASS. Screenshot: `screenshots/2026-05-13-history-smoke-signed-out-after-fix.jpg`.
- ✅ ESEGUITO — Simulator Dynamic Type extra-extra-large Options smoke: PASS. Screenshot: `screenshots/2026-05-13-options-after-dynamic-type-xxl.jpg`.
- ✅ ESEGUITO — Android reference `assembleDebug`: PASS, with existing AGP/Kotlin deprecation warnings.
- ⚠️ NON ESEGUIBILE — Supabase local stack status: Docker daemon unavailable.
- ⚠️ NON ESEGUIBILE — live Supabase app-auth full pull / incremental pull / Database push / Generated push / History push: OAuth reached Google credential prompt, but no human/test-account credentials were available to complete app-auth.
- ❌ NON ESEGUITO — iOS physical device smoke: device detected, but this targeted FIX used simulator because app-auth stopped at human credential entry.
- ✅ ESEGUITO — Privacy scan: no raw token/JWT/API key/account email added; service_role matches are existing defensive tests/config guards only.

Large ProductPrice bootstrap FIX update 2026-05-13 22:45 -0400:
- ✅ ESEGUITO — Debug simulator build after pagination/baseline fixes: PASS via XcodeBuildMCP, warning 0. Log: `build_sim_2026-05-14T02-44-43-232Z_pid92627_853b737c.log`.
- ✅ ESEGUITO — Release simulator build after pagination/baseline fixes: PASS via `xcodebuild build -configuration Release`. Log: `/tmp/task108-release-build.log`.
- ✅ ESEGUITO — `git diff --check`: PASS.
- ✅ ESEGUITO — `plutil -lint` Localizable strings EN/IT/ES/ZH: PASS.
- ✅ ESEGUITO — ProductPrice large-history targeted XCTest: PASS by exit code. Result bundle: `/tmp/task108-large-price-targeted-final.xcresult`; log: `/tmp/task108-large-price-targeted-final.log`.
- ✅ ESEGUITO — Baseline batch writer targeted XCTest: PASS by exit code. Result bundle: `/tmp/task108-baseline-batch-2.xcresult`; log: `/tmp/task108-baseline-batch-2.log`.
- ✅ ESEGUITO — Baseline-absent public CTA copy targeted XCTest: PASS by exit code. Result bundle: `/tmp/task108-download-copy-2.xcresult`; log: `/tmp/task108-download-copy-2.log`.
- ✅ ESEGUITO — Live app-auth partial bootstrap observation: authenticated preview succeeded before rebuild; local SwiftData reached 19,886 products, 79 suppliers, 47 categories, 53,022 ProductPrice rows.
- ❌ NON ESEGUITO — Fresh live app-auth bootstrap rerun after batched baseline fix: after rebuild, app-auth returned to OAuth/Google credential flow and no authenticated app session was available to rerun baseline commit.
- ❌ NON ESEGUITO — iOS physical device smoke: device listed offline by `xctrace`.

Post-TASK-108 targeted FIX update 2026-05-14 00:38 -0400:
- ✅ ESEGUITO — iOS Debug build/run via XcodeBuildMCP: PASS, warning 0. Log: `/Users/minxiang/Library/Developer/XcodeBuildMCP/workspaces/iOSMerchandiseControl-3314632fed98/logs/build_run_sim_2026-05-14T04-29-19-934Z_pid7522_e6bb61d2.log`.
- ✅ ESEGUITO — iOS Release simulator build via XcodeBuildMCP: PASS, warning 0. Log: `/Users/minxiang/Library/Developer/XcodeBuildMCP/workspaces/iOSMerchandiseControl-3314632fed98/logs/build_sim_2026-05-14T04-34-53-678Z_pid7522_3bdc118b.log`.
- ✅ ESEGUITO — iOS targeted TASK-108 tests: PASS, 116 tests / 0 failures (`SupabaseManualSyncLocalPendingSnapshotProviderTests`, `HistorySessionSyncServiceTests`, `CloudSyncOverviewStateTests`, `SupabaseManualSyncViewModelTests`).
- ✅ ESEGUITO — iOS `git diff --check`: PASS.
- ✅ ESEGUITO — `plutil -lint` Localizable strings EN/IT/ES/ZH: PASS.
- ✅ ESEGUITO — iOS simulator History smoke: PASS; read-only cloud card visible, no public `Send` / `Download`.
- ✅ ESEGUITO — iOS simulator Options smoke: PASS; single public `Sincronizza ora`, pending History count visible before apply.
- ✅ ESEGUITO — Android `assembleDebug`: PASS with pre-existing AGP/Kotlin deprecation warnings.
- ✅ ESEGUITO — Android targeted tests: PASS/up-to-date for `*CatalogSync*` and `*RealtimeRefreshCoordinatorTest*`.
- ✅ ESEGUITO — Android install/launch/device Options smoke on OnePlus IN2013: PASS; `Local database status` card rendered.
- ✅ ESEGUITO — Android `git diff --check`: PASS.
- ✅ ESEGUITO — Privacy scan: no raw token/JWT/API key/account email added; service_role matches are defensive/documentation only.
- ⚠️ NON ESEGUIBILE — Supabase local stack: not used; no Docker-backed local stack available in this pass.
- ❌ NON ESEGUITO — full iOS XCTest suite in this post-pass; targeted TASK-108 suite was run instead.
- ❌ NON ESEGUITO — Dynamic Type extra-extra-large in this post-pass; previous TASK-108 Dynamic Type smoke remains in earlier evidence.
- ❌ NON ESEGUITO — iOS physical device smoke.
- ❌ NON ESEGUITO — controlled live incremental pull/push/cross-platform E2E with `TASK108_SYNC_*` data.
