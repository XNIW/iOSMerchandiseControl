# TASK-109 — 109 Review Runtime Smoke

Review pass: 2026-05-15 02:25 -0400

## Simulator

- iPhone 15 Pro Max iOS 26.1
- Bundle: `com.niwcyber.iOSMerchandiseControl`
- Build/run: XcodeBuildMCP PASS, warnings `0`

## Screenshots

- `screenshots/109-review-runtime-inventory-launch.jpg`
- `screenshots/109-review-options-signed-out-history-zero-after-seed.jpg`

## Flow verificato

- Launch app: PASS.
- Inventory navigabile: PASS.
- Options navigabile: PASS.
- Signed-out/account issue state: PASS.
- Local database counts visible: PASS.
- History count visible in Options: PASS, value `0`.
- History SwiftData local count: PASS, `ZHISTORYENTRY = 0`.
- Products/price local data present: `ZPRODUCT = 19695`, `ZPRODUCTPRICE = 41109`.

## Flow bloccato

- Cold launch signed-in: NOT_EXECUTABLE in current runtime, app signed-out.
- Root banner signed-in auto-check: NOT_EXECUTABLE in current runtime, covered by execution evidence but not rerun signed-in.
- Sync now signed-in: NOT_EXECUTABLE in current runtime.
- Review actionable live: NOT_EXECUTABLE in current runtime.
- History live non-empty pull: BLOCKED_WITH_PLAYBOOK.
- Second sync live no-duplicate: BLOCKED_WITH_PLAYBOOK.

## Auth attempt

Tap `Sign in` opened ASWebAuthenticationSession, then returned to app with `Account needs attention`. No authenticated app session was available to run owner-scoped RLS pull.

## Performance/stability observations

- No visible freeze in Inventory/Options navigation.
- Options scroll and local count rendering are responsive.
- No root Review/no-op modal surfaced in signed-out state.
