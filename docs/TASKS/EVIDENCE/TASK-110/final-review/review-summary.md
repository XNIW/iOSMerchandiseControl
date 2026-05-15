# TASK-110 final review summary

Date: 2026-05-15 15:04 -0400

## Verdict
- ❌ CHANGES_REQUIRED — iOS app-auth blocker corrected and verified, but the full Android/iOS/Supabase manual P8 matrix has not yet been rerun after the fix.
- TASK-110 state after this review slice: `ACTIVE / FIX / APP_AUTH_FIXED_MATRIX_PENDING`.
- TASK-109 remains `BLOCKED / SOSPESO`.
- No remote push performed.

## Root cause confirmed
- The iOS discrepancy reported by the user was a real OAuth/PKCE state race, not a simple signed-out state.
- Sanitized diagnostic root cause: OAuth callback arrived with auth code while the PKCE code verifier was missing; global `.onOpenURL` could also race with `ASWebAuthenticationSession`.
- Simulator restore behavior was made deterministic for smoke verification without changing production/device session storage semantics.

## Direct fixes applied
- iOS `SupabaseAuthViewModel`: filtered OAuth URL handling, ignored ASWeb-owned callback while signing in, and added short post-failure session recovery for recoverable auth errors.
- iOS `SupabaseClientProvider`: separated short-lived PKCE verifier storage from session storage; production/device session remains Keychain-backed; DEBUG simulator gets a fallback copy for smoke restore only.
- iOS/Android History tombstone guard: remote tombstone no longer overwrites an active dirty local History entry.

## Current status
- ✅ PASS — iOS app-auth live login with `x***@gmail.com`.
- ✅ PASS — iOS session restore after stop/launch.
- ✅ PASS — iOS auth preflight XCTest.
- ✅ PASS — Supabase final smoke already completed in review preflight.
- ✅ PASS — ProductPrice/catalog counts from preflight/fix-completion remain coherent: Supabase `41109`, Android physical `41109`, iOS UI local count `41109`, `pricesSkippedNoProductRef=0`.
- ❌ CHANGES_REQUIRED — P8 full manual cross-platform matrix pending after app-auth fix.

