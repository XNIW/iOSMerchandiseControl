# TASK-112 — Final review+fix rerun

Timestamp: 2026-05-20 22:26 -0400  
Agent: Codex / Executor  
Verdict: **BLOCKED**  

## Scope

Final severe REVIEW+FIX rerun requested by the user while canonical task state is **ACTIVE / BLOCKED**. This is an explicit user override of the normal Codex phase gate; tracking remains **ACTIVE / BLOCKED** because CA-20 live iOS↔Android↔Supabase is still not passable.

## Fixes applied

| File | Change | Reason |
|---|---|---|
| `iOSMerchandiseControl/SupabaseAuthViewModel.swift` | OAuth callback URLs are forwarded to `authService.handleOpenURL(url)` even while auth state is `.signingIn`. | Prevents a valid OAuth callback from being swallowed during the sign-in transition. |
| `iOSMerchandiseControl/ContentView.swift` | Background cancellation now calls `viewModel.requestLifecycleInterruptionForBackground()` before canceling root foreground/reconnect work. | Keeps lifecycle state coherent when app backgrounding interrupts automatic sync checks. |
| `iOSMerchandiseControlTests/SupabaseManualSyncReleaseUITests.swift` | Added/updated static guards for OAuth callback forwarding and background lifecycle interruption. | Makes both review fixes traceable in targeted tests. |

## Commands and results

### iOS

| Command / check | Result | Evidence |
|---|---:|---|
| `git status --short`, `git diff` and comparison after `git fetch origin main` | PASS_WITH_NOTES | Dirty tree is TASK-112 work; target files compared against `origin/main` before edits. |
| `git diff --check` | PASS | No whitespace errors. |
| `xcodebuild -scheme iOSMerchandiseControl -configuration Debug ... build` | PASS | `** BUILD SUCCEEDED **`; only existing AppIntents metadata warning. |
| `xcodebuild -scheme iOSMerchandiseControl -configuration Release ... build` | PASS | `** BUILD SUCCEEDED **`; only existing AppIntents metadata warning. |
| Targeted XCTest reconnect/lifecycle/release/OAuth callback group | PASS | Targeted TASK-112 tests passed. |
| Broader TASK-112 regression XCTest group | PASS_WITH_NOTES | `** TEST SUCCEEDED **`; 227 passed test-case lines, 0 failed. Existing unrelated Swift concurrency/AppIntents/CoreSimulator notes remain. |
| `plutil -lint` Info/SupabaseConfig/EN/IT/ES/ZH strings | PASS | All checked plist/strings files OK. |
| Release exact forbidden sync-now scan | PASS | No `Sync now`, `Sincronizza ora`, `Sincronizar ahora`, `立即同步` in Release bundle/source. |
| Broader iOS bundle scan for download/send copy | PASS_WITH_NOTES | Strings such as download/send remain in localization/review/remediation/debug paths; Release automatic status card has no public one-tap sync-now action. |
| Release simulator launch + Options smoke | PASS_WITH_NOTES | App launched on iPhone 17 Pro simulator; Options showed automatic sync/account/local database status. |
| Live iOS preflight sentinel | BLOCKED | `xcodebuild test ... Task098CrossPlatformSmokeTests/test01PreflightAndCollisionScanReadOnly` with `/tmp/TASK098_LIVE_SMOKE` failed; xcresult message: `failed: caught error: "sessionMissing"`. |

### Android

| Command / check | Result | Evidence |
|---|---:|---|
| `git status --short`, `git diff --check` | PASS_WITH_NOTES | Dirty tree is known TASK-112 Android parity work; no whitespace errors. |
| `./gradlew :app:testDebugUnitTest` | FAIL_ENV_THEN_PASS | First run failed from MockK/ByteBuddy self-attach (`AttachNotSupportedException`). Rerun with `JAVA_TOOL_OPTIONS=-Djdk.attach.allowAttachSelf=true` passed. |
| `JAVA_TOOL_OPTIONS=-Djdk.attach.allowAttachSelf=true ./gradlew :app:testDebugUnitTest` | PASS | XML summary: 458 tests, 0 failures, 0 errors, 2 skipped. |
| `./gradlew :app:assembleDebug` | PASS | Build successful. |
| `./gradlew :app:assembleRelease` | PASS | Build successful. |
| `./gradlew :app:lintDebug` | PASS | Build successful. |
| Debug APK install | PASS | `adb install -r app-debug.apk` → Success. |
| Physical launch smoke after user unlock | PASS | `MainActivity` top-resumed, pid present, Inventario screenshot/UI tree captured. |
| Physical Options smoke after user unlock | PASS | Options rendered automatic sync card and local database status; no visible manual sync-now CTA. |
| Android Release/source CTA scan | PASS | No exact forbidden `Sync now` / localized sync-now / send/download-cloud CTA matches in source/APK resources. |

