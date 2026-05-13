# Device Account Preflight

Status: `PASS_WITH_NOTES`

## iOS

| Check | Result |
|-------|--------|
| Physical device available | PASS, physical iPhone detected. |
| OS | iOS 26.5, device identifier redacted. |
| Release physical build | PASS. |
| Physical install | PASS. |
| Physical launch | PASS, bundle id `com.niwcyber.iOSMerchandiseControl`. |
| Simulator Release build/run | PASS on an iPhone-class simulator. |
| Authenticated app session | PARTIAL, app launched but no real owner/session flow was verified end-to-end. |

## Android

| Check | Result |
|-------|--------|
| Physical device available | PASS, OnePlus-class Android device detected. |
| OS | Android 13, serial redacted. |
| Debug install | PASS. |
| Launch/UI smoke | PASS, Home/Inventory screen visible with import/manual-entry/navigation controls. |
| Application id | `com.example.merchandisecontrolsplitview`. |
| Supabase client runtime | Supabase Kotlin dependency family present through current project configuration. |
| Authenticated app session | PARTIAL, app launched but no real owner/session flow was verified end-to-end. |

## Supabase

| Check | Result |
|-------|--------|
| CLI present | PASS. |
| Linked read-only metadata | PARTIAL, one metadata query succeeded. |
| RLS metadata | PASS_WITH_NOTES, expected owner-scoped policy shape observed on key tables. |
| Live authenticated read/write/read-back | BLOCKED by missing real owner/session gate and later linked CLI auth/circuit-breaker failure. |

No Supabase data was created, modified, or deleted.
## PASS 2 Update

- iOS physical device: Debug test build and live XCTest execution passed with authenticated Supabase session.
- iOS simulator: Debug launch smoke passed; Release simulator build passed.
- Android physical device: Debug app/test APK build and install passed.
- Android account/session: first preflight correctly failed signed-out; then UI Google sign-in was completed and authenticated preflight passed.
- Owner/RLS sanity: iOS and Android reported the same redacted project hash and owner hash. No service role and no RLS bypass were used.
- Device/account details are intentionally not recorded in raw form.
