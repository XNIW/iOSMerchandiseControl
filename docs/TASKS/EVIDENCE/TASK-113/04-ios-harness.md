# iOS Harness

Status: PASS_WITH_NOTES.

PASS:
- `ios build debug`: `20260521T053308Z-ios-build-debug.json`
- `ios build release`: `20260521T053325Z-ios-build-release.json`
- `ios test sync`: `20260521T053449Z-ios-test-sync.json`
- `ios test lifecycle`: `20260521T053516Z-ios-test-lifecycle.json`
- `ios test offline`: `20260521T053528Z-ios-test-offline.json`
- `ios smoke simulator`: `20260521T053541Z-ios-smoke-simulator.json`
- `scan release-cta`: `20260521T054442Z-scan-release-cta.json`

BLOCKED:
- `ios smoke options`: `20260521T053656Z-ios-smoke-options.json`
- Cause: legacy `tools/sim_ui.sh` JXA/AX timeout, not xcodebuild/XCTest failure.

Live-gated refusals:
- `ios auth-preflight --live` without `MC_ALLOW_LIVE=1`: exit 4.
- `ios live-write` remains gated intentionally.

Professional review update — 2026-05-21:
- PASS: `ios build debug` rerun after Xcode lock fix: `20260521T061257Z-ios-build-debug-p73774.json`.
- PASS: `ios build release`: `20260521T061315Z-ios-build-release-p74937.json`.
- PASS: `ios test sync`: `20260521T061436Z-ios-test-sync-p76572.json`.
- PASS: `ios test lifecycle`: `20260521T061502Z-ios-test-lifecycle-p77538.json`.
- PASS: `ios test offline`: `20260521T061518Z-ios-test-offline-p78280.json`.
- PASS: `ios smoke simulator`: `20260521T061532Z-ios-smoke-simulator-p78995.json`.
- BLOCKED: `ios smoke options`: `20260521T061541Z-ios-smoke-options-p79643.json`; XcodeBuildMCP snapshot/tap could not run because simulator session defaults could not be configured with the exposed tools, while `simctl` screenshot only confirms visible Home/Options tab.

Resume attempt — 2026-05-21 12:30 -0400:
- PASS: `ios smoke simulator`: `20260521T162721Z-ios-smoke-simulator-p65668.json`.
- BLOCKED: `ios smoke options`: `20260521T162735Z-ios-smoke-options-p66538.json`; cause unchanged: legacy JXA timeout after launch.
- PASS_WITH_NOTES (alternative evidence): XcodeBuildMCP session defaults were configured for booted simulator `240F400E-5EFA-486A-9137-FFBBE70F604D`; UI snapshot and coordinate tap reached `Opzioni`. The visible hierarchy showed `Sincronizzazione automatica attiva`, badge `Attiva`, `Modifiche locali in attesa, 0`, and no public manual sync CTA. Privacy-safe screenshot saved at `screenshots/ios-options-xcodebuildmcp-20260521T1629Z.jpg`.

Final DONE closure — 2026-05-21 13:19 -0400:
- PASS: `ios smoke simulator`: `20260521T171135Z-ios-smoke-simulator-p28962.json`.
- PASS_WITH_NOTES: `ios smoke options`: `20260521T171149Z-ios-smoke-options-p30086.json`. The command still records legacy JXA/AX as tooling-blocked, then validates `ios-options-xcodebuildmcp-fallback.txt` before returning exit `0`.
- XcodeBuildMCP fallback evidence: Options reached; automatic sync active; badge `Attiva`; pending local changes `0`; no public manual sync CTA visible; screenshot `screenshots/ios-options-xcodebuildmcp-20260521T1656Z.jpg`.
