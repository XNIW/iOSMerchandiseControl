# Android / iOS Security Parity

## Static Parity Observed

| Area | iOS | Android reference | Result |
|---|---|---|---|
| Supabase key | Ignored plist + publishable key validation | BuildConfig URL / publishable key | PASS |
| service_role | Rejected in iOS config; no app usage found | No service-role match in main source scan | PASS |
| Owner writes | Payload owner from auth session; RLS owner | Payload owner/user id from auth state | PASS_STATIC |
| Owner reads | TASK-101 explicit owner filters added to iOS | Android relies on auth/RLS for fetches | PASS_STATIC |
| Realtime/sync events | RPC and preview paths reviewed | Realtime lifecycle tied to auth state | PASS_STATIC |
| Privacy logs | iOS masked in TASK-101 | Raw auth userId log fixed in `MerchandiseControlApplication.kt` | PASS |

Android was used as a functional/security reference and for the single cross-platform TASK-101 privacy fix. Runtime log remediation was limited to removing the raw auth `userId` from `Log.i`.

## Android Verification

- `./gradlew --no-daemon testDebugUnitTest`: PASS.
- `./gradlew --no-daemon lintDebug`: PASS.
- `./gradlew --no-daemon assembleDebug`: PASS.
- `./gradlew --no-daemon assembleRelease`: PASS.
- Raw `userId` logging scan: PASS/no matches after fix.

AGP/Kotlin deprecation warnings remain non-blocking and unrelated to TASK-101.
