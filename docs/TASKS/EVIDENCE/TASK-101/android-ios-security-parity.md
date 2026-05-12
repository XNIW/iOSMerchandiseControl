# Android / iOS Security Parity

## Static Parity Observed

| Area | iOS | Android reference | Result |
|---|---|---|---|
| Supabase key | Ignored plist + publishable key validation | BuildConfig URL / publishable key | PASS |
| service_role | Rejected in iOS config; no app usage found | No service-role match in main source scan | PASS |
| Owner writes | Payload owner from auth session; RLS owner | Payload owner/user id from auth state | PASS_STATIC |
| Owner reads | TASK-101 explicit owner filters added to iOS | Android relies on auth/RLS for fetches | PASS_STATIC |
| Realtime/sync events | RPC and preview paths reviewed | Realtime lifecycle tied to auth state | PASS_STATIC |
| Privacy logs | iOS masked in TASK-101 | Raw auth userId log remains | PARTIAL |

Android was used as a functional/security reference only. No Android source was modified and no Android build/test was run in TASK-101.

