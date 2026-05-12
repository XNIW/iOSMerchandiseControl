# Auth / Session Audit

| Area | Evidence | Result |
|---|---|---|
| Config loading | `SupabaseConfig.swift` loads ignored plist, validates HTTPS, rejects server-only keys. | PASS |
| OAuth | `SupabaseAuthService.signInWithGoogle()` uses Supabase SDK OAuth with app callback scheme. | PASS |
| Session binding | `SupabaseAuthSessionInfo.userID` is taken from Supabase `Session.user.id`. | PASS |
| Session events | `authStateChanges` maps sign-in, sign-out and token refresh into view model state. | PASS |
| Logout | `SupabaseAuthService.signOut()` delegates to Supabase SDK and clears view-model session info. | PASS |
| Token persistence | App code does not write access/refresh token to UserDefaults/SwiftData/files. | PASS |
| Error display | Auth errors use `safeDiagnosticDetail`, now backed by stronger sanitizer. | PASS |
| Password login exposure | No iOS or Android app path uses password sign-in; auth flows are Google/OAuth/ID-token based. | PASS |

No manual OAuth run with a real account was performed in TASK-101 to avoid producing sensitive evidence. Authentication behavior is covered by prior TASK-097/098 evidence, current static/test checks and final app launch smoke.