### Supabase local

| Command / check | Result | Evidence |
|---|---:|---|
| `supabase --version` | PASS_WITH_NOTES | CLI `2.98.2`; update `2.100.1` available. |
| `supabase status` | PASS_WITH_NOTES | Local setup running; stopped imgproxy/edge_runtime/pooler noted. Raw status output with local keys was removed. |
| `supabase db lint --local` | PASS | `No schema errors found`. |
| Transactional SQL contract | PASS | `record_sync_event` idempotent, owner isolation works, RLS enabled on required tables, ProductPrice unique constraint present, realtime includes `shared_sheet_sessions` and `sync_events`. |
| Residue query | PASS | `TASK112_LOCAL_*` / `TASK112_OFFLINE_*` residue count = 0 for checked tables. |

## Data and cleanup

- Supabase local data used: `TASK112_LOCAL_FINAL_REVIEW_EVENT`, `TASK112_LOCAL_FINAL_REVIEW_DEVICE`, synthetic UUID owners, inside `BEGIN`/`ROLLBACK`.
- Live data used: none created for `TASK112_*` or `TASK112_OFFLINE_*`.
- Cleanup: local SQL transaction rolled back; final residue query returned 0.
- Android/iOS smoke screenshots and UI dumps are local `/tmp` artifacts only.
- No service_role, client secret, RLS bypass, global cleanup, live migration, or real-data deletion was used.

## Verified

- iOS reconnect/lifecycle/OAuth callback static and XCTest paths.
- iOS Debug/Release build and Release simulator launch/Options smoke.
- Android full unit suite with required JVM attach flag, Debug/Release builds, lint, install, physical launch and Options smoke after unlock.
- Supabase local schema/RLS/RPC/realtime contract and cleanup discipline.
- Public sync-now CTA absence in Release/source scans and visible Options smoke.

## Not verified

- CA-20 live iOS↔Android↔Supabase convergence.
- Live iOS authenticated write/read/apply.
- Dual-client offline `TASK112_OFFLINE_*` matrix.
- Account switch/logout with pending live data.
- Long-offline gap/full reconciliation live simulation.
- Instruments/Perfetto jank profiling and full Dynamic Type/VoiceOver pass.

## Residual risks

- P0 blocker: iOS app-auth session is missing for live harness, so cross-platform automatic convergence is not proven.
- Offline-first live gates CA-43…CA-68 remain BLOCKED/PASS_WITH_NOTES/NOT_RUN mix.
- iOS Release bundle contains localization/review/remediation strings for download/send states; current Release automatic status UI does not expose them as public manual sync-now CTAs, but a future UI change must preserve this separation.

## Next concrete action

Restore or provide a valid iOS app-auth live session/test account path, then rerun iOS live preflight, CA-20, `TASK112_*` live convergence, `TASK112_OFFLINE_*` offline/reconnect matrix and scoped cleanup/read-back. Until that passes, TASK-112 remains **ACTIVE / BLOCKED**.

## Superseding CA-20 app-auth rerun — 2026-05-20 23:15 -0400

The previous `sessionMissing` conclusion is superseded:

- iOS app-auth restore and XCTest preflight PASS.
- Android app-auth preflight PASS via persistent `adb shell am instrument`.
- CA-20 bidirectional live matrix PASS with `TASK112_CA20_R20260521T030156Z_`.
- Offline iOS retry/drain PASS with `TASK112_OFFLINE_R20260521T030912Z_`.

The task remains **ACTIVE / BLOCKED** because cleanup scoped failed:

- `Task103CrossPlatformAcceptanceTests/test08Task112ScopedCleanupWhenEnabled`
- error: `PostgrestError 42501 permission denied for table inventory_product_prices`
- remaining live residue before cleanup:
  - CA-20 prefix: suppliers `9`, categories `9`, products `54`, ProductPrice `114`;
  - offline prefix: suppliers `1`, categories `1`, products `1`, ProductPrice `0`.

No service_role/admin cleanup, global cleanup or RLS bypass was used. See `92-ca20-app-auth-rerun-to-done.md`.

## Final closure superseding this rerun — 2026-05-21 00:01 -0400

The cleanup blocker documented above is resolved by the user-authorized scoped admin/postgres cleanup:

- Initial CA-20/offline residuals deleted only by exact TASK-112 prefixes.
- Final `TASK112_FINAL_R20260521T033505Z_` live rerun passed and was cleaned immediately.
- Final `TASK112_ANY` residue is 0.
- iOS lifecycle crash discovered after this rerun was fixed and targeted lifecycle/reconnect tests PASS.
- iOS Debug/Release and Android unit/build/lint/device smoke checks PASS.

Canonical final evidence: `93-final-cleanup-done-closure.md`.

Final verdict: **DONE**.
