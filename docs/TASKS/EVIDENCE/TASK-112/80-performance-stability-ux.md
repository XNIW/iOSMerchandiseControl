# TASK-112 — Performance, stability and UX

Timestamp: 2026-05-20 22:26 -0400  
Agent: Codex / Executor

## Implemented / verified

| Area | Result | Evidence |
|---|---:|---|
| Options does not start full sync on open | PASS_WITH_NOTES | Public CTA removed/hidden; iOS Release automatic status card has no action buttons; Android Options card is status-only aside from account sign-in remediation. |
| iOS reconnect efficiency | PASS | Added `AutomaticSyncReconnectScheduler` with foreground gate, debounce, coalescing and cancellation on background. |
| No reconnect sync storm | PASS_WITH_NOTES | iOS fake-path scheduler tests and Android coordinator tests pass; live flapping drain not executed. |
| Main thread/MainActor heavy work | PASS_WITH_NOTES | Reconnect scheduler only schedules intent; sync execution remains in existing async service paths. No profiling trace captured. |
| ProductPrice large dataset | PASS_WITH_NOTES | iOS ProductPrice large/paging test passed; Android repository tests passed. No fresh live large dataset run. |
| Batch bounded / retry lanes | PASS_WITH_NOTES | Existing unit coverage on both platforms; live partial ack matrix not executed. |
| Crash/smoke | PASS | iOS simulator launch/Options and Android unlocked physical launch/Options both succeeded without immediate crash/logcat fatal. |
| Release CTA scan | PASS | Exact public sync-now CTA scans pass for iOS Release bundle/source and Android APK/source; iOS broad bundle still contains non-public localization/review/remediation strings for download/send states. |
| Localization/plist | PASS | `plutil -lint` PASS for iOS Info/config/localizations EN/ES/IT/ZH. |
| Android lint/build | PASS | `testDebugUnitTest` PASS on attach-self rerun, `assembleDebug`, `assembleRelease`, `lintDebug` PASS. |

## Not fully verified

| Area | Result | Reason |
|---|---:|---|
| UI jank/frame timing | NOT_RUN | No Instruments/Perfetto profile captured. |
| Database/History scroll/selection preservation | NOT_RUN | Manual UI path not instrumented in this completion slice. |
| Dynamic Type/VoiceOver | NOT_RUN | Smoke not executed in simulator/device. |
| No snackbar repetition/global blocking spinner | PASS_WITH_NOTES | Static/UI-state audit only; no repeated offline/reconnect device script. |
| Full offline pending UX | BLOCKED | Depends on live/offline dual-client matrix and iOS app-auth session. |

## Bundle/resource cleanup

The iOS project no longer copies non-runtime `Vendor/libxls` service files (`fuzz.yml`, workflow/config docs, README, etc.) into app Resources. This removed a false-positive `Upload` string from the Release bundle scan and reduces bundle noise without changing runtime parser source compilation.

## Verdict

**PASS_WITH_NOTES** for targeted performance/stability/UX checks. The concrete iOS reconnect efficiency gap was fixed and tested; full offline/live UX and profiling remain blocked/not run.

## Final review+fix rerun update — 2026-05-20 22:26 -0400

- iOS OAuth callback forwarding fix reduces sign-in callback fragility: matching callback URLs now reach `authService.handleOpenURL` even while state is `.signingIn`.
- iOS background cancellation now records lifecycle interruption before canceling root foreground/reconnect work.
- Android physical Options smoke after unlock confirms visible automatic-sync status copy and no public manual sync-now CTA.
- No Instruments/Perfetto profiling was captured; performance verdict remains PASS_WITH_NOTES, not a global production-readiness claim.

## CA-20 app-auth rerun update — 2026-05-20 23:15 -0400

- iOS cold-launch restore UI PASS: Options showed connected account, automatic sync active, pending local changes `0`; screenshot saved at `/var/folders/nf/85_c2pqj60v6q0r7v8ktzkpw0000gn/T/screenshot_optimized_b08e863a-fd00-43a8-a1f5-623b9eff2624.jpg`.
- Android final UI smoke after persistent app-auth run saved screenshot at `/private/tmp/task112_android_final_options.png`; UI text included `Catalogo cloud sincronizzato`.
- CA-20 live tests completed without observed app crash.
- No fresh Instruments/Perfetto/profile capture was run in this rerun.
- Stability verdict remains **PASS_WITH_NOTES** because cleanup is blocked and profiling/manual accessibility smoke are not complete.

## Final stability/UX closure update — 2026-05-21 00:01 -0400

- Cleanup blocker resolved with scoped admin cleanup and zero-residue read-back.
- iOS lifecycle XCTest crash found during regression was fixed with explicit `nonisolated deinit` on the MainActor lifecycle preflight/gate classes; single-test and full lifecycle suite now PASS.
- iOS Options smoke PASS via XcodeBuildMCP: UI hierarchy reached `Options`; screenshot `/var/folders/nf/85_c2pqj60v6q0r7v8ktzkpw0000gn/T/screenshot_optimized_87cf026b-b3f0-4c59-8b4f-00fbbb1239f3.jpg`.
- Android Options smoke PASS on OnePlus `IN2013`: UI dump shows `Opzioni` selected; screenshot `/tmp/task112-android-options-smoke.png`; no app crash buffer output.
- No Instruments/Perfetto profiling or full accessibility pass was run; this remains a non-blocking PASS_WITH_NOTES limitation.

Final stability/UX verdict: **PASS_WITH_NOTES**.
