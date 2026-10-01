# Independent source review — iOS R-I05 — 2026-10-01

**Verdict: APPROVED. No remaining concrete P0/P1/P2 finding in the frozen R-I05 auth delta.** This approves source correctness and the inspected targeted evidence. Final canonical full suite, Release/analyze/scans, signed TEST artifact, authenticated acceptance, exact-SHA CI and normal integration remain distinct required gates owned by executor/root/coordinator. This is not a DONE or live-logout claim.

## Scope and immutable source

Reviewed Provider, AuthService, AuthViewModel and the new SDK-backed SupabaseAuthLifecycleTests. Read active TASK-144 planning/CA, isolated master, AGENTS and execution protocol before source. Reviewed exact pinned supabase-swift2.46.0 at dd29b624b9ceea87612d0b00457e1400f7d22c2e and its AuthClient, LiveSessionManager, SessionStorage, CodeVerifierStorage and internal SupabaseClient listener.

Independent SHA256 recheck:

- `iOSMerchandiseControl/SupabaseClientProvider.swift`: `5a0dd30dc65262bb6d85e9e0bfa730f53771279c61f372f29034464b8ced5bed`
- `iOSMerchandiseControl/SupabaseAuthService.swift`: `2f37c30835cb6cb0a80579e9856e13fb2efa1f3a6efe5999e890b0a8faabf5b1`
- `iOSMerchandiseControl/SupabaseAuthViewModel.swift`: `6f13de8ae1c05b2dbc3f9c6cdd9cad8e865051dc2ade96629f8f0c80922528d7`
- `iOSMerchandiseControlTests/SupabaseAuthLifecycleTests.swift`: `f1eeb4c951ddeab2f571931cd1732b4ebe3d76f1d954336fadfabc478f348aca`

Full executor source mapping: 326 app/test/UI/resource files independently rehashed, zero missing/mismatch; recomputed compact sorted mapping fingerprint `3e0202444d73ba021259c98787702eb6d1ea18cfbc913e1e44bdc1a60910464a` equals frozen-source-manifest.json. R-I04 source/test/two fixture hashes still match the prior separate APPROVED review.

## Original finding and closure

The real pinned SDK may finish a refresh after signOut(.local), re-store the old session and emit TOKEN_REFRESHED. Foreground/background providers previously had separate SDK clients but shared durable auth storage. The fix shares one active SDK group for that existing session key and supplies a generation-owned wrapper over the existing storage implementation. Store/remove and generation transitions use the same lock. Beginning logout rejects further writes and application events from the retiring generation; finalization verifies removal even if logout HTTP fails or is cancelled. The SDK's swallowed deletion errors are therefore not mistaken for success.

The verified removal includes the current session key, the actual legacy migration alias supabase.session, and that session's PKCE verifier; no unrelated project key is deleted. If remove/readback fails, the current process blocks storage and event acceptance and reports failure. The test explicitly demonstrates that an independent SDK restart may still read the record when deletion actually failed; this case is not misreported as a completed durable logout. Retry/new explicit login verifies cleanup before permitting a new session. Successful logout/restart is separately proven to remain empty after old refresh response.

Retired wrappers cannot read, overwrite or remove a newer login's session/verifier. The group switches the active client, retires the earlier ticker/listener, and sends replacement snapshots to Service listeners. Scoped events retain their SDK generation until ViewModel consumption, protecting an already queued event; the service also rejects session payloads that no longer match current storage. VM operation epoch and generation checks fence asynchronous sign-in/sign-out success/failure after suspension. The returned replacement generation is captured before awaiting ticker stop, avoiding attribution to a newer login started while that await yields.

## Bounded review interleaving and correction

Root/reviewer confirmed that an interactive replacement client could otherwise bootstrap a retained expired session A on the *new* generation, then overwrite login B. SupabaseClient always attaches its auth listener and refreshes expired initial storage even with the periodic ticker disabled. The executor preserved a controlled red with 1 failed case / four assertions and corrected prepareInteractiveSignIn to remove and verify the retired session before creating the interactive generation. The normal cold-bootstrap and ordinary-refresh paths do not call this cleanup; both positive controls remain green. New same-UUID login is protected by generation, not merely account equality.

## Evidence independently inspected

- Original resumed red.xcresult official summary: 5 unique cases, 1 PASS / 4 FAIL / 0 SKIP / expectedFailures0. Failures cover late refresh after completed logout, background provider, different new account and new login with the same UUID.
- replacement-bootstrap-red.xcresult official summary: 1 case, 0 PASS / 1 FAIL / 0 SKIP. Log retains all four failing assertions, including expired storage still present and old refreshed token replacing B.
- final-targeted.xcresult official summary: 55 unique cases, 54 PASS / 0 FAIL / 1 SKIP, expectedFailures0, no runtime warning. Log independently identifies 20 real SDK auth cases, 1 local-signout-scope contract, 3 config cases (2 PASS / 1 gated live-auth SKIP) and 31 Task111 import cases. No UI/device/live acceptance is inferred from these tests.
- Guardrails cover current/storage/restarted SDK, foreground/background single-client isolation, actual buffered SDK event, same/different account, ordinary and expired bootstrap, refresh 500 preserving existing session, delayed earlier SDK sign-in success/failure, cancellation and HTTP500 logout, failed/no-op deletion, failed store and PKCE retired-read/write/remove isolation.
- HTTP500 can cause SDK internal retries; the new scope assertion correctly checks every request remains local. No existing assertion/gate was removed or weakened. The first guardrail failures and earlier reds remain preserved.
- git diff --check passed. No new dependency, SDK upgrade/fork, global signout, business schema/sync/image pipeline or protected configuration edit in the reviewed source delta. All application auth API changes are internal module types/seams; no public API migration.

Review method: STATIC code/SDK inspection plus read-only official result/hash verification. Tests/builds were executed by the executor, not the reviewer. Reviewer changed only standalone evidence notes/review receipts under the shared output directory and operated no device, account, Keychain, preferences, credentials or backend.
